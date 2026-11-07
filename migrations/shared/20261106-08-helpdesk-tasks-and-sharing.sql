-- Help Desk R2: fulfilment tasks, time entries and sharing a ticket with another department.
--
--   hd_tasks                      work on a ticket, optionally nested, with an optimistic-lock version
--   hd_task_dependencies          a task waits for another (never itself)
--   hd_task_checklist_items       a task's checklist
--   hd_time_entries               minutes worked on a ticket or one of its tasks, per day
--   hd_fulfilment_templates       the tasks a catalogue item creates (one template per item)
--   hd_fulfilment_template_tasks  the template's tasks, by position, with dependencies by position
--   hd_ticket_shares              another department may read, or collaborate on, a ticket
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R2.md §3. Idempotent; safe to re-run.

BEGIN;

-- ============================================================================= tasks
CREATE TABLE IF NOT EXISTS helpdesk.hd_tasks (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    ticket_id         text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    parent_task_id    text REFERENCES helpdesk.hd_tasks (id),
    title             text NOT NULL,
    description       text,
    assignee_user_id  text,
    team_id           text REFERENCES helpdesk.hd_teams (id),
    state             text NOT NULL DEFAULT 'open'
                      CONSTRAINT hd_tasks_state_check CHECK (state IN ('open', 'in_progress', 'blocked', 'done', 'cancelled')),
    due_at            timestamptz,
    position          int NOT NULL DEFAULT 0,
    completed_at      timestamptz,
    version           int NOT NULL DEFAULT 1,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text,
    CONSTRAINT hd_tasks_not_own_parent CHECK (parent_task_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS hd_tasks_ticket_idx ON helpdesk.hd_tasks (ticket_id, position);
CREATE INDEX IF NOT EXISTS hd_tasks_assignee_idx ON helpdesk.hd_tasks (tenant_id, bus_id, assignee_user_id, state);
CREATE INDEX IF NOT EXISTS hd_tasks_team_idx ON helpdesk.hd_tasks (tenant_id, bus_id, team_id, state);

CREATE TABLE IF NOT EXISTS helpdesk.hd_task_dependencies (
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    task_id             text NOT NULL REFERENCES helpdesk.hd_tasks (id),
    depends_on_task_id  text NOT NULL REFERENCES helpdesk.hd_tasks (id),
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text,
    PRIMARY KEY (task_id, depends_on_task_id),
    CONSTRAINT hd_task_dependencies_not_self CHECK (task_id <> depends_on_task_id)
);
CREATE INDEX IF NOT EXISTS hd_task_dependencies_on_idx ON helpdesk.hd_task_dependencies (depends_on_task_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_task_checklist_items (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    task_id     text NOT NULL REFERENCES helpdesk.hd_tasks (id),
    label       text NOT NULL,
    is_done     boolean NOT NULL DEFAULT false,
    done_by     text,
    done_at     timestamptz,
    position    int NOT NULL DEFAULT 0,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_task_checklist_items_task_idx ON helpdesk.hd_task_checklist_items (task_id, position);

-- ====================================================================== time entries
CREATE TABLE IF NOT EXISTS helpdesk.hd_time_entries (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    task_id     text REFERENCES helpdesk.hd_tasks (id),
    user_id     text NOT NULL,
    minutes     int NOT NULL CONSTRAINT hd_time_entries_minutes_check CHECK (minutes > 0 AND minutes <= 1440),
    work_date   date NOT NULL,
    note        text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_time_entries_ticket_idx ON helpdesk.hd_time_entries (ticket_id, work_date);
CREATE INDEX IF NOT EXISTS hd_time_entries_user_idx ON helpdesk.hd_time_entries (tenant_id, bus_id, user_id, work_date);

-- ============================================================= fulfilment templates
CREATE TABLE IF NOT EXISTS helpdesk.hd_fulfilment_templates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    item_id     text NOT NULL REFERENCES helpdesk.hd_catalog_items (id),
    name        text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_fulfilment_templates_item_uq ON helpdesk.hd_fulfilment_templates (item_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_fulfilment_template_tasks (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    bus_id                text NOT NULL,
    template_id           text NOT NULL REFERENCES helpdesk.hd_fulfilment_templates (id),
    position              int NOT NULL,
    title                 text NOT NULL,
    description           text,
    team_id               text REFERENCES helpdesk.hd_teams (id),
    depends_on_positions  int[] NOT NULL DEFAULT '{}',
    due_offset_minutes    int CONSTRAINT hd_fulfilment_template_tasks_due_offset_check CHECK (due_offset_minutes >= 0),
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz,
    updated_by            text,
    CONSTRAINT hd_fulfilment_template_tasks_not_self CHECK (NOT (position = ANY (depends_on_positions)))
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_fulfilment_template_tasks_position_uq
    ON helpdesk.hd_fulfilment_template_tasks (template_id, position);

-- ============================================================================ shares
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_shares (
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    ticket_id      text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    department_id  text NOT NULL REFERENCES helpdesk.hd_departments (id),
    access         text NOT NULL DEFAULT 'read'
                   CONSTRAINT hd_ticket_shares_access_check CHECK (access IN ('read', 'collaborate')),
    shared_by      text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text,
    PRIMARY KEY (ticket_id, department_id)
);
CREATE INDEX IF NOT EXISTS hd_ticket_shares_department_idx ON helpdesk.hd_ticket_shares (tenant_id, bus_id, department_id);

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tasks k JOIN helpdesk.hd_tickets t ON t.id = k.ticket_id
                WHERE t.tenant_id <> k.tenant_id OR t.bus_id <> k.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk task belongs to a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tasks k JOIN helpdesk.hd_tasks p ON p.id = k.parent_task_id
                WHERE p.ticket_id <> k.ticket_id) THEN
        RAISE EXCEPTION 'a Help Desk task is nested under a task of another ticket';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_task_dependencies d
                 JOIN helpdesk.hd_tasks a ON a.id = d.task_id
                 JOIN helpdesk.hd_tasks b ON b.id = d.depends_on_task_id
                WHERE a.tenant_id <> b.tenant_id OR a.bus_id <> b.bus_id OR a.tenant_id <> d.tenant_id OR a.bus_id <> d.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk task depends on a task of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_time_entries e JOIN helpdesk.hd_tickets t ON t.id = e.ticket_id
                WHERE t.tenant_id <> e.tenant_id OR t.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk time entry belongs to a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_time_entries e JOIN helpdesk.hd_tasks k ON k.id = e.task_id
                WHERE k.ticket_id <> e.ticket_id) THEN
        RAISE EXCEPTION 'a Help Desk time entry names a task of another ticket';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_fulfilment_templates f JOIN helpdesk.hd_catalog_items i ON i.id = f.item_id
                WHERE i.tenant_id <> f.tenant_id OR i.bus_id <> f.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk fulfilment template belongs to an item of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_shares s
                 JOIN helpdesk.hd_tickets t ON t.id = s.ticket_id
                 JOIN helpdesk.hd_departments d ON d.id = s.department_id
                WHERE t.tenant_id <> s.tenant_id OR t.bus_id <> s.bus_id OR d.tenant_id <> s.tenant_id OR d.bus_id <> s.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket is shared across businesses';
    END IF;
END $$;

COMMIT;
