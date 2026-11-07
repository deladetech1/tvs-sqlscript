-- Help Desk R5: Workflow Studio.
--
--   hd_workflows          a workflow: its trigger (or a six-field schedule), its current version
--   hd_workflow_versions  the graph, numbered. Once published a version never changes (its own
--                         trigger); a draft may change, be published once, or be deleted
--   hd_workflow_runs      one run of a version; deduped on (version_id, trigger_event_id)
--   hd_workflow_steps     append-only: every attempt at every node of a run
--   hd_workflow_waits     a run parked on a delay or an approval, one per node
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §2. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_workflows (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    name                text NOT NULL,
    description         text,
    department_id       text REFERENCES helpdesk.hd_departments (id),
    trigger             text NOT NULL
                        CONSTRAINT hd_workflows_trigger_check CHECK (trigger IN ('ticket_created', 'ticket_updated', 'status_changed',
                            'approval_decided', 'sla_warning', 'sla_breach', 'fulfilment_complete', 'manual', 'schedule')),
    schedule_cron       text,
    is_active           boolean NOT NULL DEFAULT true,
    current_version_id  text,
    version             int NOT NULL DEFAULT 1,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text,
    -- A scheduled workflow says when.
    CONSTRAINT hd_workflows_schedule_check CHECK (trigger <> 'schedule' OR schedule_cron IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_workflows_trigger_idx ON helpdesk.hd_workflows (tenant_id, bus_id, trigger) WHERE is_active;

CREATE TABLE IF NOT EXISTS helpdesk.hd_workflow_versions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    workflow_id   text NOT NULL REFERENCES helpdesk.hd_workflows (id),
    number        int NOT NULL CONSTRAINT hd_workflow_versions_number_check CHECK (number >= 1),
    graph         jsonb NOT NULL,
    published_at  timestamptz,
    published_by  text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_workflow_versions_number_uq ON helpdesk.hd_workflow_versions (workflow_id, number);

-- A published version is what runs used: it never changes, and is deleted only by the unsubscribe
-- purge. A draft (published_at NULL) changes freely, may be published once, or deleted.
CREATE OR REPLACE FUNCTION helpdesk.hd_workflow_versions_published_guard() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF OLD.published_at IS NULL THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;
    IF TG_OP = 'DELETE' AND helpdesk.hd_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'hd_workflow_versions: a published version is immutable (% refused); write a new version instead', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;
DROP TRIGGER IF EXISTS hd_workflow_versions_published_guard ON helpdesk.hd_workflow_versions;
CREATE TRIGGER hd_workflow_versions_published_guard BEFORE UPDATE OR DELETE ON helpdesk.hd_workflow_versions
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_workflow_versions_published_guard();

ALTER TABLE helpdesk.hd_workflows DROP CONSTRAINT IF EXISTS hd_workflows_current_version_fk;
ALTER TABLE helpdesk.hd_workflows ADD CONSTRAINT hd_workflows_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES helpdesk.hd_workflow_versions (id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_workflow_runs (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    workflow_id       text NOT NULL REFERENCES helpdesk.hd_workflows (id),
    version_id        text NOT NULL REFERENCES helpdesk.hd_workflow_versions (id),
    ticket_id         text REFERENCES helpdesk.hd_tickets (id),
    trigger_event_id  text,
    state             text NOT NULL DEFAULT 'running'
                      CONSTRAINT hd_workflow_runs_state_check CHECK (state IN ('running', 'waiting', 'succeeded', 'failed', 'cancelled')),
    depth             int NOT NULL DEFAULT 0 CONSTRAINT hd_workflow_runs_depth_check CHECK (depth >= 0),
    started_at        timestamptz NOT NULL DEFAULT now(),
    ended_at          timestamptz,
    error             text,
    is_test           boolean NOT NULL DEFAULT false,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text
);
-- The dedupe key: a version runs at most once per triggering event.
CREATE UNIQUE INDEX IF NOT EXISTS hd_workflow_runs_dedupe_uq
    ON helpdesk.hd_workflow_runs (version_id, trigger_event_id) WHERE trigger_event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS hd_workflow_runs_workflow_idx ON helpdesk.hd_workflow_runs (tenant_id, bus_id, workflow_id, started_at DESC);
CREATE INDEX IF NOT EXISTS hd_workflow_runs_ticket_idx ON helpdesk.hd_workflow_runs (ticket_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_workflow_steps (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    run_id      text NOT NULL REFERENCES helpdesk.hd_workflow_runs (id),
    node_id     text NOT NULL,
    attempt     int NOT NULL DEFAULT 1 CONSTRAINT hd_workflow_steps_attempt_check CHECK (attempt >= 1),
    state       text NOT NULL
                CONSTRAINT hd_workflow_steps_state_check CHECK (state IN ('started', 'succeeded', 'failed', 'skipped', 'waiting')),
    output      jsonb,
    error       text,
    wake_at     timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_workflow_steps_run_idx ON helpdesk.hd_workflow_steps (run_id, cdatetime);
DROP TRIGGER IF EXISTS hd_workflow_steps_append_only ON helpdesk.hd_workflow_steps;
CREATE TRIGGER hd_workflow_steps_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_workflow_steps
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

CREATE TABLE IF NOT EXISTS helpdesk.hd_workflow_waits (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    run_id               text NOT NULL REFERENCES helpdesk.hd_workflow_runs (id),
    node_id              text NOT NULL,
    kind                 text NOT NULL CONSTRAINT hd_workflow_waits_kind_check CHECK (kind IN ('delay', 'approval')),
    wake_at              timestamptz,
    approval_request_id  text REFERENCES helpdesk.hd_approval_requests (id),
    resolved_at          timestamptz,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    -- A delay says until when.
    CONSTRAINT hd_workflow_waits_delay_check CHECK (kind <> 'delay' OR wake_at IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_workflow_waits_node_uq ON helpdesk.hd_workflow_waits (run_id, node_id);
-- The wake-up job reads open waits by time, across businesses.
CREATE INDEX IF NOT EXISTS hd_workflow_waits_due_idx ON helpdesk.hd_workflow_waits (wake_at) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS hd_workflow_waits_approval_idx ON helpdesk.hd_workflow_waits (approval_request_id) WHERE resolved_at IS NULL;

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_workflow_steps'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_workflow_steps is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_workflow_versions'::regclass AND p.proname = 'hd_workflow_versions_published_guard'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_workflow_versions has no published-version guard on UPDATE and DELETE';
    END IF;
    IF to_regclass('helpdesk.hd_workflow_runs_dedupe_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_workflow_runs has no dedupe key on (version_id, trigger_event_id)';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflows w JOIN helpdesk.hd_workflow_versions v ON v.id = w.current_version_id
                WHERE v.workflow_id <> w.id) THEN
        RAISE EXCEPTION 'a Help Desk workflow points at a version of another workflow';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflow_versions v JOIN helpdesk.hd_workflows w ON w.id = v.workflow_id
                WHERE w.tenant_id <> v.tenant_id OR w.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk workflow version belongs to a workflow of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflow_runs r JOIN helpdesk.hd_workflow_versions v ON v.id = r.version_id
                WHERE v.workflow_id <> r.workflow_id OR v.tenant_id <> r.tenant_id OR v.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk workflow run names a version of another workflow or business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflow_runs r JOIN helpdesk.hd_tickets t ON t.id = r.ticket_id
                WHERE t.tenant_id <> r.tenant_id OR t.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk workflow run is on a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflow_steps s JOIN helpdesk.hd_workflow_runs r ON r.id = s.run_id
                WHERE r.tenant_id <> s.tenant_id OR r.bus_id <> s.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk workflow step belongs to a run of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_workflow_waits w JOIN helpdesk.hd_workflow_runs r ON r.id = w.run_id
                WHERE r.tenant_id <> w.tenant_id OR r.bus_id <> w.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk workflow wait belongs to a run of another business';
    END IF;
END $$;

COMMIT;
