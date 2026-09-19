-- A day was never a schedule.
--
-- cp_login_settings could say which days somebody may sign in (working_days)
-- and it could say between which two absolute moments (login_on / logout_on),
-- and the two were mutually exclusive. Neither is what anybody actually means
-- by working hours. "Monday, 02:30 to 17:50" needs both halves at once, and it
-- needs to repeat — login_on/logout_on are timestamps, so they express "between
-- the 1st and the 5th of October", a temporary grant, not a weekly rhythm.
--
-- So the times move into rows of their own, one per window, hanging off the
-- login setting. A day with no row is the old behaviour: allowed, all day. A
-- day with rows is allowed only inside them, and there can be more than one, so
-- a split shift is two rows rather than a reason to widen the whole day.
--
-- start_time and end_time are `time`, not timestamps. A weekly window has no
-- date; it acquires one at the moment somebody tries to sign in — which is the
-- second half of this migration.
--
-- Whose 02:30?
--
-- Nothing in core_platform has ever needed an answer, because everything stored
-- here is an absolute instant that carries its own offset. A wall-clock time
-- does not. Worse, the code that reads these columns was already of two minds:
-- the working-day check called datetime.now() and got the server's local day,
-- while the date-range check called datetime.now(timezone.utc). On a UTC
-- container in Ghana those agree, which is exactly why nobody noticed, and they
-- would stop agreeing the first time a container moved or a tenant opened
-- somewhere else.
--
-- cp_timezone_settings gives that question one answer per tenant. An IANA name
-- rather than an offset, so daylight saving belongs to the zone database rather
-- than to somebody remembering to edit a column twice a year. A tenant with no
-- row reads as UTC, so nothing has to be backfilled and nothing changes for
-- anyone until they choose a zone.
--
-- Idempotent; safe to re-run on every deploy. The EF migration
-- AddLoginSchedulesAndTenantTimezone creates both tables and runs first, so on
-- a normal deploy the statements below find them already there; they are
-- repeated for anyone applying the shared SQL on its own.


-- =====================================================================
-- 1. The windows.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_login_schedules (
    id                text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,
    login_settings_id text        NOT NULL,
    day_of_week       varchar(9)  NOT NULL,
    start_time        time        NOT NULL,
    end_time          time        NOT NULL,
    description       text,
    cdate             text,
    ctime             text,
    cdatetime         timestamptz,
    created_by        text,
    updated_by        text,
    deleted_by        text,
    delete_status     text        NOT NULL DEFAULT 'NOT_DELETED',
    is_active         boolean     NOT NULL DEFAULT true,
    CONSTRAINT pk_cp_login_schedules PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_cp_login_schedules_delete_status
        CHECK (delete_status IN ('PENDING','DELETED','NOT_DELETED')),
    CONSTRAINT ck_cp_login_schedules_day
        CHECK (day_of_week IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY',
                               'FRIDAY','SATURDAY','SUNDAY')),
    -- Equal is not a window, and reversed silently means "never" — the kind of
    -- setting that looks saved and locks somebody out on Monday morning.
    CONSTRAINT ck_cp_login_schedules_window CHECK (end_time > start_time),
    CONSTRAINT fk_cp_login_schedules_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE,
    -- A window is part of the setting it hangs off and means nothing without it.
    CONSTRAINT fk_cp_login_schedules_login_settings
        FOREIGN KEY (login_settings_id, tenant_id)
        REFERENCES core_platform.cp_login_settings (id, tenant_id) ON DELETE CASCADE
);

-- The resolver reads every window for one login setting on the auth hot path,
-- and looks them up by that and nothing else.
CREATE INDEX IF NOT EXISTS ix_cp_login_schedules_settings_tenant
    ON core_platform.cp_login_schedules (login_settings_id, tenant_id);


-- =====================================================================
-- 2. Whose clock.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_timezone_settings (
    id          text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    timezone    text        NOT NULL DEFAULT 'UTC',
    description text,
    cdate       text,
    ctime       text,
    cdatetime   timestamptz,
    created_by  text,
    updated_by  text,
    is_active   boolean     NOT NULL DEFAULT true,
    CONSTRAINT pk_cp_timezone_settings PRIMARY KEY (id, tenant_id),
    CONSTRAINT fk_cp_timezone_settings_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- One answer per tenant, or the question is not answered.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_timezone_settings_tenant_id
    ON core_platform.cp_timezone_settings (tenant_id);
