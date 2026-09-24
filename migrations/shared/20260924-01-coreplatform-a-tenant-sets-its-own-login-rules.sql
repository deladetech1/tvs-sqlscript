-- Four security rules that were never anybody's to set.
--
-- A session lasted 24 hours because ACCESS_TOKEN_EXPIRE_HOUR said 24. Not a
-- default a tenant could raise — a constant in the login service, the same for
-- a two-person shop and for somebody handling other people's money. The other
-- three did not exist at all: a wrong password cost an attacker nothing but
-- another request, a password could be changed back to the one it just came
-- from, and no password ever had to be rotated.
--
-- All four become tenant settings here, and each carries its own answer to the
-- question "does this apply to the owner too?".
--
--
-- Why the owner switches default to false
--
-- These are the settings most likely to be configured by exactly one person:
-- the owner, on their own tenant, with nobody above them. An owner who enables
-- lockout and then mistypes their password five times has locked themselves
-- out of the only account that could have unlocked them. So the policies skip
-- the owner until somebody deliberately says otherwise. The switch is there —
-- a tenant that wants the owner held to the same rule can say so — but that has
-- to be a decision, not the thing that happens while you are reading the label.
--
--
-- The table that was already here
--
-- cp_user_login_tracking has existed since the schema did, with columns for
-- attempt counts, lock state, password history and expiry dates. Nothing has
-- ever written to it. Every column it needs for three of these four features
-- was sitting there unused, including the unique index on (tenant_id, user_id)
-- that makes the attempt counter safe to upsert. Only the lock_reason /
-- locked_at / unlocked_* group below is new, and it is new for the admin rather
-- than for the enforcement: somebody looking at a locked account should be able
-- to see why it locked before they decide to open it again.
--
--
-- Idempotent; safe to re-run on every deploy. The EF migration
-- AddLoginSecuritySettings creates the two tables and adds the columns, and
-- runs first, so on a normal deploy the statements below find the work already
-- done. They are repeated for anyone applying the shared SQL on its own. The
-- audit-log tables are shared-SQL only, matching 20260730-02.


-- =====================================================================
-- 1. How long a session lasts.
-- =====================================================================
-- Minutes, not hours. The behaviour being replaced is exactly 1440 of them,
-- and minutes leave room for the tenant who wants a half-hour session without
-- another migration to get there.
--
-- What this cannot do, and the UI says so: the number is baked into a
-- stateless JWT's `exp` when somebody signs in. Lowering it shortens the next
-- session, not the ones already handed out.
CREATE TABLE IF NOT EXISTS core_platform.cp_session_settings (
    id                      text        NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id               text        NOT NULL,
    session_timeout_minutes integer     NOT NULL DEFAULT 1440,
    applies_to_owner        boolean     NOT NULL DEFAULT false,
    description             text,
    cdate                   text,
    ctime                   text,
    cdatetime               timestamptz,
    created_by              text,
    updated_by              text,
    is_active               boolean     NOT NULL DEFAULT true,
    CONSTRAINT pk_cp_session_settings PRIMARY KEY (id, tenant_id),
    -- A zero-minute session has expired by the time the token reaches the
    -- browser: every user in the tenant locked out at once, by a saved form.
    CONSTRAINT ck_cp_session_settings_timeout CHECK (session_timeout_minutes >= 1),
    CONSTRAINT fk_cp_session_settings_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- One answer per tenant, or the question is not answered.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_session_settings_tenant_id
    ON core_platform.cp_session_settings (tenant_id);


-- =====================================================================
-- 2. Locking an account after repeated failures.
-- =====================================================================
-- Off by default. Switching this on for existing tenants unasked would start
-- locking people out of a system that has never done that to them.
--
-- release_mode is an explicit choice rather than "a duration of zero means
-- manual". A 0 in a column called lockout_duration_minutes reads as "unlock
-- immediately" to the next person who sees it, which is the opposite of what
-- it would have meant.
CREATE TABLE IF NOT EXISTS core_platform.cp_account_lockout_settings (
    id                       text       NOT NULL DEFAULT gen_random_uuid()::text,
    tenant_id                text       NOT NULL,
    is_enabled               boolean    NOT NULL DEFAULT false,
    -- Consecutive failures that trip the lock. The counter resets on a
    -- successful sign-in, so somebody who mistypes twice a week never reaches it.
    max_failed_attempts      integer    NOT NULL DEFAULT 5,
    -- AUTOMATIC: the lock expires on its own after lockout_duration_minutes.
    -- MANUAL:    it holds until an admin opens the account.
    release_mode             text       NOT NULL DEFAULT 'AUTOMATIC',
    lockout_duration_minutes integer    NOT NULL DEFAULT 30,
    applies_to_owner         boolean    NOT NULL DEFAULT false,
    description              text,
    cdate                    text,
    ctime                    text,
    cdatetime                timestamptz,
    created_by               text,
    updated_by               text,
    is_active                boolean    NOT NULL DEFAULT true,
    CONSTRAINT pk_cp_account_lockout_settings PRIMARY KEY (id, tenant_id),
    -- Locking after zero failures locks everybody on their first attempt.
    CONSTRAINT ck_cp_account_lockout_settings_attempts
        CHECK (max_failed_attempts >= 1),
    CONSTRAINT ck_cp_account_lockout_settings_duration
        CHECK (lockout_duration_minutes >= 1),
    CONSTRAINT ck_cp_account_lockout_settings_release_mode
        CHECK (release_mode IN ('AUTOMATIC','MANUAL')),
    CONSTRAINT fk_cp_account_lockout_settings_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_account_lockout_settings_tenant_id
    ON core_platform.cp_account_lockout_settings (tenant_id);


-- =====================================================================
-- 3. Password reuse and password expiry.
-- =====================================================================
-- These live on cp_password_policies because that is what they are: rules
-- about what a password may be. But note the gating carefully — each has its
-- own flag, and neither is behind enforce_password_policy.
--
-- enforce_password_policy governs the complexity rules (length, uppercase,
-- digits). A tenant can perfectly well want passwords rotated every 90 days
-- without wanting to dictate their shape, and if expiry hid behind the
-- complexity flag they would switch expiry on, see it saved, and get nothing.
ALTER TABLE core_platform.cp_password_policies
    -- On by default: reuse has always been allowed, and flipping that for
    -- every tenant at once would refuse the next password change of everybody
    -- who cycles between two of them.
    ADD COLUMN IF NOT EXISTS allow_password_reuse    boolean NOT NULL DEFAULT true,
    -- How many previous passwords to remember and refuse, once reuse is off.
    ADD COLUMN IF NOT EXISTS password_history_count  integer NOT NULL DEFAULT 5,
    ADD COLUMN IF NOT EXISTS reuse_applies_to_owner  boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS enforce_password_expiry boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS password_expiry_value   integer NOT NULL DEFAULT 90,
    -- QUARTERS and SEMI_ANNUAL are units in their own right rather than folded
    -- into "3 months" and "6 months". They compute to the same interval, but
    -- the interval an admin picked is the interval the screen shows them
    -- afterwards, which is the whole point of storing their answer.
    ADD COLUMN IF NOT EXISTS password_expiry_unit    text    NOT NULL DEFAULT 'DAYS',
    ADD COLUMN IF NOT EXISTS expiry_applies_to_owner boolean NOT NULL DEFAULT false;

DO $$
BEGIN
    -- Remembering zero previous passwords is not "no history"; it is a reuse
    -- rule that refuses nothing while reporting itself as on.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_cp_password_policies_history_count'
    ) THEN
        ALTER TABLE core_platform.cp_password_policies
            ADD CONSTRAINT ck_cp_password_policies_history_count
            CHECK (password_history_count >= 1);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_cp_password_policies_expiry_value'
    ) THEN
        ALTER TABLE core_platform.cp_password_policies
            ADD CONSTRAINT ck_cp_password_policies_expiry_value
            CHECK (password_expiry_value >= 1);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_cp_password_policies_password_expiry_unit'
    ) THEN
        ALTER TABLE core_platform.cp_password_policies
            ADD CONSTRAINT ck_cp_password_policies_password_expiry_unit
            CHECK (password_expiry_unit IN
                   ('DAYS','WEEKS','MONTHS','QUARTERS','SEMI_ANNUAL','YEARS'));
    END IF;
