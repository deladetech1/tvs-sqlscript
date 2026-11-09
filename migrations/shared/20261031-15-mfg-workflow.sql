-- Manufacturing: rules, approvals and notifications (design: docs/mfg/03-database-model.md §3.5
-- Workflow; 02-domain-model.md §11; contract R3.md D13-D16, R-10).
--
--   mfg_rules           each row is ONE VERSION of a rule: key, version (1, 2, ...; UNIQUE per
--                       business and key), name, status draft -> tested -> published -> retired,
--                       enabled, definition {"trigger": {"kind", "v"}, "conditions": {"all"|"any":
--                       [...]}, "steps": [{"key", "action", "params"}]} (a typed JSON tree, no CEL in
--                       R3), trigger_kind (copied from the definition so the queue can find enabled
--                       published rules per event kind), preset_key when a preset made it. At most
--                       one published version per key. A published or retired row is frozen by
--                       mfg.mfg_rule_frozen() (below): publishing again means a new version.
--                       lock_version is the optimistic lock (`version` is the rule's version)
--   mfg_rule_queue      events waiting for the rules (D15): written by publish() in the event's own
--                       transaction, only when the business has an enabled published rule for that
--                       kind; drained lazily and by the mfg-workflow-drain job. A queue, not a log:
--                       a drained row is deleted
--   mfg_rule_runs       one run of a rule version for one event, pinned to that version
--                       (rule_version); running | waiting_approval | completed | failed | cancelled,
--                       with outcome (e.g. rejected) and the attempt (a resume adds one)
--   mfg_rule_steps      the run's step timeline (append-only): step key, attempt, status, input,
--                       output, error
--   mfg_approvals       an approval a run asked for: the named user or a role, summary; decision
--                       approved | rejected (NULL while pending) with comment, who and when
--   mfg_notifications   a notification to one user: title, body, link; read or unread; email
--                       wanted or not and how it went (email_status). UNIQUE (bus_id, dedupe_key)
--
-- No product or party column. The CHECK lists live in 20261031-20. No grants. Idempotent; safe to re-run.

BEGIN;

-- ================================================================== freeze trigger
-- A published or retired rule version is frozen. What it still accepts: published -> retired (with
-- retired_at), enabled on a published version, lock_version, updated_at, updated_by. DELETE only by
-- the unsubscribe purge. mfg_freeze_released (20261029-40) knows the revision statuses
-- (released/superseded/obsolete), not the rule ones, so rules have their own, as R2's cost sets do.
CREATE OR REPLACE FUNCTION mfg.mfg_rule_frozen() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    lifecycle constant text[] := ARRAY['status', 'enabled', 'retired_at', 'lock_version', 'updated_at', 'updated_by'];
    o jsonb := to_jsonb(OLD);
    n jsonb;
BEGIN
    IF OLD.status NOT IN ('published', 'retired') THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;
    IF TG_OP = 'DELETE' THEN
        IF mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION 'mfg.mfg_rules %: a % rule version cannot be deleted', OLD.id, OLD.status
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    n := to_jsonb(NEW);
    IF (n - lifecycle) = (o - lifecycle)
       AND ((OLD.status = 'published' AND NEW.status = 'published')
            OR (OLD.status = 'published' AND NEW.status = 'retired')
            OR (OLD.status = 'retired' AND NEW.status = 'retired' AND NEW.enabled = OLD.enabled)) THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'mfg.mfg_rules %: a % rule version is frozen; edit it as a new version instead', OLD.id, OLD.status
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;

-- =========================================================================== rules
CREATE TABLE IF NOT EXISTS mfg.mfg_rules (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    key               text NOT NULL,              -- the rule; its versions share it
    version           integer NOT NULL DEFAULT 1, -- the rule's version (runs pin it)
    name              text NOT NULL,
    description       text,
    status            text NOT NULL DEFAULT 'draft',
    enabled           boolean NOT NULL DEFAULT false,
    trigger_kind      text NOT NULL,              -- definition.trigger.kind, an mfg event kind
    definition        jsonb NOT NULL,
    preset_key        text,                       -- the preset it was made from
    dry_run_report    jsonb,                      -- the last dry run: per event matched, per step what it would do
    tested_at         timestamptz,
    tested_by         text,
    published_at      timestamptz,
    published_by      text,                       -- the rule acts with this user's permissions (D14)
    retired_at        timestamptz,
    lock_version      integer NOT NULL DEFAULT 1, -- optimistic lock for PATCH (draft only)
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_rules_key_version_uq ON mfg.mfg_rules (bus_id, key, version);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_rules_published_uq ON mfg.mfg_rules (bus_id, key) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS mfg_rules_trigger_idx ON mfg.mfg_rules (bus_id, trigger_kind) WHERE status = 'published' AND enabled;
CREATE INDEX IF NOT EXISTS mfg_rules_list_idx ON mfg.mfg_rules (bus_id, status, key);
ALTER TABLE mfg.mfg_rules DROP CONSTRAINT IF EXISTS mfg_rules_rules_check;
ALTER TABLE mfg.mfg_rules ADD CONSTRAINT mfg_rules_rules_check
    CHECK (version >= 1 AND btrim(key) <> ''
           AND jsonb_typeof(definition) = 'object'
           AND (status <> 'published' OR (published_at IS NOT NULL AND published_by IS NOT NULL))
           AND (status <> 'retired' OR retired_at IS NOT NULL)
           AND (NOT enabled OR status = 'published'));

DROP TRIGGER IF EXISTS mfg_rules_freeze ON mfg.mfg_rules;
CREATE TRIGGER mfg_rules_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_rules
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_rule_frozen();

-- ===================================================================== rule queue
CREATE TABLE IF NOT EXISTS mfg.mfg_rule_queue (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    event_id          text NOT NULL,              -- the cp_events row publish() wrote
    kind              text NOT NULL,              -- the event kind
    subject_type      text,
    subject_id        text,
    payload           jsonb NOT NULL DEFAULT '{}',
    enqueued_at       timestamptz NOT NULL DEFAULT now(),
    claimed_at        timestamptz,                -- a drain holds it (FOR UPDATE SKIP LOCKED)
    attempts          integer NOT NULL DEFAULT 0,
    last_error        text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_rule_queue_event_uq ON mfg.mfg_rule_queue (bus_id, event_id);
CREATE INDEX IF NOT EXISTS mfg_rule_queue_drain_idx ON mfg.mfg_rule_queue (bus_id, enqueued_at);
COMMENT ON TABLE mfg.mfg_rule_queue IS
    'Events waiting for the rules (R3 D15). Enqueue: in publish(), only when an enabled published rule has that trigger_kind. Drain: claim with FOR UPDATE SKIP LOCKED, make the runs, DELETE.';

-- ======================================================================= rule runs
CREATE TABLE IF NOT EXISTS mfg.mfg_rule_runs (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    rule_id           text NOT NULL REFERENCES mfg.mfg_rules (id),   -- the pinned version's row
    rule_key          text NOT NULL,
    rule_version      integer NOT NULL,           -- pinned at start (R-10)
    event_id          text NOT NULL,
    trigger_kind      text NOT NULL,
    subject_type      text,
    subject_id        text,
    payload           jsonb NOT NULL DEFAULT '{}',   -- the event as the rule saw it
    status            text NOT NULL DEFAULT 'running',
    outcome           text,                       -- e.g. approved | rejected | done
    current_step      text,
    attempt           integer NOT NULL DEFAULT 1, -- a resume adds one
    error             text,
    started_at        timestamptz NOT NULL DEFAULT now(),
    finished_at       timestamptz,
    resumed_at        timestamptz,
    resumed_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
-- A rule version runs once per event, however many drains see it.
CREATE UNIQUE INDEX IF NOT EXISTS mfg_rule_runs_event_uq ON mfg.mfg_rule_runs (rule_id, event_id);
CREATE INDEX IF NOT EXISTS mfg_rule_runs_rule_idx ON mfg.mfg_rule_runs (bus_id, rule_key, started_at DESC);
CREATE INDEX IF NOT EXISTS mfg_rule_runs_status_idx ON mfg.mfg_rule_runs (bus_id, status) WHERE status IN ('running', 'waiting_approval', 'failed');
ALTER TABLE mfg.mfg_rule_runs DROP CONSTRAINT IF EXISTS mfg_rule_runs_rules_check;
ALTER TABLE mfg.mfg_rule_runs ADD CONSTRAINT mfg_rule_runs_rules_check
    CHECK (attempt >= 1 AND rule_version >= 1
           AND ((status IN ('completed', 'failed', 'cancelled')) = (finished_at IS NOT NULL)));

CREATE TABLE IF NOT EXISTS mfg.mfg_rule_steps (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    run_id            text NOT NULL REFERENCES mfg.mfg_rule_runs (id),
    seq               integer NOT NULL,           -- the step's place in the definition
    step_key          text NOT NULL,
    action            text NOT NULL,
    attempt           integer NOT NULL DEFAULT 1,
    status            text NOT NULL,
    input             jsonb NOT NULL DEFAULT '{}',
    output            jsonb NOT NULL DEFAULT '{}',
    error             text,                       -- e.g. FORBIDDEN when the publisher lost the permission
    at                timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_rule_steps_run_idx ON mfg.mfg_rule_steps (run_id, at);

DROP TRIGGER IF EXISTS mfg_rule_steps_append_only ON mfg.mfg_rule_steps;
CREATE TRIGGER mfg_rule_steps_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_rule_steps
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ======================================================================= approvals
CREATE TABLE IF NOT EXISTS mfg.mfg_approvals (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    run_id            text REFERENCES mfg.mfg_rule_runs (id),
    step_key          text,
    subject_type      text NOT NULL,              -- e.g. maintenance_order
    subject_id        text NOT NULL,
    summary           text NOT NULL,
    approver_role     text,                       -- a role id (cp_roles.id)
    approver_user_id  text,
    requested_by      text,                       -- the rule's publisher, or the user
    requested_at      timestamptz NOT NULL DEFAULT now(),
    decision          text,                       -- approved | rejected; NULL while pending
    comment           text,
    decided_by        text,
    decided_at        timestamptz,
    version           integer NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_approvals_pending_idx ON mfg.mfg_approvals (bus_id, requested_at) WHERE decision IS NULL;
CREATE INDEX IF NOT EXISTS mfg_approvals_user_idx ON mfg.mfg_approvals (bus_id, approver_user_id) WHERE approver_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_approvals_subject_idx ON mfg.mfg_approvals (bus_id, subject_type, subject_id);
CREATE INDEX IF NOT EXISTS mfg_approvals_run_idx ON mfg.mfg_approvals (run_id) WHERE run_id IS NOT NULL;
ALTER TABLE mfg.mfg_approvals DROP CONSTRAINT IF EXISTS mfg_approvals_rules_check;
ALTER TABLE mfg.mfg_approvals ADD CONSTRAINT mfg_approvals_rules_check
    CHECK ((approver_role IS NOT NULL OR approver_user_id IS NOT NULL)
           AND ((decision IS NULL) = (decided_at IS NULL))
           AND (decision IS DISTINCT FROM 'rejected' OR nullif(btrim(comment), '') IS NOT NULL));

-- =================================================================== notifications
CREATE TABLE IF NOT EXISTS mfg.mfg_notifications (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    user_id           text NOT NULL,              -- the recipient
    channel           text NOT NULL DEFAULT 'in_app',   -- in_app | email
    title             text NOT NULL,
    body              text,
    link_type         text,                       -- what it is about, e.g. maintenance_order
    link_id           text,
    source_type       text,                       -- rule_run | approval | system
    source_id         text,
    dedupe_key        text NOT NULL,
    status            text NOT NULL DEFAULT 'unread',   -- unread | read
    read_at           timestamptz,
    email_status      text,                       -- pending | sent | failed | skipped; NULL when no email was asked
    email_error       text,
    emailed_at        timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_notifications_dedupe_uq ON mfg.mfg_notifications (bus_id, dedupe_key);
CREATE INDEX IF NOT EXISTS mfg_notifications_user_idx ON mfg.mfg_notifications (bus_id, user_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_notifications_unread_idx ON mfg.mfg_notifications (bus_id, user_id) WHERE status = 'unread';
CREATE INDEX IF NOT EXISTS mfg_notifications_email_idx ON mfg.mfg_notifications (bus_id, cdatetime) WHERE email_status = 'pending';
ALTER TABLE mfg.mfg_notifications DROP CONSTRAINT IF EXISTS mfg_notifications_rules_check;
ALTER TABLE mfg.mfg_notifications ADD CONSTRAINT mfg_notifications_rules_check
    CHECK ((status = 'read') = (read_at IS NOT NULL));

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_rule_steps'::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_rule_steps is not append-only: its mfg_refuse_change trigger is missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'mfg.mfg_rules'::regclass AND p.proname = 'mfg_rule_frozen' AND NOT g.tgisinternal) THEN
        RAISE EXCEPTION 'mfg.mfg_rules has no freeze trigger: a published rule version could change under its runs';
    END IF;
    FOREACH t IN ARRAY ARRAY['mfg_rules_key_version_uq', 'mfg_rules_published_uq', 'mfg_rule_runs_event_uq',
                             'mfg_rule_queue_event_uq', 'mfg_notifications_dedupe_uq'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'mfg' AND indexname = t) THEN
            RAISE EXCEPTION 'mfg unique index % is missing', t;
        END IF;
    END LOOP;
END $$;

COMMIT;
