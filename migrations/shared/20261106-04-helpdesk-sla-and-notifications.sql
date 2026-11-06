-- Help Desk R1: SLAs, in-app notifications and the email outbox.
--
--   hd_calendars         business calendars (or 24x7); at most one default per business
--   hd_calendar_hours    working windows per weekday (0 = Sunday ... 6), in minutes from midnight
--   hd_holidays          days a calendar does not count
--   hd_sla_policies      which tickets a policy covers (first match by position wins)
--   hd_sla_targets       per priority: first response, next response and resolution minutes
--   hd_sla_clocks        the read model: one clock per ticket and metric, kept by the backend in the
--                        same transaction as the ticket change
--   hd_sla_clock_events  append-only: the history of every clock
--   hd_notifications     the in-app bell
--   hd_outbox            emails waiting to be sent by the helpdesk-outbox job
--
-- Also the FK from hd_tickets.sla_policy_id (20261106-03) to hd_sla_policies.
-- Retention: cp_app_data_owners (20261106-01) is per schema, so these tables are purged with the
-- rest of helpdesk on unsubscribe; nothing names tables one by one. CHECK lists are defined here,
-- inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R1.md §1, §5. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================= calendars
CREATE TABLE IF NOT EXISTS helpdesk.hd_calendars (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL,
    timezone    text NOT NULL DEFAULT 'UTC',
    is_24x7     boolean NOT NULL DEFAULT false,
    is_default  boolean NOT NULL DEFAULT false,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
-- At most one default calendar per business (R1 §1 invariant), enforced on every write.
CREATE UNIQUE INDEX IF NOT EXISTS hd_calendars_one_default_uq
    ON helpdesk.hd_calendars (tenant_id, bus_id) WHERE is_default;

CREATE TABLE IF NOT EXISTS helpdesk.hd_calendar_hours (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    calendar_id   text NOT NULL REFERENCES helpdesk.hd_calendars (id),
    weekday       int NOT NULL CONSTRAINT hd_calendar_hours_weekday_check CHECK (weekday BETWEEN 0 AND 6),
    start_minute  int NOT NULL,
    end_minute    int NOT NULL,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text,
    CONSTRAINT hd_calendar_hours_window_check CHECK (0 <= start_minute AND start_minute < end_minute AND end_minute <= 1440)
);
CREATE INDEX IF NOT EXISTS hd_calendar_hours_calendar_idx ON helpdesk.hd_calendar_hours (calendar_id, weekday);

CREATE TABLE IF NOT EXISTS helpdesk.hd_holidays (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    calendar_id   text NOT NULL REFERENCES helpdesk.hd_calendars (id),
    holiday_date  date NOT NULL,
    name          text NOT NULL,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_holidays_date_uq ON helpdesk.hd_holidays (calendar_id, holiday_date);

-- ====================================================================== SLA policies
CREATE TABLE IF NOT EXISTS helpdesk.hd_sla_policies (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    name                 text NOT NULL,
    position             int NOT NULL DEFAULT 0,
    match_department_id  text REFERENCES helpdesk.hd_departments (id),
    match_ticket_type    text CONSTRAINT hd_sla_policies_match_ticket_type_check CHECK (match_ticket_type IN ('request', 'incident', 'question')),
    match_category_id    text REFERENCES helpdesk.hd_categories (id),
    calendar_id          text REFERENCES helpdesk.hd_calendars (id),
    is_active            boolean NOT NULL DEFAULT true,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text
);
CREATE INDEX IF NOT EXISTS hd_sla_policies_order_idx ON helpdesk.hd_sla_policies (tenant_id, bus_id, position);

CREATE TABLE IF NOT EXISTS helpdesk.hd_sla_targets (
    tenant_id               text NOT NULL,
    bus_id                  text NOT NULL,
    policy_id               text NOT NULL REFERENCES helpdesk.hd_sla_policies (id),
    priority                text NOT NULL
                            CONSTRAINT hd_sla_targets_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    first_response_minutes  int CONSTRAINT hd_sla_targets_first_response_check CHECK (first_response_minutes > 0),
    next_response_minutes   int CONSTRAINT hd_sla_targets_next_response_check CHECK (next_response_minutes > 0),
    resolution_minutes      int CONSTRAINT hd_sla_targets_resolution_check CHECK (resolution_minutes > 0),
    warn_percent            int NOT NULL DEFAULT 80 CONSTRAINT hd_sla_targets_warn_percent_check CHECK (warn_percent BETWEEN 1 AND 100),
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    created_by              text,
    updated_at              timestamptz,
    updated_by              text,
    PRIMARY KEY (policy_id, priority)
);

-- The ticket file came first; its policy reference is tied here, where the table exists.
ALTER TABLE helpdesk.hd_tickets DROP CONSTRAINT IF EXISTS hd_tickets_sla_policy_fk;
ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_sla_policy_fk
    FOREIGN KEY (sla_policy_id) REFERENCES helpdesk.hd_sla_policies (id);

-- ======================================================================== SLA clocks
CREATE TABLE IF NOT EXISTS helpdesk.hd_sla_clocks (
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    ticket_id        text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    metric           text NOT NULL
                     CONSTRAINT hd_sla_clocks_metric_check CHECK (metric IN ('first_response', 'next_response', 'resolution')),
    policy_id        text REFERENCES helpdesk.hd_sla_policies (id),
    target_minutes   int,
    started_at       timestamptz,
    due_at           timestamptz,
    elapsed_seconds  bigint NOT NULL DEFAULT 0,
    last_change_at   timestamptz,
    state            text NOT NULL DEFAULT 'running'
                     CONSTRAINT hd_sla_clocks_state_check CHECK (state IN ('running', 'paused', 'met', 'breached', 'cancelled')),
    warned_at        timestamptz,
    breached_at      timestamptz,
    stopped_at       timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    PRIMARY KEY (ticket_id, metric)
);
-- The helpdesk-sla-scan job reads running clocks by due time, across businesses.
CREATE INDEX IF NOT EXISTS hd_sla_clocks_running_idx ON helpdesk.hd_sla_clocks (due_at) WHERE state = 'running';
CREATE INDEX IF NOT EXISTS hd_sla_clocks_business_idx ON helpdesk.hd_sla_clocks (tenant_id, bus_id, state);

CREATE TABLE IF NOT EXISTS helpdesk.hd_sla_clock_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    metric      text NOT NULL
                CONSTRAINT hd_sla_clock_events_metric_check CHECK (metric IN ('first_response', 'next_response', 'resolution')),
    event       text NOT NULL
                CONSTRAINT hd_sla_clock_events_event_check CHECK (event IN ('start', 'pause', 'resume', 'stop', 'retarget', 'warn', 'breach', 'cancel')),
    at          timestamptz NOT NULL DEFAULT now(),
    data        jsonb NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS hd_sla_clock_events_ticket_idx ON helpdesk.hd_sla_clock_events (ticket_id, metric, at);
DROP TRIGGER IF EXISTS hd_sla_clock_events_append_only ON helpdesk.hd_sla_clock_events;
CREATE TRIGGER hd_sla_clock_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_sla_clock_events
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== notifications
CREATE TABLE IF NOT EXISTS helpdesk.hd_notifications (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    user_id     text NOT NULL,
    kind        text NOT NULL,
    ticket_id   text REFERENCES helpdesk.hd_tickets (id),
    title       text NOT NULL,
    body        text,
    read_at     timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_notifications_user_idx
    ON helpdesk.hd_notifications (tenant_id, user_id, read_at, cdatetime DESC);

-- ============================================================================ outbox
CREATE TABLE IF NOT EXISTS helpdesk.hd_outbox (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    channel          text NOT NULL DEFAULT 'email' CONSTRAINT hd_outbox_channel_check CHECK (channel IN ('email')),
    to_address       text NOT NULL,
    subject          text NOT NULL,
    body             text NOT NULL,
    ticket_id        text REFERENCES helpdesk.hd_tickets (id),
    idempotency_key  text NOT NULL,
    status           text NOT NULL DEFAULT 'pending'
                     CONSTRAINT hd_outbox_status_check CHECK (status IN ('pending', 'sent', 'failed', 'skipped')),
    attempts         int NOT NULL DEFAULT 0,
    last_error       text,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    sent_at          timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_outbox_idempotency_uq ON helpdesk.hd_outbox (tenant_id, bus_id, idempotency_key);
-- The helpdesk-outbox job reads pending rows by their next attempt, across businesses.
CREATE INDEX IF NOT EXISTS hd_outbox_pending_idx ON helpdesk.hd_outbox (next_attempt_at) WHERE status = 'pending';

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_calendars_one_default_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_calendars has no one-default-per-business index';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_calendars WHERE is_default
                GROUP BY tenant_id, bus_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a business has more than one default Help Desk calendar';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_sla_clock_events'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_sla_clock_events is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_sla_policies p JOIN helpdesk.hd_calendars c ON c.id = p.calendar_id
                WHERE c.tenant_id <> p.tenant_id OR c.bus_id <> p.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk SLA policy uses a calendar of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_sla_clocks k JOIN helpdesk.hd_tickets t ON t.id = k.ticket_id
                WHERE t.tenant_id <> k.tenant_id OR t.bus_id <> k.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk SLA clock belongs to a ticket of another business';
    END IF;
END $$;

COMMIT;
