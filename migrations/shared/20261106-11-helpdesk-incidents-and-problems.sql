-- Help Desk R3: incidents (impact x urgency, major incidents, reviews) and problems.
--
--   hd_tickets.impact, .urgency, .vendor_party_id
--   hd_priority_matrix              impact x urgency -> priority, per business
--   hd_number_series                PRB-, CHG-, AST- numbering per business
--   hd_major_incidents              the coordination room of one incident ticket
--   hd_major_incident_tickets       tickets linked to a major incident
--   hd_major_incident_stakeholders  who gets the stakeholder updates
--   hd_incident_updates             append-only: updates posted, by audience
--   hd_reviews                      post-incident and post-implementation reviews
--   hd_review_actions               actions a review assigns
--   hd_problems                     problems, root cause, workaround and known-error article
--   hd_rca_entries                  Five Whys, Fishbone and 8D entries
--   hd_problem_tickets              tickets a problem explains
--   hd_problem_actions              corrective and preventive actions
--
-- hd_tickets.vendor_party_id is a Core party (core_platform.cp_parties); it is registered in
-- cp_party_references so a party merge re-points it (20261106-13 registers the other party columns).
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R3.md §3. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== tickets
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS impact text
    CONSTRAINT hd_tickets_impact_check CHECK (impact IN ('low', 'medium', 'high'));
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS urgency text
    CONSTRAINT hd_tickets_urgency_check CHECK (urgency IN ('low', 'medium', 'high'));
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS vendor_party_id text;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_party_references') IS NOT NULL THEN
        INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension)
        VALUES ('helpdesk.hd_tickets', 'vendor_party_id', false)
        ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
    END IF;
END $$;

-- =================================================================== priority matrix
CREATE TABLE IF NOT EXISTS helpdesk.hd_priority_matrix (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    impact      text NOT NULL CONSTRAINT hd_priority_matrix_impact_check CHECK (impact IN ('low', 'medium', 'high')),
    urgency     text NOT NULL CONSTRAINT hd_priority_matrix_urgency_check CHECK (urgency IN ('low', 'medium', 'high')),
    priority    text NOT NULL CONSTRAINT hd_priority_matrix_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (tenant_id, bus_id, impact, urgency)
);

-- ===================================================================== number series
CREATE TABLE IF NOT EXISTS helpdesk.hd_number_series (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    kind        text NOT NULL CONSTRAINT hd_number_series_kind_check CHECK (kind IN ('problem', 'change', 'asset')),
    prefix      text NOT NULL,
    next_value  bigint NOT NULL DEFAULT 1 CONSTRAINT hd_number_series_next_value_check CHECK (next_value >= 1),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (tenant_id, bus_id, kind)
);

