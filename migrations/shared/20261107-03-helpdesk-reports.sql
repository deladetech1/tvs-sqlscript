-- Help Desk R5: custom reports, dashboards and scheduled reports.
--
--   hd_reports           a report over one whitelisted dataset; definition holds the dimensions,
--                        measures, filters, date range, grain, sort and limit
--   hd_dashboards        widgets laid out on a page (a report or a built-in each)
--   hd_report_schedules  six-field cron, timezone, recipients (business users' emails only), CSV
--   hd_report_runs       append-only: what each scheduled run did
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §2. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_reports (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    name           text NOT NULL,
    dataset        text NOT NULL
                   CONSTRAINT hd_reports_dataset_check CHECK (dataset IN ('tickets', 'sla', 'tasks', 'approvals', 'assets', 'changes', 'problems', 'csat')),
    definition     jsonb NOT NULL DEFAULT '{}',
    owner_user_id  text,
    is_shared      boolean NOT NULL DEFAULT false,
    version        int NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_reports_owner_idx ON helpdesk.hd_reports (tenant_id, bus_id, owner_user_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_dashboards (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    name           text NOT NULL,
    owner_user_id  text,
    is_shared      boolean NOT NULL DEFAULT false,
    layout         jsonb NOT NULL DEFAULT '[]',
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_dashboards_owner_idx ON helpdesk.hd_dashboards (tenant_id, bus_id, owner_user_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_report_schedules (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    report_id    text NOT NULL REFERENCES helpdesk.hd_reports (id),
    cron         text NOT NULL,
    timezone     text NOT NULL DEFAULT 'UTC',
    recipients   text[] NOT NULL DEFAULT '{}',
    format       text NOT NULL DEFAULT 'csv' CONSTRAINT hd_report_schedules_format_check CHECK (format IN ('csv')),
    is_active    boolean NOT NULL DEFAULT true,
    last_run_at  timestamptz,
    next_run_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text
);
CREATE INDEX IF NOT EXISTS hd_report_schedules_report_idx ON helpdesk.hd_report_schedules (report_id);
-- The schedule job reads due schedules across businesses.
CREATE INDEX IF NOT EXISTS hd_report_schedules_due_idx ON helpdesk.hd_report_schedules (next_run_at) WHERE is_active;

CREATE TABLE IF NOT EXISTS helpdesk.hd_report_runs (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    schedule_id  text REFERENCES helpdesk.hd_report_schedules (id),
    report_id    text NOT NULL REFERENCES helpdesk.hd_reports (id),
    rows         int CONSTRAINT hd_report_runs_rows_check CHECK (rows >= 0),
    outcome      text NOT NULL CONSTRAINT hd_report_runs_outcome_check CHECK (outcome IN ('sent', 'failed', 'skipped', 'empty')),
    error        text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text
);
CREATE INDEX IF NOT EXISTS hd_report_runs_schedule_idx ON helpdesk.hd_report_runs (schedule_id, cdatetime DESC);
DROP TRIGGER IF EXISTS hd_report_runs_append_only ON helpdesk.hd_report_runs;
CREATE TRIGGER hd_report_runs_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_report_runs
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_report_runs'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_report_runs is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_report_schedules s JOIN helpdesk.hd_reports r ON r.id = s.report_id
                WHERE r.tenant_id <> s.tenant_id OR r.bus_id <> s.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk report schedule belongs to a report of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_report_runs x JOIN helpdesk.hd_reports r ON r.id = x.report_id
                WHERE r.tenant_id <> x.tenant_id OR r.bus_id <> x.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk report run belongs to a report of another business';
    END IF;
END $$;

COMMIT;
