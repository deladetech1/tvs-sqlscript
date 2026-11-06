-- Help Desk R4: inbound email, outbound threading and SMS, and web chat.
--
--   hd_mailboxes         support addresses; each has a secret inbound_key for the provider-neutral
--                        endpoint POST /helpdesk/public/inbound/email/{inbound_key}
--   hd_inbound_messages  append-only: every normalised inbound email and what was done with it
--   hd_outbox            + message_id_header, in_reply_to, to_phone; channel email or sms
--   hd_ticket_messages   + delivery_status, author_contact_id; wider channel list
--   hd_tickets           wider source list (portal, chat, SMS and customer-portal tickets)
--   hd_chat_widgets      embeddable chat widgets, each with a public widget_key
--   hd_chats             one conversation with a visitor (polling, no websockets)
--   hd_chat_messages     append-only
--
-- This file is the newest that touches three lists, so it owns them: hd_outbox.channel,
-- hd_ticket_messages.channel and hd_tickets.source. An SMS outbox row has a phone, not an address
-- or a subject, so those two columns stop being NOT NULL and a CHECK requires the right one.
-- inbound_key, widget_key and visitor_token_hash are unique everywhere: the public routes look them
-- up before they know the business. The visitor token is stored only as its hash.
-- hd_inbound_messages."references" is quoted: REFERENCES is a reserved word.
-- Provisional (owner decisions D6, D7, R4.md): no provider adapter here; SMS is outbound only.
-- CHECK lists of new tables are inline. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §3, §6. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================= mailboxes
CREATE TABLE IF NOT EXISTS helpdesk.hd_mailboxes (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    name              text NOT NULL,
    address           text NOT NULL,
    inbound_key       text NOT NULL CONSTRAINT hd_mailboxes_inbound_key_check CHECK (length(inbound_key) >= 32 AND inbound_key ~ '^[A-Za-z0-9_-]+$'),
    department_id     text REFERENCES helpdesk.hd_departments (id),
    team_id           text REFERENCES helpdesk.hd_teams (id),
    default_priority  text NOT NULL DEFAULT 'medium'
                      CONSTRAINT hd_mailboxes_default_priority_check CHECK (default_priority IN ('low', 'medium', 'high', 'urgent')),
    is_active         boolean NOT NULL DEFAULT true,
    auto_reply        boolean NOT NULL DEFAULT false,
    auto_reply_text   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_mailboxes_inbound_key_uq ON helpdesk.hd_mailboxes (inbound_key);
CREATE UNIQUE INDEX IF NOT EXISTS hd_mailboxes_address_uq ON helpdesk.hd_mailboxes (tenant_id, bus_id, lower(address));

-- ================================================================ inbound messages
CREATE TABLE IF NOT EXISTS helpdesk.hd_inbound_messages (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    mailbox_id          text NOT NULL REFERENCES helpdesk.hd_mailboxes (id),
    message_id_header   text,
    in_reply_to         text,
    "references"        text[] NOT NULL DEFAULT '{}',
    from_email          text,
    from_name           text,
    to_emails           text[] NOT NULL DEFAULT '{}',
    cc_emails           text[] NOT NULL DEFAULT '{}',
    subject             text,
    body_text           text,
    body_html_stripped  text,
    received_at         timestamptz NOT NULL DEFAULT now(),
    outcome             text NOT NULL
                        CONSTRAINT hd_inbound_messages_outcome_check CHECK (outcome IN ('created_ticket', 'appended', 'ignored_loop',
                            'ignored_bounce', 'ignored_duplicate', 'rejected')),
    ticket_id           text REFERENCES helpdesk.hd_tickets (id),
    message_id          text REFERENCES helpdesk.hd_ticket_messages (id),
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text
);
-- The dedupe key: one row per Message-ID per business. A message without one is never deduplicated.
CREATE UNIQUE INDEX IF NOT EXISTS hd_inbound_messages_message_id_uq
    ON helpdesk.hd_inbound_messages (tenant_id, bus_id, message_id_header) WHERE message_id_header IS NOT NULL;
CREATE INDEX IF NOT EXISTS hd_inbound_messages_mailbox_idx ON helpdesk.hd_inbound_messages (mailbox_id, received_at DESC);
DROP TRIGGER IF EXISTS hd_inbound_messages_append_only ON helpdesk.hd_inbound_messages;
CREATE TRIGGER hd_inbound_messages_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_inbound_messages
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ============================================================================ outbox
ALTER TABLE helpdesk.hd_outbox ADD COLUMN IF NOT EXISTS message_id_header text;
ALTER TABLE helpdesk.hd_outbox ADD COLUMN IF NOT EXISTS in_reply_to text;
ALTER TABLE helpdesk.hd_outbox ADD COLUMN IF NOT EXISTS to_phone text;
ALTER TABLE helpdesk.hd_outbox ALTER COLUMN to_address DROP NOT NULL;
ALTER TABLE helpdesk.hd_outbox ALTER COLUMN subject DROP NOT NULL;
ALTER TABLE helpdesk.hd_outbox DROP CONSTRAINT IF EXISTS hd_outbox_channel_check;
ALTER TABLE helpdesk.hd_outbox ADD CONSTRAINT hd_outbox_channel_check CHECK (channel IN ('email', 'sms'));
-- An email has an address and a subject; an SMS has a phone.
ALTER TABLE helpdesk.hd_outbox DROP CONSTRAINT IF EXISTS hd_outbox_recipient_check;
ALTER TABLE helpdesk.hd_outbox ADD CONSTRAINT hd_outbox_recipient_check CHECK (
    (channel = 'email' AND to_address IS NOT NULL AND subject IS NOT NULL)
    OR (channel = 'sms' AND to_phone IS NOT NULL));

-- ========================================================================== messages
ALTER TABLE helpdesk.hd_ticket_messages ADD COLUMN IF NOT EXISTS delivery_status text
    CONSTRAINT hd_ticket_messages_delivery_status_check CHECK (delivery_status IN ('pending', 'sent', 'failed', 'skipped'));
ALTER TABLE helpdesk.hd_ticket_messages ADD COLUMN IF NOT EXISTS author_contact_id text REFERENCES helpdesk.hd_contacts (id);
ALTER TABLE helpdesk.hd_ticket_messages DROP CONSTRAINT IF EXISTS hd_ticket_messages_channel_check;
ALTER TABLE helpdesk.hd_ticket_messages ADD CONSTRAINT hd_ticket_messages_channel_check
    CHECK (channel IN ('portal', 'agent', 'email', 'api', 'chat', 'sms', 'customer_portal'));

-- =========================================================================== tickets
-- R4.md §6 creates tickets with source customer_portal, and chats become tickets; the R1 list
-- (portal, agent, email, api) is widened to the message channels.
ALTER TABLE helpdesk.hd_tickets DROP CONSTRAINT IF EXISTS hd_tickets_source_check;
ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_source_check
    CHECK (source IN ('portal', 'agent', 'email', 'api', 'chat', 'sms', 'customer_portal'));

-- ====================================================================== chat widgets
CREATE TABLE IF NOT EXISTS helpdesk.hd_chat_widgets (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    name             text NOT NULL,
    widget_key       text NOT NULL CONSTRAINT hd_chat_widgets_widget_key_check CHECK (length(widget_key) >= 32 AND widget_key ~ '^[A-Za-z0-9_-]+$'),
    department_id    text REFERENCES helpdesk.hd_departments (id),
    team_id          text REFERENCES helpdesk.hd_teams (id),
    allowed_origins  text[] NOT NULL DEFAULT '{}',
    greeting         text,
    is_active        boolean NOT NULL DEFAULT true,
    require_email    boolean NOT NULL DEFAULT true,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_chat_widgets_widget_key_uq ON helpdesk.hd_chat_widgets (widget_key);

-- ============================================================================= chats
CREATE TABLE IF NOT EXISTS helpdesk.hd_chats (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    widget_id           text NOT NULL REFERENCES helpdesk.hd_chat_widgets (id),
    contact_id          text REFERENCES helpdesk.hd_contacts (id),
    visitor_name        text,
    visitor_email       text,
    state               text NOT NULL DEFAULT 'waiting'
                        CONSTRAINT hd_chats_state_check CHECK (state IN ('waiting', 'active', 'ended')),
    assignee_user_id    text,
    ticket_id           text REFERENCES helpdesk.hd_tickets (id),
    visitor_token_hash  text NOT NULL,
    started_at          timestamptz NOT NULL DEFAULT now(),
    ended_at            timestamptz,
    last_activity_at    timestamptz NOT NULL DEFAULT now(),
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_chats_visitor_token_uq ON helpdesk.hd_chats (visitor_token_hash);
CREATE INDEX IF NOT EXISTS hd_chats_inbox_idx ON helpdesk.hd_chats (tenant_id, bus_id, state, last_activity_at DESC);

CREATE TABLE IF NOT EXISTS helpdesk.hd_chat_messages (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    chat_id         text NOT NULL REFERENCES helpdesk.hd_chats (id),
    sender          text NOT NULL CONSTRAINT hd_chat_messages_sender_check CHECK (sender IN ('visitor', 'agent', 'system')),
    author_user_id  text,
    body            text NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz,
    updated_by      text
);
CREATE INDEX IF NOT EXISTS hd_chat_messages_chat_idx ON helpdesk.hd_chat_messages (chat_id, cdatetime);
DROP TRIGGER IF EXISTS hd_chat_messages_append_only ON helpdesk.hd_chat_messages;
CREATE TRIGGER hd_chat_messages_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_chat_messages
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['hd_inbound_messages', 'hd_chat_messages'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                        WHERE g.tgrelid = ('helpdesk.' || t)::regclass AND p.proname = 'hd_refuse_change'
                          AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
            RAISE EXCEPTION 'helpdesk.% is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing', t;
        END IF;
    END LOOP;
    FOREACH t IN ARRAY ARRAY['hd_mailboxes_inbound_key_uq', 'hd_chat_widgets_widget_key_uq', 'hd_chats_visitor_token_uq',
                             'hd_inbound_messages_message_id_uq'] LOOP
        IF to_regclass('helpdesk.' || t) IS NULL THEN
            RAISE EXCEPTION 'helpdesk.% is missing', t;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_inbound_messages i JOIN helpdesk.hd_mailboxes m ON m.id = i.mailbox_id
                WHERE m.tenant_id <> i.tenant_id OR m.bus_id <> i.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk inbound message belongs to a mailbox of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_inbound_messages i JOIN helpdesk.hd_tickets k ON k.id = i.ticket_id
                WHERE k.tenant_id <> i.tenant_id OR k.bus_id <> i.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk inbound message landed on a ticket of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_chats c JOIN helpdesk.hd_chat_widgets w ON w.id = c.widget_id
                WHERE w.tenant_id <> c.tenant_id OR w.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk chat belongs to a widget of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_chat_messages m JOIN helpdesk.hd_chats c ON c.id = m.chat_id
                WHERE c.tenant_id <> m.tenant_id OR c.bus_id <> m.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk chat message belongs to a chat of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_messages m JOIN helpdesk.hd_contacts c ON c.id = m.author_contact_id
                WHERE c.tenant_id <> m.tenant_id OR c.bus_id <> m.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket message names a contact of another business';
    END IF;
END $$;

COMMIT;
