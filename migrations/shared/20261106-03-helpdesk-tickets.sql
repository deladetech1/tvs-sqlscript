-- Help Desk R1: tickets and everything on them.
--
--   hd_tickets              the ticket: who asked, where it sits (department, team, assignee), its
--                           status (and the status's category, copied for fast lists), its SLA due
--                           time, merge and parent links, soft delete, an optimistic-lock version and
--                           a generated search vector
--   hd_ticket_events        append-only: every change to a ticket (created, assigned, merged...)
--   hd_ticket_messages      append-only: public replies and internal notes; a correction is a new
--                           message
--   hd_attachments          files in blob storage, on a ticket or one of its messages
--   hd_ticket_links         related / duplicate_of / blocks / caused_by
--   hd_ticket_watchers      who follows a ticket
--   hd_ticket_tags          lower-case tags
--   hd_ticket_field_values  values of the business's custom fields (hd_field_defs)
--   hd_saved_views          personal views and shared queues
--   hd_idempotency_keys     replayed answers for Idempotency-Key requests (housekeeping drops them
--                           after 24h)
--
-- The FK from hd_tickets.sla_policy_id to hd_sla_policies is added in 20261106-04, which creates
-- that table. Append-only tables use helpdesk.hd_refuse_change (20261106-02). CHECK lists are
-- defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R1.md §1, §4. Idempotent; safe to re-run.

BEGIN;

-- =========================================================================== tickets
CREATE TABLE IF NOT EXISTS helpdesk.hd_tickets (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    loc_id              text,
    number              text NOT NULL,
    ticket_type         text NOT NULL DEFAULT 'request'
                        CONSTRAINT hd_tickets_ticket_type_check CHECK (ticket_type IN ('request', 'incident', 'question')),
    subject             text NOT NULL,
    description         text,
    requester_user_id   text,
    requester_name      text,
    requester_email     text,
    department_id       text REFERENCES helpdesk.hd_departments (id),
    team_id             text REFERENCES helpdesk.hd_teams (id),
    assignee_user_id    text,
    category_id         text REFERENCES helpdesk.hd_categories (id),
    subcategory_id      text REFERENCES helpdesk.hd_categories (id),
    priority            text NOT NULL DEFAULT 'medium'
                        CONSTRAINT hd_tickets_priority_check CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    severity            text CONSTRAINT hd_tickets_severity_check CHECK (severity IN ('sev1', 'sev2', 'sev3', 'sev4')),
    status_id           text NOT NULL REFERENCES helpdesk.hd_statuses (id),
    status_category     text NOT NULL
                        CONSTRAINT hd_tickets_status_category_check CHECK (status_category IN ('new', 'open', 'pending', 'on_hold', 'resolved', 'closed', 'cancelled')),
    source              text NOT NULL
                        CONSTRAINT hd_tickets_source_check CHECK (source IN ('portal', 'agent', 'email', 'api')),
    sla_policy_id       text,
    due_at              timestamptz,
    first_responded_at  timestamptz,
    resolved_at         timestamptz,
    closed_at           timestamptz,
    reopened_count      int NOT NULL DEFAULT 0,
    parent_ticket_id    text REFERENCES helpdesk.hd_tickets (id),
    merged_into_id      text REFERENCES helpdesk.hd_tickets (id),
    is_restricted       boolean NOT NULL DEFAULT false,
    deleted_at          timestamptz,
    version             int NOT NULL DEFAULT 1,
    search              tsvector GENERATED ALWAYS AS (to_tsvector('simple',
                            coalesce(number, '') || ' ' || coalesce(subject, '') || ' ' || coalesce(description, ''))) STORED,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text,
    CONSTRAINT hd_tickets_requester_check CHECK (requester_user_id IS NOT NULL OR requester_email IS NOT NULL),
    CONSTRAINT hd_tickets_not_merged_into_self CHECK (merged_into_id IS DISTINCT FROM id),
    CONSTRAINT hd_tickets_not_own_parent CHECK (parent_ticket_id IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_tickets_number_uq ON helpdesk.hd_tickets (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS hd_tickets_list_idx
    ON helpdesk.hd_tickets (tenant_id, bus_id, status_category, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hd_tickets_assignee_idx ON helpdesk.hd_tickets (tenant_id, bus_id, assignee_user_id);
CREATE INDEX IF NOT EXISTS hd_tickets_team_idx ON helpdesk.hd_tickets (tenant_id, bus_id, team_id);
CREATE INDEX IF NOT EXISTS hd_tickets_requester_idx ON helpdesk.hd_tickets (tenant_id, bus_id, requester_user_id);
CREATE INDEX IF NOT EXISTS hd_tickets_search_idx ON helpdesk.hd_tickets USING gin (search);

-- ============================================================================ events
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    event_type  text NOT NULL,
    actor_id    text,
    data        jsonb NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS hd_ticket_events_ticket_idx ON helpdesk.hd_ticket_events (ticket_id, cdatetime);
DROP TRIGGER IF EXISTS hd_ticket_events_append_only ON helpdesk.hd_ticket_events;
CREATE TRIGGER hd_ticket_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_ticket_events
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ========================================================================== messages
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_messages (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    ticket_id            text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    kind                 text NOT NULL CONSTRAINT hd_ticket_messages_kind_check CHECK (kind IN ('reply', 'note')),
    body                 text NOT NULL,
    author_user_id       text,
    author_name          text,
    channel              text NOT NULL
                         CONSTRAINT hd_ticket_messages_channel_check CHECK (channel IN ('portal', 'agent', 'email', 'api')),
    is_from_requester    boolean NOT NULL DEFAULT false,
    note_department_id   text REFERENCES helpdesk.hd_departments (id),
    mentions             text[] NOT NULL DEFAULT '{}',
    external_message_id  text,
    in_reply_to          text,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    CONSTRAINT hd_ticket_messages_note_department_check CHECK (note_department_id IS NULL OR kind = 'note')
);
CREATE INDEX IF NOT EXISTS hd_ticket_messages_ticket_idx ON helpdesk.hd_ticket_messages (ticket_id, cdatetime);
CREATE INDEX IF NOT EXISTS hd_ticket_messages_mentions_idx ON helpdesk.hd_ticket_messages USING gin (mentions);
DROP TRIGGER IF EXISTS hd_ticket_messages_append_only ON helpdesk.hd_ticket_messages;
CREATE TRIGGER hd_ticket_messages_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_ticket_messages
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ======================================================================= attachments
-- ticket_id may be NULL between upload and the ticket it is attached to; confirmed_at marks a
-- blob that was confirmed as uploaded.
CREATE TABLE IF NOT EXISTS helpdesk.hd_attachments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    ticket_id     text REFERENCES helpdesk.hd_tickets (id),
    message_id    text REFERENCES helpdesk.hd_ticket_messages (id),
    blob_name     text NOT NULL,
    file_name     text NOT NULL,
    content_type  text,
    size_bytes    bigint CONSTRAINT hd_attachments_size_check CHECK (size_bytes >= 0),
    uploaded_by   text,
    confirmed_at  timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE INDEX IF NOT EXISTS hd_attachments_ticket_idx ON helpdesk.hd_attachments (ticket_id);
CREATE INDEX IF NOT EXISTS hd_attachments_message_idx ON helpdesk.hd_attachments (message_id);

-- ============================================================ links, watchers, tags
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_links (
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    ticket_id         text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    linked_ticket_id  text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    link_type         text NOT NULL
                      CONSTRAINT hd_ticket_links_link_type_check CHECK (link_type IN ('related', 'duplicate_of', 'blocks', 'caused_by')),
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    PRIMARY KEY (ticket_id, linked_ticket_id, link_type),
    CONSTRAINT hd_ticket_links_not_self CHECK (ticket_id <> linked_ticket_id)
);
CREATE INDEX IF NOT EXISTS hd_ticket_links_linked_idx ON helpdesk.hd_ticket_links (linked_ticket_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_watchers (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    user_id     text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    PRIMARY KEY (ticket_id, user_id)
);
CREATE INDEX IF NOT EXISTS hd_ticket_watchers_user_idx ON helpdesk.hd_ticket_watchers (tenant_id, bus_id, user_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_tags (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    tag         text NOT NULL CONSTRAINT hd_ticket_tags_tag_check CHECK (tag = lower(tag) AND length(tag) BETWEEN 1 AND 40),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    PRIMARY KEY (ticket_id, tag)
);
CREATE INDEX IF NOT EXISTS hd_ticket_tags_tag_idx ON helpdesk.hd_ticket_tags (tenant_id, bus_id, tag);

-- ===================================================================== field values
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_field_values (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    field_id    text NOT NULL REFERENCES helpdesk.hd_field_defs (id),
    value       jsonb,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (ticket_id, field_id)
);

-- ======================================================================= saved views
CREATE TABLE IF NOT EXISTS helpdesk.hd_saved_views (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    owner_user_id  text,
    name           text NOT NULL,
    filters        jsonb NOT NULL DEFAULT '{}',
    sort           text,
    columns        jsonb NOT NULL DEFAULT '[]',
    position       int NOT NULL DEFAULT 0,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_saved_views_owner_idx ON helpdesk.hd_saved_views (tenant_id, bus_id, owner_user_id);

-- =================================================================== idempotency keys
CREATE TABLE IF NOT EXISTS helpdesk.hd_idempotency_keys (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    key          text NOT NULL,
    route        text NOT NULL,
    status_code  int,
    response     jsonb,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    PRIMARY KEY (tenant_id, bus_id, key, route)
);
CREATE INDEX IF NOT EXISTS hd_idempotency_keys_age_idx ON helpdesk.hd_idempotency_keys (cdatetime);

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['hd_ticket_events', 'hd_ticket_messages'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                        WHERE g.tgrelid = ('helpdesk.' || t)::regclass AND p.proname = 'hd_refuse_change'
                          AND NOT g.tgisinternal
                          AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
            RAISE EXCEPTION 'helpdesk.% is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing', t;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tickets k JOIN helpdesk.hd_statuses s ON s.id = k.status_id
                WHERE s.tenant_id <> k.tenant_id OR s.bus_id <> k.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket has a status of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tickets k JOIN helpdesk.hd_tickets m ON m.id = k.merged_into_id
                WHERE m.tenant_id <> k.tenant_id OR m.bus_id <> k.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket is merged into a ticket of another business';
    END IF;
END $$;

COMMIT;
