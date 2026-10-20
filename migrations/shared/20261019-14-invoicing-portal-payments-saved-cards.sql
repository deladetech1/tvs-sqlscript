-- Invoicing: paying several invoices at once, and saved cards.
--
-- inv_payment_attempt_invoices: one online payment for several of a customer's invoices (from
-- their page). The attempt names its first invoice; each invoice's share is here. When it
-- settles, what came in is split across them in order -- one payment per invoice, so the
-- gateway reference is unique per invoice (inv_payments_gateway_uq).
--
-- Saved cards. A customer paying by card can keep it for next time; the business can then
-- charge it -- by hand, or by itself when an invoice falls due (inv_customers.autopay). Only a
-- card the gateway says can be charged again is kept (Paystack's reusable authorization);
-- mobile money cannot be charged without the customer, so it is never kept.
--   * core_platform.cp_tenant_payer_authorizations: the gateway's authorization, held by
--     core-platform (which holds the tenant's gateway credentials). The authorization code is
--     encrypted like the credentials are, and never leaves core-platform: apps refer to a row
--     by its id. payer_ref is the app's name for the payer ("invoicing-customer:<id>").
--   * invoicing.inv_payment_methods: a customer's saved cards as Invoicing shows them (brand,
--     last four, expiry) with the core id to charge.
--   * inv_payment_attempts.save_method: keep the card if the payment succeeds; source: a
--     checkout the customer went through, or a charge of a saved card (by hand or autopay).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_payment_attempt_invoices (
    reference     text    NOT NULL,
    invoice_id    text    NOT NULL REFERENCES invoicing.inv_invoices (id) ON DELETE CASCADE,
    amount_minor  bigint  NOT NULL CHECK (amount_minor > 0),
    position      integer NOT NULL,
    PRIMARY KEY (reference, invoice_id)
);
CREATE INDEX IF NOT EXISTS inv_payment_attempt_invoices_invoice_idx ON invoicing.inv_payment_attempt_invoices (invoice_id);

-- One gateway payment may now pay several invoices, so its reference is unique per invoice.
-- Same index name, so migration 07 re-running (IF NOT EXISTS) leaves this definition alone.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'invoicing' AND indexname = 'inv_payments_gateway_uq'
                AND indexdef NOT LIKE '%invoice_id%') THEN
        DROP INDEX invoicing.inv_payments_gateway_uq;
    END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS inv_payments_gateway_uq ON invoicing.inv_payments (gateway_reference, invoice_id) WHERE gateway_reference IS NOT NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_tenant_payer_authorizations (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    provider_code       text        NOT NULL,
    app_id              text,
    payer_ref           text        NOT NULL,
    authorization_code  text        NOT NULL,          -- encrypted (Fernet), never returned
    signature           text,                          -- the gateway's id of the card itself
    email               text,
    customer_code       text,
    channel             text        NOT NULL DEFAULT 'card',
    card_type           text,
    bank                text,
    last4               text,
    exp_month           text,
    exp_year            text,
    reusable            boolean     NOT NULL DEFAULT true,
    is_active           boolean     NOT NULL DEFAULT true,
    from_reference      text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    udatetime           timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_tenant_payer_authorizations_card
    ON core_platform.cp_tenant_payer_authorizations (tenant_id, provider_code, payer_ref, signature)
    WHERE is_active AND signature IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cp_tenant_payer_authorizations_payer
    ON core_platform.cp_tenant_payer_authorizations (tenant_id, payer_ref) WHERE is_active;

CREATE TABLE IF NOT EXISTS invoicing.inv_payment_methods (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,
    bus_id            text        NOT NULL,
    customer_id       text        NOT NULL REFERENCES invoicing.inv_customers (id) ON DELETE CASCADE,
    authorization_id  text        NOT NULL,
    provider_code     text        NOT NULL DEFAULT '',
    card_type         text        NOT NULL DEFAULT '',
    bank              text        NOT NULL DEFAULT '',
    last4             text        NOT NULL DEFAULT '',
    exp_month         text        NOT NULL DEFAULT '',
    exp_year          text        NOT NULL DEFAULT '',
    is_default        boolean     NOT NULL DEFAULT false,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (customer_id, authorization_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_payment_methods_one_default ON invoicing.inv_payment_methods (customer_id) WHERE is_default;

-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS autopay boolean NOT NULL DEFAULT false;
    END IF;
END $guard$;

ALTER TABLE invoicing.inv_payment_attempts
    ADD COLUMN IF NOT EXISTS save_method boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS source      text    NOT NULL DEFAULT 'checkout',
    ADD COLUMN IF NOT EXISTS error       text    NOT NULL DEFAULT '';

COMMIT;
