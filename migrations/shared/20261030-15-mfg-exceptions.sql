-- Manufacturing: exceptions rolled up by root cause (design: docs/mfg/03-database-model.md §3.5
-- Insight, §5, §7; 02-domain-model.md §12; contract R2.md C11, R-9).
--
--   mfg_exceptions          ONE ROW PER ROOT CAUSE: one short component is one exception that lists
--                           every order it hurts. root_key (e.g. shortage:<plant>:<product>,
--                           resource_down:<resource>) is unique per business while the exception
--                           is open | acknowledged | in_resolution; once resolved or dismissed the
--                           same cause may open a new row. affected is the list of what it hurts
--                           [{type, id, label, impact}], impact the totals, playbooks the fixes it
--                           declares (expedite, alternate_source, reschedule, open_scenario).
--                           exceptionsRefresh(business) keeps them: it upserts on root_key, rewrites
--                           affected and last_seen_at, and resolves (auto) the ones whose cause is
--                           gone. Sources (C11): MRP messages, short material on released orders,
--                           failed inspections, NCRs open over 7 days, resources down with booked
--                           operations
--   mfg_exception_events    APPEND-ONLY; what happened to an exception: opened, updated,
--                           acknowledged, assigned, resolved, dismissed (reason), reopened,
--                           playbook_run (with its params and result). Time to resolve and the
--                           dismissal rate per rule_key come from here
--
-- The CHECK lists live in 20261030-17 (planning and exceptions). No product or party column: the
-- root and the affected subjects are ids by type. No grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_exceptions (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    plant_id            text REFERENCES mfg.mfg_plants (id),
    kind                text NOT NULL,
    severity            text NOT NULL DEFAULT 'medium',
    rule_key            text NOT NULL,             -- the rule that raised it, for time-to-resolve and dismissal stats
    root_key            text NOT NULL,             -- the root cause, e.g. shortage:<plant_id>:<product_id>
    root_type           text NOT NULL,             -- the API's root_cause_type: item | resource | lot | inspection | ncr | planned_order | production_order
    root_id             text NOT NULL,             -- the API's root_cause_id
    title               text NOT NULL,
    summary             text,
    affected            jsonb NOT NULL DEFAULT '[]',   -- [{"type", "id", "label", "due", "customer_name", "value"}]
    impact              jsonb NOT NULL DEFAULT '{}',   -- {"orders", "customers", "value", "currency", "worst_late_days"}
    playbooks           jsonb NOT NULL DEFAULT '[]',   -- [{"key", "label", "enabled", "disabled_reason", "target"}]
    status              text NOT NULL DEFAULT 'open',
    owner_id            text,                      -- assigned user
    sla_due_at          timestamptz,               -- when it should be resolved by
    opened_at           timestamptz NOT NULL DEFAULT now(),
    last_seen_at        timestamptz NOT NULL DEFAULT now(),   -- the last refresh that still found the cause
    acknowledged_at     timestamptz,
    acknowledged_by     text,
    assigned_at         timestamptz,
    assigned_by         text,
    resolved_at         timestamptz,
    resolved_by         text,                      -- NULL when the refresh resolved it
    resolution_note     text,
    dismissed_at        timestamptz,
    dismissed_by        text,
    dismissed_reason    text,
    version             integer NOT NULL DEFAULT 1,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_exceptions_root_open_uq
    ON mfg.mfg_exceptions (bus_id, root_key) WHERE status IN ('open', 'acknowledged', 'in_resolution');
CREATE INDEX IF NOT EXISTS mfg_exceptions_board_idx
    ON mfg.mfg_exceptions (bus_id, status, severity) WHERE status NOT IN ('resolved', 'dismissed');
CREATE INDEX IF NOT EXISTS mfg_exceptions_rule_idx ON mfg.mfg_exceptions (bus_id, rule_key, opened_at);
ALTER TABLE mfg.mfg_exceptions DROP CONSTRAINT IF EXISTS mfg_exceptions_lifecycle_check;
ALTER TABLE mfg.mfg_exceptions ADD CONSTRAINT mfg_exceptions_lifecycle_check
    CHECK ((status <> 'resolved' OR resolved_at IS NOT NULL)
           AND (status <> 'dismissed' OR (dismissed_at IS NOT NULL AND dismissed_reason IS NOT NULL))
           AND jsonb_typeof(affected) = 'array' AND jsonb_typeof(playbooks) = 'array');

CREATE TABLE IF NOT EXISTS mfg.mfg_exception_events (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    exception_id   text NOT NULL REFERENCES mfg.mfg_exceptions (id),
    kind           text NOT NULL,
    playbook       text,                          -- playbook_run: its key
    params         jsonb NOT NULL DEFAULT '{}',
    result         jsonb NOT NULL DEFAULT '{}',
    note           text,
    actor          text,                          -- NULL when the refresh did it
    at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_exception_events_exception_idx ON mfg.mfg_exception_events (exception_id, at);

DROP TRIGGER IF EXISTS mfg_exception_events_append_only ON mfg.mfg_exception_events;
CREATE TRIGGER mfg_exception_events_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_exception_events
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_exception_events'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_exception_events is not append-only: its mfg_refuse_change trigger is missing';
    END IF;
    -- One open exception per root cause (also the unique index; asserted so it can't be dropped quietly).
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = 'mfg_exceptions_root_open_uq') THEN
        RAISE EXCEPTION 'mfg.mfg_exceptions has no unique root_key while open';
    END IF;
END $$;

COMMIT;
