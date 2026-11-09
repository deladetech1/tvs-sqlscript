-- Help Desk R2: the approval engine.
--
--   hd_approval_policies      how a request is approved: sequential or parallel, any or all, expiry
--   hd_approval_policy_steps  who approves at each position: a user, the department manager, the
--                             team leads, or a role pool
--   hd_approval_requests      one approval round of a ticket (a resubmission is the next round)
--   hd_approval_tasks         one approver's decision in a request; on_behalf_of is set when an
--                             active delegate decided
--   hd_approval_delegations   who decides for whom, and when
--   hd_approval_events        append-only: the history of every request
--
-- Also the FK from hd_catalog_items.approval_policy_id (20261106-06) to hd_approval_policies.
-- Holding helpdesk|approvals|approve never lets anyone decide on its own: the code also requires
-- being the task's approver or their active delegate (R2.md §4).
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R2.md §3, §4. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== policies
CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_policies (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    name                   text NOT NULL,
    mode                   text NOT NULL CONSTRAINT hd_approval_policies_mode_check CHECK (mode IN ('sequential', 'parallel')),
    rule                   text NOT NULL CONSTRAINT hd_approval_policies_rule_check CHECK (rule IN ('any', 'all')),
    expires_after_minutes  int CONSTRAINT hd_approval_policies_expires_check CHECK (expires_after_minutes > 0),
    on_expiry              text NOT NULL DEFAULT 'reject'
                           CONSTRAINT hd_approval_policies_on_expiry_check CHECK (on_expiry IN ('reject', 'escalate')),
    escalate_to_user_id    text,
    is_active              boolean NOT NULL DEFAULT true,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz,
    updated_by             text
);
CREATE INDEX IF NOT EXISTS hd_approval_policies_business_idx ON helpdesk.hd_approval_policies (tenant_id, bus_id);

ALTER TABLE helpdesk.hd_catalog_items DROP CONSTRAINT IF EXISTS hd_catalog_items_approval_policy_fk;
ALTER TABLE helpdesk.hd_catalog_items ADD CONSTRAINT hd_catalog_items_approval_policy_fk
    FOREIGN KEY (approval_policy_id) REFERENCES helpdesk.hd_approval_policies (id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_policy_steps (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    policy_id      text NOT NULL REFERENCES helpdesk.hd_approval_policies (id),
    position       int NOT NULL DEFAULT 0,
    approver_type  text NOT NULL
                   CONSTRAINT hd_approval_policy_steps_approver_type_check CHECK (approver_type IN ('user', 'department_manager', 'team_leads', 'role')),
    approver_ref   text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text,
    -- A user step names the user, a role step names the role; the other two need no reference.
    CONSTRAINT hd_approval_policy_steps_ref_check CHECK (approver_type NOT IN ('user', 'role') OR approver_ref IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_approval_policy_steps_uq
    ON helpdesk.hd_approval_policy_steps (policy_id, position, approver_type, coalesce(approver_ref, ''));

-- ========================================================================== requests
CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_requests (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    policy_id   text REFERENCES helpdesk.hd_approval_policies (id),
    round       int NOT NULL DEFAULT 1 CONSTRAINT hd_approval_requests_round_check CHECK (round >= 1),
    state       text NOT NULL DEFAULT 'pending'
                CONSTRAINT hd_approval_requests_state_check CHECK (state IN ('pending', 'approved', 'rejected', 'expired', 'cancelled')),
    decided_at  timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_approval_requests_ticket_idx ON helpdesk.hd_approval_requests (ticket_id, round);
CREATE INDEX IF NOT EXISTS hd_approval_requests_business_idx ON helpdesk.hd_approval_requests (tenant_id, bus_id, state);

CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_tasks (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    request_id        text NOT NULL REFERENCES helpdesk.hd_approval_requests (id),
    position          int NOT NULL DEFAULT 0,
    approver_user_id  text,
    approver_role_id  text,
    state             text NOT NULL DEFAULT 'waiting'
                      CONSTRAINT hd_approval_tasks_state_check CHECK (state IN ('waiting', 'pending', 'approved', 'rejected', 'skipped', 'expired')),
    decided_by        text,
    decided_at        timestamptz,
    comment           text,
    due_at            timestamptz,
    on_behalf_of      text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text,
    CONSTRAINT hd_approval_tasks_approver_check CHECK (approver_user_id IS NOT NULL OR approver_role_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_approval_tasks_request_idx ON helpdesk.hd_approval_tasks (request_id, position);
CREATE INDEX IF NOT EXISTS hd_approval_tasks_approver_idx ON helpdesk.hd_approval_tasks (tenant_id, bus_id, approver_user_id, state);
CREATE INDEX IF NOT EXISTS hd_approval_tasks_role_idx ON helpdesk.hd_approval_tasks (tenant_id, bus_id, approver_role_id, state);
-- The expiry job reads pending tasks by due time, across businesses.
CREATE INDEX IF NOT EXISTS hd_approval_tasks_due_idx ON helpdesk.hd_approval_tasks (due_at) WHERE state = 'pending';

-- ======================================================================= delegations
CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_delegations (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    user_id           text NOT NULL,
    delegate_user_id  text NOT NULL,
    starts_on         date NOT NULL,
    ends_on           date NOT NULL,
    is_active         boolean NOT NULL DEFAULT true,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text,
    CONSTRAINT hd_approval_delegations_not_self CHECK (delegate_user_id <> user_id),
    CONSTRAINT hd_approval_delegations_dates_check CHECK (ends_on >= starts_on)
);
CREATE INDEX IF NOT EXISTS hd_approval_delegations_user_idx ON helpdesk.hd_approval_delegations (tenant_id, bus_id, user_id);
CREATE INDEX IF NOT EXISTS hd_approval_delegations_delegate_idx ON helpdesk.hd_approval_delegations (tenant_id, bus_id, delegate_user_id);

-- ============================================================================ events
CREATE TABLE IF NOT EXISTS helpdesk.hd_approval_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    request_id  text NOT NULL REFERENCES helpdesk.hd_approval_requests (id),
    task_id     text REFERENCES helpdesk.hd_approval_tasks (id),
    event       text NOT NULL,
    actor_id    text,
    data        jsonb NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_approval_events_request_idx ON helpdesk.hd_approval_events (request_id, cdatetime);
DROP TRIGGER IF EXISTS hd_approval_events_append_only ON helpdesk.hd_approval_events;
CREATE TRIGGER hd_approval_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_approval_events
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_approval_events'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_approval_events is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_approval_policy_steps s JOIN helpdesk.hd_approval_policies p ON p.id = s.policy_id
                WHERE p.tenant_id <> s.tenant_id OR p.bus_id <> s.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk approval step belongs to a policy of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_catalog_items i JOIN helpdesk.hd_approval_policies p ON p.id = i.approval_policy_id
                WHERE p.tenant_id <> i.tenant_id OR p.bus_id <> i.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk catalogue item uses an approval policy of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_approval_requests r JOIN helpdesk.hd_tickets t ON t.id = r.ticket_id
                WHERE t.tenant_id <> r.tenant_id OR t.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk approval request belongs to a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_approval_tasks k JOIN helpdesk.hd_approval_requests r ON r.id = k.request_id
                WHERE r.tenant_id <> k.tenant_id OR r.bus_id <> k.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk approval task belongs to a request of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_approval_events e JOIN helpdesk.hd_approval_requests r ON r.id = e.request_id
                WHERE r.tenant_id <> e.tenant_id OR r.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk approval event belongs to a request of another business';
    END IF;
END $$;

COMMIT;