-- =================================================================== major incidents
CREATE TABLE IF NOT EXISTS helpdesk.hd_major_incidents (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    ticket_id          text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    state              text NOT NULL DEFAULT 'declared'
                       CONSTRAINT hd_major_incidents_state_check CHECK (state IN ('declared', 'investigating', 'identified', 'monitoring', 'resolved', 'closed')),
    commander_user_id  text,
    summary            text,
    customer_impact    text,
    declared_at        timestamptz NOT NULL DEFAULT now(),
    resolved_at        timestamptz,
    closed_at          timestamptz,
    pir_due_on         date,
    version            int NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz,
    updated_by         text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_major_incidents_ticket_uq ON helpdesk.hd_major_incidents (ticket_id);
CREATE INDEX IF NOT EXISTS hd_major_incidents_business_idx ON helpdesk.hd_major_incidents (tenant_id, bus_id, state);

CREATE TABLE IF NOT EXISTS helpdesk.hd_major_incident_tickets (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    major_id    text NOT NULL REFERENCES helpdesk.hd_major_incidents (id),
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (major_id, ticket_id)
);
CREATE INDEX IF NOT EXISTS hd_major_incident_tickets_ticket_idx ON helpdesk.hd_major_incident_tickets (ticket_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_major_incident_stakeholders (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    major_id    text NOT NULL REFERENCES helpdesk.hd_major_incidents (id),
    user_id     text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (major_id, user_id)
);

CREATE TABLE IF NOT EXISTS helpdesk.hd_incident_updates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    major_id    text NOT NULL REFERENCES helpdesk.hd_major_incidents (id),
    audience    text NOT NULL CONSTRAINT hd_incident_updates_audience_check CHECK (audience IN ('internal', 'stakeholders', 'public')),
    state       text NOT NULL
                CONSTRAINT hd_incident_updates_state_check CHECK (state IN ('declared', 'investigating', 'identified', 'monitoring', 'resolved', 'closed')),
    body        text NOT NULL,
    posted_by   text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_incident_updates_major_idx ON helpdesk.hd_incident_updates (major_id, cdatetime);
DROP TRIGGER IF EXISTS hd_incident_updates_append_only ON helpdesk.hd_incident_updates;
CREATE TRIGGER hd_incident_updates_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_incident_updates
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- =========================================================================== reviews
-- subject_id is a major incident or a change, by subject_type; one review per subject.
CREATE TABLE IF NOT EXISTS helpdesk.hd_reviews (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    subject_type  text NOT NULL CONSTRAINT hd_reviews_subject_type_check CHECK (subject_type IN ('major_incident', 'change')),
    subject_id    text NOT NULL,
    summary       text,
    timeline      jsonb NOT NULL DEFAULT '[]',
    root_cause    text,
    went_well     text,
    went_wrong    text,
    completed_by  text,
    completed_at  timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_reviews_subject_uq ON helpdesk.hd_reviews (subject_type, subject_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_review_actions (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    review_id      text NOT NULL REFERENCES helpdesk.hd_reviews (id),
    title          text NOT NULL,
    owner_user_id  text,
    due_on         date,
    state          text NOT NULL DEFAULT 'open' CONSTRAINT hd_review_actions_state_check CHECK (state IN ('open', 'done', 'cancelled')),
    done_at        timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_review_actions_review_idx ON helpdesk.hd_review_actions (review_id);
CREATE INDEX IF NOT EXISTS hd_review_actions_owner_idx ON helpdesk.hd_review_actions (tenant_id, bus_id, owner_user_id, state);

-- ========================================================================== problems
CREATE TABLE IF NOT EXISTS helpdesk.hd_problems (
    id                      text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id               text NOT NULL,
    bus_id                  text NOT NULL,
    number                  text NOT NULL,
    title                   text NOT NULL,
    description             text,
    state                   text NOT NULL DEFAULT 'new'
                            CONSTRAINT hd_problems_state_check CHECK (state IN ('new', 'investigating', 'root_cause_identified', 'known_error', 'resolved', 'closed')),
    priority                text NOT NULL DEFAULT 'medium'
                            CONSTRAINT hd_problems_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    owner_user_id           text,
    team_id                 text REFERENCES helpdesk.hd_teams (id),
    department_id           text REFERENCES helpdesk.hd_departments (id),
    rca_method              text CONSTRAINT hd_problems_rca_method_check CHECK (rca_method IN ('five_whys', 'fishbone', 'eight_d', 'other')),
    root_cause              text,
    workaround              text,
    known_error_article_id  text REFERENCES helpdesk.hd_articles (id),
    resolved_at             timestamptz,
    closed_at               timestamptz,
    version                 int NOT NULL DEFAULT 1,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    created_by              text,
    updated_at              timestamptz,
    updated_by              text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_problems_number_uq ON helpdesk.hd_problems (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS hd_problems_business_idx ON helpdesk.hd_problems (tenant_id, bus_id, state);

-- step_key belongs to its method: why_1..why_5, the six Fishbone bones, or d1..d8; 'other' is free.
CREATE TABLE IF NOT EXISTS helpdesk.hd_rca_entries (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    problem_id      text NOT NULL REFERENCES helpdesk.hd_problems (id),
    method          text NOT NULL CONSTRAINT hd_rca_entries_method_check CHECK (method IN ('five_whys', 'fishbone', 'eight_d', 'other')),
    step_key        text NOT NULL,
    content         text NOT NULL,
    position        int NOT NULL DEFAULT 0,
    author_user_id  text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz,
    updated_by      text,
    CONSTRAINT hd_rca_entries_step_key_check CHECK (
        (method = 'five_whys' AND step_key IN ('why_1', 'why_2', 'why_3', 'why_4', 'why_5'))
        OR (method = 'fishbone' AND step_key IN ('people', 'process', 'technology', 'environment', 'materials', 'measurement'))
        OR (method = 'eight_d' AND step_key IN ('d1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd7', 'd8'))
        OR method = 'other')
);
CREATE INDEX IF NOT EXISTS hd_rca_entries_problem_idx ON helpdesk.hd_rca_entries (problem_id, method, position);

CREATE TABLE IF NOT EXISTS helpdesk.hd_problem_tickets (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    problem_id  text NOT NULL REFERENCES helpdesk.hd_problems (id),
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (problem_id, ticket_id)
);
CREATE INDEX IF NOT EXISTS hd_problem_tickets_ticket_idx ON helpdesk.hd_problem_tickets (ticket_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_problem_actions (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    problem_id     text NOT NULL REFERENCES helpdesk.hd_problems (id),
    kind           text NOT NULL CONSTRAINT hd_problem_actions_kind_check CHECK (kind IN ('corrective', 'preventive')),
    title          text NOT NULL,
    owner_user_id  text,
    due_on         date,
    state          text NOT NULL DEFAULT 'open' CONSTRAINT hd_problem_actions_state_check CHECK (state IN ('open', 'done', 'cancelled')),
    done_at        timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_problem_actions_problem_idx ON helpdesk.hd_problem_actions (problem_id);

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_incident_updates'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_incident_updates is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF to_regclass('core_platform.cp_party_references') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references
                        WHERE table_name = 'helpdesk.hd_tickets' AND column_name = 'vendor_party_id') THEN
        RAISE EXCEPTION 'helpdesk.hd_tickets.vendor_party_id is not in cp_party_references; a party merge would miss it';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_major_incidents m JOIN helpdesk.hd_tickets t ON t.id = m.ticket_id
                WHERE t.tenant_id <> m.tenant_id OR t.bus_id <> m.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk major incident belongs to a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_major_incident_tickets l
                 JOIN helpdesk.hd_major_incidents m ON m.id = l.major_id
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                WHERE m.tenant_id <> l.tenant_id OR m.bus_id <> l.bus_id OR t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk major incident links a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_incident_updates u JOIN helpdesk.hd_major_incidents m ON m.id = u.major_id
                WHERE m.tenant_id <> u.tenant_id OR m.bus_id <> u.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk incident update belongs to a major incident of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_problem_tickets l
                 JOIN helpdesk.hd_problems p ON p.id = l.problem_id
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                WHERE p.tenant_id <> l.tenant_id OR p.bus_id <> l.bus_id OR t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk problem links a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_problems p JOIN helpdesk.hd_articles a ON a.id = p.known_error_article_id
                WHERE a.tenant_id <> p.tenant_id OR a.bus_id <> p.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk problem points at a known-error article of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_review_actions x JOIN helpdesk.hd_reviews r ON r.id = x.review_id
                WHERE r.tenant_id <> x.tenant_id OR r.bus_id <> x.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk review action belongs to a review of another business';
    END IF;
END $$;

COMMIT;
