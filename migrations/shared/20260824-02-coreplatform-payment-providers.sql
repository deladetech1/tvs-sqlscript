-- 20260824-02-coreplatform-payment-providers.sql
-- Tenant-owned payment collection: which gateways a tenant has set up, and every
-- payment they have taken through them.
--
-- Distinct from the existing Paystack billing flow. That one uses TroveSuite's
-- own merchant account (PAYSTACK_SECRET_KEY) to charge tenants for their
-- subscriptions. These tables hold each TENANT's own merchant credentials so the
-- tenant can collect money from THEIR customers, from any app on the platform.
--
-- The provider catalogue itself lives in code (src/entities/payment_providers/
-- registry.py), because adding a gateway always means adding a client anyway.
-- These tables only hold per-tenant configuration and the resulting payments,
-- so a new provider needs no migration.
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- Per-tenant gateway configuration
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_tenant_payment_providers (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,

    provider_code     text        NOT NULL,          -- 'paystack' | 'hubtel' | 'expresspay' | 'stripe'

    -- Credentials, encrypted at rest. One JSON object per provider holding only
    -- that provider's fields (see the registry for which). Secret values are
    -- Fernet tokens, never plaintext; non-secret fields (merchant ids, account
    -- numbers) are stored as-is so they can be shown back in the UI.
    credentials       jsonb       NOT NULL DEFAULT '{}'::jsonb,

    mode              text        NOT NULL DEFAULT 'test',   -- 'test' | 'live'
    is_active         boolean     NOT NULL DEFAULT true,
    is_default        boolean     NOT NULL DEFAULT false,

    delete_status     text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by        text,
    updated_by        text,
    cdate             text,
    ctime             text,
    cdatetime         timestamptz DEFAULT NOW(),
    udatetime         timestamptz
);

-- One configuration per provider per tenant. Partial so a soft-deleted row does
-- not block setting the same provider up again.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_tenant_payment_providers_tenant_provider
    ON core_platform.cp_tenant_payment_providers (tenant_id, provider_code)
    WHERE delete_status = 'NOT_DELETED';

-- At most one default per tenant, enforced by the database rather than by
-- hoping every write path remembers to clear the previous one.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_tenant_payment_providers_one_default
    ON core_platform.cp_tenant_payment_providers (tenant_id)
    WHERE is_default = true AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS idx_cp_tenant_payment_providers_tenant
    ON core_platform.cp_tenant_payment_providers (tenant_id, delete_status);


-- ---------------------------------------------------------------------------
-- Payments collected through those gateways
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_payment_collections (
    id                   text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text        NOT NULL,
    org_id               text,
    bus_id               text,

    -- Which app asked for the payment (app-mystoreguard, app-loandrift, …), so a
    -- tenant collecting from several apps can still tell them apart.
    app_id               text,

    provider_code        text        NOT NULL,

    -- Our reference, generated here and unique per tenant. This is what the app
    -- keeps against its own invoice/loan and what every provider echoes back.
    reference            text        NOT NULL,
    provider_reference   text,                       -- the gateway's own id/token

    -- Canonical amount is the MINOR unit (pesewas, kobo, cents) as an integer,
    -- because that is what most gateways take and it cannot lose precision.
    -- Clients convert to major units for the gateways that want them.
    amount_minor         bigint      NOT NULL,
    currency             text        NOT NULL,

    status               text        NOT NULL DEFAULT 'pending',
    -- 'pending' | 'success' | 'failed' | 'cancelled' | 'abandoned'

    customer_name        text,
    customer_email       text,
    customer_phone       text,
    description          text,

    checkout_url         text,
    callback_url         text,
    metadata             jsonb,
    provider_response    jsonb,                      -- last raw payload, for support

    verified_at          timestamptz,
    initiated_by         text,

    cdate                text,
    ctime                text,
    cdatetime            timestamptz DEFAULT NOW(),
    udatetime            timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_payment_collections_reference
    ON core_platform.cp_payment_collections (tenant_id, reference);
CREATE INDEX IF NOT EXISTS idx_cp_payment_collections_scope
    ON core_platform.cp_payment_collections (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_payment_collections_status
    ON core_platform.cp_payment_collections (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_cp_payment_collections_provider_ref
    ON core_platform.cp_payment_collections (provider_code, provider_reference);


-- ---------------------------------------------------------------------------
-- Audit trail for gateway configuration changes
--
-- Payment credentials are among the most sensitive settings a tenant has, so
-- changes to them are audited like every other settings sub-entity. Secret
-- values are never written into the snapshots.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_payment_provider_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,
    entity_name            text,

    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_payment_provider_audit_logs_scope
    ON core_platform.cp_payment_provider_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_payment_provider_audit_logs_entity
    ON core_platform.cp_payment_provider_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_payment_provider_audit_logs_action
    ON core_platform.cp_payment_provider_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_payment_provider_audit_logs_performed_by
    ON core_platform.cp_payment_provider_audit_logs (tenant_id, performed_by);