END $$;


-- =====================================================================
-- 4. Why an account locked.
-- =====================================================================
-- The enforcement does not need these columns — is_locked and locked_until are
-- enough to refuse a sign-in. They are here for the person on the other side
-- of it: an admin looking at a locked account, deciding whether to open it.
-- "Locked" on its own is not a thing anybody can act on.
--
-- unlocked_by holds a user id, or the string 'system' when the lock simply
-- expired, so the trail reads the same either way.
ALTER TABLE core_platform.cp_user_login_tracking
    ADD COLUMN IF NOT EXISTS lock_reason  text,
    ADD COLUMN IF NOT EXISTS locked_at    timestamptz,
    ADD COLUMN IF NOT EXISTS unlocked_by  text,
    ADD COLUMN IF NOT EXISTS unlocked_at  timestamptz;

-- The admin screen lists a tenant's locked accounts; without this it is a
-- sequential scan of every user who has ever signed in.
CREATE INDEX IF NOT EXISTS ix_cp_user_login_tracking_locked
    ON core_platform.cp_user_login_tracking (tenant_id, is_locked)
    WHERE is_locked = true;


-- =====================================================================
-- 5. Audit trails for the two new settings groups.
-- =====================================================================
-- One table per settings sub-entity, so each gets its own tab on the Settings
-- audit page — the design set by 20260730-02, followed here rather than
-- reinvented. No FKs to the audited row: an audit trail must outlive it.
--
-- Reuse and expiry need nothing here; they are columns on cp_password_policies,
-- so changing them already lands in cp_password_policy_audit_logs.
CREATE TABLE IF NOT EXISTS core_platform.cp_session_settings_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- session settings id
    entity_name            text,

    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_session_settings_audit_logs_scope
    ON core_platform.cp_session_settings_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_session_settings_audit_logs_entity
    ON core_platform.cp_session_settings_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_session_settings_audit_logs_action
    ON core_platform.cp_session_settings_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_session_settings_audit_logs_performed_by
    ON core_platform.cp_session_settings_audit_logs (tenant_id, performed_by);


CREATE TABLE IF NOT EXISTS core_platform.cp_account_lockout_settings_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- lockout settings id
    entity_name            text,

    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_account_lockout_audit_logs_scope
    ON core_platform.cp_account_lockout_settings_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_account_lockout_audit_logs_entity
    ON core_platform.cp_account_lockout_settings_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_account_lockout_audit_logs_action
    ON core_platform.cp_account_lockout_settings_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_account_lockout_audit_logs_performed_by
    ON core_platform.cp_account_lockout_settings_audit_logs (tenant_id, performed_by);
