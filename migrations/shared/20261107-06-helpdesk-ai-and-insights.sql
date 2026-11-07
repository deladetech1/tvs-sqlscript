-- Help Desk R5: the AI governance scaffold and service intelligence.
--
--   hd_ai_settings         one row per business: on or off, a monthly request cap, whether customer
--                          data may be sent. No provider exists (owner decision D8, blocked): every
--                          model-backed call answers AI_NOT_CONFIGURED
--   hd_ai_usage            append-only: every AI request and its outcome, for caps and audit
--   hd_insight_dismissals  a user hides one insight until a date
--   hd_insight_cache       the helpdesk-insights job's results per business (statistical, no model)
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R5.md §2, §6 BE-5. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_ai_settings (
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    enabled              boolean NOT NULL DEFAULT false,
    monthly_request_cap  int CONSTRAINT hd_ai_settings_cap_check CHECK (monthly_request_cap >= 0),
    allow_customer_data  boolean NOT NULL DEFAULT false,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    PRIMARY KEY (tenant_id, bus_id)
);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ai_usage (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    user_id     text,
    feature     text NOT NULL,
    ticket_id   text REFERENCES helpdesk.hd_tickets (id),
    outcome     text NOT NULL CONSTRAINT hd_ai_usage_outcome_check CHECK (outcome IN ('ok', 'refused', 'not_configured', 'capped')),
    tokens_in   int CONSTRAINT hd_ai_usage_tokens_in_check CHECK (tokens_in >= 0),
    tokens_out  int CONSTRAINT hd_ai_usage_tokens_out_check CHECK (tokens_out >= 0),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
-- The monthly cap counts a business's requests by time.
CREATE INDEX IF NOT EXISTS hd_ai_usage_business_idx ON helpdesk.hd_ai_usage (tenant_id, bus_id, cdatetime DESC);
DROP TRIGGER IF EXISTS hd_ai_usage_append_only ON helpdesk.hd_ai_usage;
CREATE TRIGGER hd_ai_usage_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_ai_usage
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

CREATE TABLE IF NOT EXISTS helpdesk.hd_insight_dismissals (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    insight_key      text NOT NULL,
    user_id          text NOT NULL,
    dismissed_until  timestamptz NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
-- One dismissal per user and insight; dismissing again moves the date.
CREATE UNIQUE INDEX IF NOT EXISTS hd_insight_dismissals_uq ON helpdesk.hd_insight_dismissals (tenant_id, bus_id, user_id, insight_key);

CREATE TABLE IF NOT EXISTS helpdesk.hd_insight_cache (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    insight_key  text NOT NULL,
    kind         text NOT NULL,
    payload      jsonb NOT NULL,
    computed_at  timestamptz NOT NULL DEFAULT now(),
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_insight_cache_key_uq ON helpdesk.hd_insight_cache (tenant_id, bus_id, insight_key);

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_ai_usage'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_ai_usage is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF to_regclass('helpdesk.hd_insight_cache_key_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_insight_cache has no unique key on (tenant_id, bus_id, insight_key)';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ai_usage u JOIN helpdesk.hd_tickets t ON t.id = u.ticket_id
                WHERE t.tenant_id <> u.tenant_id OR t.bus_id <> u.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk AI usage row names a ticket of another business';
    END IF;
END $$;

COMMIT;
