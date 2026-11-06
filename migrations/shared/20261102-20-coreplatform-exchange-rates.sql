-- 20261102-20-coreplatform-exchange-rates.sql
-- A tenant's own exchange rates between its currencies, set in Core Platform and used by every
-- app (the first: SCM stock valuation converts lots bought in another currency).
--
-- The owner (2026-11-02): "Let us have a currency converter in coreplatform we can set and use
-- there."
--
-- Scoped like core_platform.cp_currencies: per TENANT, by ISO code. A rate is 1 from_currency =
-- rate to_currency from effective_at on. History is kept: a new rate is a new row, and the rate
-- at a moment is the latest row of the pair whose effective_at is at or before it. A mistaken
-- entry is withdrawn (deleted_at/deleted_by), never rewritten, so what a past report used stays
-- explainable. Read and written only through Core's /api/v1/exchange-rates
-- (tvs-coreplatform-bk app/src/entities/exchange_rates), which also derives inverse and cross
-- (via the tenant's default currency) rates -- they are never stored.
--
-- source: MANUAL (typed in Settings) or AUTO (a future rate feed; nothing writes AUTO yet).
-- This is the tenant's business rate, unrelated to platform billing's USD->local rate.
--
-- Kept out of the EF model like cp_user_view_preferences. Idempotent; safe to re-run on every
-- deploy (table grants come from the schema's default privileges).

CREATE TABLE IF NOT EXISTS core_platform.cp_exchange_rates (
    id             text           PRIMARY KEY DEFAULT ('fx-' || gen_random_uuid()::text),
    tenant_id      text           NOT NULL,
    from_currency  text           NOT NULL CHECK (from_currency ~ '^[A-Z]{3}$'),
    to_currency    text           NOT NULL CHECK (to_currency ~ '^[A-Z]{3}$'),
    rate           numeric(20,10) NOT NULL CHECK (rate > 0),
    effective_at   timestamptz    NOT NULL DEFAULT now(),
    source         text           NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('MANUAL', 'AUTO')),
    note           text           CHECK (note IS NULL OR length(note) <= 200),
    set_by         text,
    created_at     timestamptz    NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    deleted_by     text,

    CONSTRAINT ck_cp_exchange_rates_two_currencies CHECK (from_currency <> to_currency),
    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- The rate of a pair at a moment: latest effective_at at or before it, live rows only.
CREATE INDEX IF NOT EXISTS ix_cp_exchange_rates_pair
    ON core_platform.cp_exchange_rates (tenant_id, from_currency, to_currency, effective_at DESC, created_at DESC)
    WHERE deleted_at IS NULL;
