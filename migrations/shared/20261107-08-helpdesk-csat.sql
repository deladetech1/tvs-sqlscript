-- Help Desk R6: customer satisfaction (CSAT).
--
--   hd_csat_settings  one row per business: on or off, the question asked, how many days a survey
--                     link stays open (1..90). No row means off.
--   hd_csat_surveys   one survey per resolution: sent when a ticket moves to resolved (in the same
--                     transaction), answered once on the public page, expired by the
--                     helpdesk-csat-expiry job, superseded when the ticket is reopened. At most one
--                     pending survey per ticket.
--
-- The survey link's token is never stored: only its sha256 (hex), unique everywhere, because the
-- public page looks a token up before it knows the business (as the customer portal's links).
-- client_account_id is copied from the ticket so the responses list is client scoped like every
-- other list. CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R6.md §2. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_csat_settings (
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    enabled       boolean NOT NULL DEFAULT false,
    question      text CONSTRAINT hd_csat_settings_question_check CHECK (length(question) <= 500),
    expires_days  int NOT NULL DEFAULT 14 CONSTRAINT hd_csat_settings_expires_days_check CHECK (expires_days BETWEEN 1 AND 90),
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text,
    PRIMARY KEY (tenant_id, bus_id)
);

CREATE TABLE IF NOT EXISTS helpdesk.hd_csat_surveys (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    bus_id                text NOT NULL,
    ticket_id             text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    -- Whoever the ticket's requester is: a hub user, a customer contact, or a bare address.
    requester_user_id     text,
    requester_contact_id  text,
    requester_email       text,
    client_account_id     text,
    token_hash            text NOT NULL CONSTRAINT hd_csat_surveys_token_hash_check CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    question              text,
    status                text NOT NULL DEFAULT 'pending'
                          CONSTRAINT hd_csat_surveys_status_check CHECK (status IN ('pending', 'answered', 'expired', 'superseded')),
    sent_at               timestamptz NOT NULL DEFAULT now(),
    expires_at            timestamptz NOT NULL,
    rating                smallint CONSTRAINT hd_csat_surveys_rating_check CHECK (rating BETWEEN 1 AND 5),
    comment               text CONSTRAINT hd_csat_surveys_comment_check CHECK (length(comment) <= 2000),
    answered_at           timestamptz,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz,
    updated_by            text,
    -- An answered survey has its rating and time; nothing else has a rating.
    CONSTRAINT hd_csat_surveys_answer_check CHECK ((status = 'answered') = (rating IS NOT NULL AND answered_at IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_csat_surveys_token_hash_uq ON helpdesk.hd_csat_surveys (token_hash);
-- One pending survey per ticket.
CREATE UNIQUE INDEX IF NOT EXISTS hd_csat_surveys_pending_uq ON helpdesk.hd_csat_surveys (ticket_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS hd_csat_surveys_ticket_idx ON helpdesk.hd_csat_surveys (tenant_id, bus_id, ticket_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS hd_csat_surveys_list_idx ON helpdesk.hd_csat_surveys (tenant_id, bus_id, status, sent_at DESC);
CREATE INDEX IF NOT EXISTS hd_csat_surveys_client_idx ON helpdesk.hd_csat_surveys (tenant_id, bus_id, client_account_id);
-- The expiry job reads pending surveys across businesses.
CREATE INDEX IF NOT EXISTS hd_csat_surveys_expiry_idx ON helpdesk.hd_csat_surveys (expires_at) WHERE status = 'pending';

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM helpdesk.hd_csat_surveys v JOIN helpdesk.hd_tickets t ON t.id = v.ticket_id
                WHERE t.tenant_id <> v.tenant_id OR t.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk satisfaction survey belongs to a ticket of another business';
    END IF;
END $$;

COMMIT;
