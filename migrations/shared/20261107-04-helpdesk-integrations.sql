-- Help Desk R5: the integration platform.
--
--   hd_api_tokens          Help Desk's own API tokens in Core's style (prefix tvs_hd_, 32 random
--                          bytes, shown once): only the sha256 key_hash is stored, unique
--                          everywhere because a request is matched to its token before the
--                          business is known. Scoped to one business and a subset of Help Desk
--                          permission pairs (owner decision D11, provisional)
--   hd_webhooks            signed webhooks (https only) for the R5.md §5 event types; the payload
--                          carries a requester's email only when include_personal_data is true
--   hd_webhook_deliveries  one delivery per event per webhook, retried until delivered or dead
--   hd_integration_errors  append-only: what went wrong talking to the outside world
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §2, §5, §6 BE-3. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_api_tokens (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    label         text NOT NULL,
    key_prefix    text NOT NULL,
    key_hash      text NOT NULL,
    permissions   text[] NOT NULL DEFAULT '{}',
    expires_at    timestamptz,
    last_used_at  timestamptz,
    last_used_ip  text,
    revoked_at    timestamptz,
    revoked_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_api_tokens_key_hash_uq ON helpdesk.hd_api_tokens (key_hash);
CREATE INDEX IF NOT EXISTS hd_api_tokens_business_idx ON helpdesk.hd_api_tokens (tenant_id, bus_id) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS helpdesk.hd_webhooks (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    name                   text NOT NULL,
    url                    text NOT NULL CONSTRAINT hd_webhooks_url_check CHECK (url ~ '^https://'),
    secret_hint            text,
    secret_enc             text,
    event_types            text[] NOT NULL DEFAULT '{}'
                           CONSTRAINT hd_webhooks_event_types_check CHECK (event_types <@ ARRAY['ticket.created', 'ticket.updated',
                               'ticket.status_changed', 'ticket.assigned', 'ticket.replied', 'ticket.resolved', 'ticket.reopened',
                               'sla.warning', 'sla.breach', 'approval.decided', 'change.state_changed', 'major_incident.updated']::text[]),
    include_personal_data  boolean NOT NULL DEFAULT false,
    is_active              boolean NOT NULL DEFAULT true,
    failure_count          int NOT NULL DEFAULT 0,
    disabled_reason        text,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz,
    updated_by             text
);
ALTER TABLE helpdesk.hd_webhooks ADD COLUMN IF NOT EXISTS include_personal_data boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS hd_webhooks_business_idx ON helpdesk.hd_webhooks (tenant_id, bus_id) WHERE is_active;

CREATE TABLE IF NOT EXISTS helpdesk.hd_webhook_deliveries (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    webhook_id       text NOT NULL REFERENCES helpdesk.hd_webhooks (id),
    event_id         text NOT NULL,
    event_type       text NOT NULL,
    payload          jsonb NOT NULL,
    idempotency_key  text NOT NULL,
    state            text NOT NULL DEFAULT 'pending'
                     CONSTRAINT hd_webhook_deliveries_state_check CHECK (state IN ('pending', 'delivered', 'failed', 'dead')),
    attempts         int NOT NULL DEFAULT 0,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    response_status  int,
    response_ms      int,
    last_error       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_webhook_deliveries_idempotency_uq ON helpdesk.hd_webhook_deliveries (webhook_id, idempotency_key);
CREATE INDEX IF NOT EXISTS hd_webhook_deliveries_webhook_idx ON helpdesk.hd_webhook_deliveries (webhook_id, cdatetime DESC);
-- The delivery job reads pending and failed deliveries by next attempt, across businesses.
CREATE INDEX IF NOT EXISTS hd_webhook_deliveries_due_idx
    ON helpdesk.hd_webhook_deliveries (next_attempt_at) WHERE state IN ('pending', 'failed');

CREATE TABLE IF NOT EXISTS helpdesk.hd_integration_errors (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    source      text NOT NULL
                CONSTRAINT hd_integration_errors_source_check CHECK (source IN ('webhook', 'api', 'inbound_email', 'sms', 'email', 'workflow')),
    ref_id      text,
    message     text NOT NULL,
    data        jsonb NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_integration_errors_business_idx ON helpdesk.hd_integration_errors (tenant_id, bus_id, source, cdatetime DESC);
DROP TRIGGER IF EXISTS hd_integration_errors_append_only ON helpdesk.hd_integration_errors;
CREATE TRIGGER hd_integration_errors_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_integration_errors
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_integration_errors'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_integration_errors is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF to_regclass('helpdesk.hd_api_tokens_key_hash_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_api_tokens has no unique index on key_hash';
    END IF;
    -- A token is scoped to Help Desk pairs only.
    IF EXISTS (SELECT 1 FROM helpdesk.hd_api_tokens t, unnest(t.permissions) AS pair
                WHERE pair NOT LIKE 'helpdesk|%') THEN
        RAISE EXCEPTION 'a Help Desk API token carries a permission that is not a Help Desk pair';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_webhook_deliveries d JOIN helpdesk.hd_webhooks w ON w.id = d.webhook_id
                WHERE w.tenant_id <> d.tenant_id OR w.bus_id <> d.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk webhook delivery belongs to a webhook of another business';
    END IF;
END $$;

COMMIT;
