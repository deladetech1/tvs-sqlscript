-- 20260828-01-coreplatform-sms-providers.sql
-- Tenant-owned SMS sending: which gateways a tenant has set up, and every
-- message sent through them.
--
-- Deliberately the same shape as cp_tenant_payment_providers next door. The two
-- problems are the same problem — per-tenant credentials for a third party that
-- any app on the platform can then use — so anyone who has read one of these
-- can read the other, and the settings screens behave alike.
--
-- The provider catalogue lives in code (src/entities/sms_providers/registry.py),
-- because adding a gateway always means adding a client anyway. These tables
-- hold only per-tenant configuration and the resulting messages, so a new
-- provider needs no migration.
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- Per-tenant gateway configuration
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_tenant_sms_providers (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,

    provider_code     text        NOT NULL,          -- 'arkesel' | 'hubtel' | 'twilio'

    -- Credentials, encrypted at rest. One JSON object per provider holding only
    -- that provider's fields (see the registry for which). Secret values are
    -- Fernet tokens, never plaintext; non-secret fields (sender IDs, account
    -- SIDs) are stored as-is so they can be shown back in the UI.
    credentials       jsonb       NOT NULL DEFAULT '{}'::jsonb,

    -- The name recipients see. Held outside `credentials` because it is the one
    -- setting a shop actually thinks about, it is not a secret, and every
    -- provider has it under a different name — Arkesel "sender", Hubtel "From",
    -- Twilio a purchased number or MessagingServiceSid.
    sender_id         text,

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
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_tenant_sms_providers_tenant_provider
    ON core_platform.cp_tenant_sms_providers (tenant_id, provider_code)
    WHERE delete_status = 'NOT_DELETED';

-- At most one default per tenant, enforced by the database rather than by
-- hoping every write path remembers to clear the previous one.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_tenant_sms_providers_one_default
    ON core_platform.cp_tenant_sms_providers (tenant_id)
    WHERE is_default = true AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS idx_cp_tenant_sms_providers_tenant
    ON core_platform.cp_tenant_sms_providers (tenant_id, delete_status);


-- ---------------------------------------------------------------------------
-- Messages sent through those gateways
--
-- One row per RECIPIENT, not per send call. Arkesel takes a list and answers
-- once for the batch, but "did this customer get their reminder" is the
-- question anyone actually asks, and it cannot be answered from a batch row.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_sms_messages (
    id                   text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text        NOT NULL,
    org_id               text,
    bus_id               text,

    -- Which app asked for the message (app-mystoreguard, app-loandrift, …), so
    -- a tenant sending from several apps can still tell them apart.
    app_id               text,

    provider_code        text        NOT NULL,

    -- Our reference, generated here and unique per tenant. What the calling app
    -- keeps against its own record, and what a support question starts from.
    reference            text        NOT NULL,
    provider_reference   text,                       -- the gateway's own message id

    recipient            text        NOT NULL,       -- E.164 where we could form it
    sender_id            text,
    message              text        NOT NULL,
    segments             integer,                    -- billable parts, when reported

    -- queued | sent | delivered | failed | undelivered
    --
    -- Five rather than the payment table's four: a gateway accepting a message
    -- and the handset receiving it are different events, and only the second
    -- answers "did they get it". Providers that never report back stop at
    -- 'sent', which is honest — it is all they told us.
    status               text        NOT NULL DEFAULT 'queued',
    error_code           text,
    error_message        text,

    metadata             jsonb,
    provider_response    jsonb,                      -- last raw payload, for support

    sent_at              timestamptz,
    delivered_at         timestamptz,
    initiated_by         text,

    cdate                text,
    ctime                text,
    cdatetime            timestamptz DEFAULT NOW(),
    udatetime            timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cp_sms_messages_tenant_reference
    ON core_platform.cp_sms_messages (tenant_id, reference);

CREATE INDEX IF NOT EXISTS idx_cp_sms_messages_scope
    ON core_platform.cp_sms_messages (tenant_id, app_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_sms_messages_status
    ON core_platform.cp_sms_messages (tenant_id, status, cdatetime DESC);

-- Delivery reports arrive keyed by the gateway's id, not ours.
CREATE INDEX IF NOT EXISTS idx_cp_sms_messages_provider_ref
    ON core_platform.cp_sms_messages (provider_reference)
    WHERE provider_reference IS NOT NULL;

-- "Did this customer get their message" is asked by phone number far more often
-- than by reference.
CREATE INDEX IF NOT EXISTS idx_cp_sms_messages_recipient
    ON core_platform.cp_sms_messages (tenant_id, recipient, cdatetime DESC);


-- ---------------------------------------------------------------------------
-- Who changed a gateway's configuration, and to what
--
-- Credentials are money: someone quietly repointing a tenant's SMS at their own
-- account is worth being able to see after the fact. Values are redacted before
-- they reach old_data/new_data — the log records THAT a secret changed, never
-- what it changed to.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_sms_provider_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_cp_sms_provider_audit_logs_scope
    ON core_platform.cp_sms_provider_audit_logs (tenant_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_sms_provider_audit_logs_entity
    ON core_platform.cp_sms_provider_audit_logs (tenant_id, entity_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_sms_provider_audit_logs_action
    ON core_platform.cp_sms_provider_audit_logs (tenant_id, action);

CREATE INDEX IF NOT EXISTS idx_cp_sms_provider_audit_logs_performed_by
    ON core_platform.cp_sms_provider_audit_logs (tenant_id, performed_by);
