-- Help Desk R3: change management.
--
--   hd_change_templates     standard changes; a standard change from an active template skips CAB
--   hd_changes              standard, normal and emergency changes: risk and impact, plans, state,
--                           schedule, outcome, approval policy (CAB through the R2 engine)
--   hd_maintenance_windows  recurring (weekday and minutes) or one-off (starts_at / ends_at)
--                           windows, for everything or one CI
--   hd_change_cis           CIs a change touches
--   hd_change_tickets       tickets a change caused, resolves or relates to
--   hd_change_problems      problems a change addresses
--   hd_change_events        append-only: the change's state history
--   hd_approval_requests    an approval request is for a ticket or a change, exactly one
--
-- hd_maintenance_windows.ci_id and hd_change_cis.ci_id get their FK in 20261106-13, which creates
-- hd_cis. CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R3.md §3. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================= templates
CREATE TABLE IF NOT EXISTS helpdesk.hd_change_templates (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    name         text NOT NULL,
    description  text,
    defaults     jsonb NOT NULL DEFAULT '{}',
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text
);
CREATE INDEX IF NOT EXISTS hd_change_templates_business_idx ON helpdesk.hd_change_templates (tenant_id, bus_id);

-- =========================================================================== changes
CREATE TABLE IF NOT EXISTS helpdesk.hd_changes (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    number               text NOT NULL,
    title                text NOT NULL,
    description          text,
    change_type          text NOT NULL
                         CONSTRAINT hd_changes_change_type_check CHECK (change_type IN ('standard', 'normal', 'emergency')),
    category_id          text REFERENCES helpdesk.hd_categories (id),
    justification        text,
    impact               text CONSTRAINT hd_changes_impact_check CHECK (impact IN ('low', 'medium', 'high')),
    risk                 text CONSTRAINT hd_changes_risk_check CHECK (risk IN ('low', 'medium', 'high')),
    risk_score           int,
    risk_answers         jsonb NOT NULL DEFAULT '{}',
    implementation_plan  text,
    rollback_plan        text,
    test_plan            text,
    owner_user_id        text,
    team_id              text REFERENCES helpdesk.hd_teams (id),
    department_id        text REFERENCES helpdesk.hd_departments (id),
    state                text NOT NULL DEFAULT 'draft'
                         CONSTRAINT hd_changes_state_check CHECK (state IN ('draft', 'submitted', 'awaiting_approval', 'scheduled',
                             'implementing', 'review', 'closed', 'rejected', 'cancelled')),
    planned_start        timestamptz,
    planned_end          timestamptz,
    actual_start         timestamptz,
    actual_end           timestamptz,
    outcome              text CONSTRAINT hd_changes_outcome_check CHECK (outcome IN ('successful', 'partially_successful', 'failed', 'rolled_back')),
    approval_policy_id   text REFERENCES helpdesk.hd_approval_policies (id),
    template_id          text REFERENCES helpdesk.hd_change_templates (id),
    version              int NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    CONSTRAINT hd_changes_planned_check CHECK (planned_end IS NULL OR planned_start IS NULL OR planned_end >= planned_start),
    CONSTRAINT hd_changes_actual_check CHECK (actual_end IS NULL OR actual_start IS NULL OR actual_end >= actual_start)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_changes_number_uq ON helpdesk.hd_changes (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS hd_changes_business_idx ON helpdesk.hd_changes (tenant_id, bus_id, state);
-- The change calendar reads changes by planned time.
CREATE INDEX IF NOT EXISTS hd_changes_calendar_idx ON helpdesk.hd_changes (tenant_id, bus_id, planned_start, planned_end);

-- =============================================================== maintenance windows
-- Recurring: weekday (NULL = every day) with start and end minutes. One-off: starts_at and ends_at.
CREATE TABLE IF NOT EXISTS helpdesk.hd_maintenance_windows (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    timezone      text NOT NULL DEFAULT 'UTC',
    weekday       int CONSTRAINT hd_maintenance_windows_weekday_check CHECK (weekday BETWEEN 0 AND 6),
    start_minute  int,
    end_minute    int,
    starts_at     timestamptz,
    ends_at       timestamptz,
    ci_id         text,
    is_active     boolean NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text,
    CONSTRAINT hd_maintenance_windows_shape_check CHECK (
        (starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at > starts_at)
        OR (starts_at IS NULL AND ends_at IS NULL AND start_minute IS NOT NULL AND end_minute IS NOT NULL
            AND 0 <= start_minute AND start_minute < end_minute AND end_minute <= 1440))
);
CREATE INDEX IF NOT EXISTS hd_maintenance_windows_business_idx ON helpdesk.hd_maintenance_windows (tenant_id, bus_id, ci_id);

-- ======================================================================= link tables
CREATE TABLE IF NOT EXISTS helpdesk.hd_change_cis (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    change_id   text NOT NULL REFERENCES helpdesk.hd_changes (id),
    ci_id       text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (change_id, ci_id)
);
CREATE INDEX IF NOT EXISTS hd_change_cis_ci_idx ON helpdesk.hd_change_cis (ci_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_change_tickets (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    change_id   text NOT NULL REFERENCES helpdesk.hd_changes (id),
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    relation    text NOT NULL DEFAULT 'related'
                CONSTRAINT hd_change_tickets_relation_check CHECK (relation IN ('caused_by', 'resolves', 'related')),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (change_id, ticket_id)
);
CREATE INDEX IF NOT EXISTS hd_change_tickets_ticket_idx ON helpdesk.hd_change_tickets (ticket_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_change_problems (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    change_id   text NOT NULL REFERENCES helpdesk.hd_changes (id),
    problem_id  text NOT NULL REFERENCES helpdesk.hd_problems (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (change_id, problem_id)
);
CREATE INDEX IF NOT EXISTS hd_change_problems_problem_idx ON helpdesk.hd_change_problems (problem_id);

-- ============================================================================ events
CREATE TABLE IF NOT EXISTS helpdesk.hd_change_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    change_id   text NOT NULL REFERENCES helpdesk.hd_changes (id),
    from_state  text,
    to_state    text NOT NULL,
    actor_id    text,
    data        jsonb NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_change_events_change_idx ON helpdesk.hd_change_events (change_id, cdatetime);
DROP TRIGGER IF EXISTS hd_change_events_append_only ON helpdesk.hd_change_events;
CREATE TRIGGER hd_change_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_change_events
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ================================================================ approval requests
-- An approval request is now for a ticket or a change (CAB), exactly one of the two.
ALTER TABLE helpdesk.hd_approval_requests ALTER COLUMN ticket_id DROP NOT NULL;
ALTER TABLE helpdesk.hd_approval_requests ADD COLUMN IF NOT EXISTS change_id text REFERENCES helpdesk.hd_changes (id);
ALTER TABLE helpdesk.hd_approval_requests DROP CONSTRAINT IF EXISTS hd_approval_requests_subject_check;
ALTER TABLE helpdesk.hd_approval_requests ADD CONSTRAINT hd_approval_requests_subject_check
    CHECK (num_nonnulls(ticket_id, change_id) = 1);
CREATE INDEX IF NOT EXISTS hd_approval_requests_change_idx ON helpdesk.hd_approval_requests (change_id, round);

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_change_events'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_change_events is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_changes c JOIN helpdesk.hd_approval_policies p ON p.id = c.approval_policy_id
                WHERE p.tenant_id <> c.tenant_id OR p.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change uses an approval policy of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_changes c JOIN helpdesk.hd_change_templates t ON t.id = c.template_id
                WHERE t.tenant_id <> c.tenant_id OR t.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change uses a template of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_approval_requests r JOIN helpdesk.hd_changes c ON c.id = r.change_id
                WHERE c.tenant_id <> r.tenant_id OR c.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk approval request belongs to a change of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_change_tickets l
                 JOIN helpdesk.hd_changes c ON c.id = l.change_id
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                WHERE c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id OR t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change links a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_change_problems l
                 JOIN helpdesk.hd_changes c ON c.id = l.change_id
                 JOIN helpdesk.hd_problems p ON p.id = l.problem_id
                WHERE c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id OR p.tenant_id <> l.tenant_id OR p.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change links a problem of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_change_events e JOIN helpdesk.hd_changes c ON c.id = e.change_id
                WHERE c.tenant_id <> e.tenant_id OR c.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change event belongs to a change of another business';
    END IF;
END $$;

COMMIT;
