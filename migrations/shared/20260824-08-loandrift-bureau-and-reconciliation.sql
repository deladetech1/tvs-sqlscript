-- 20260824-08-loandrift-bureau-and-reconciliation.sql
-- Credit bureau enquiries and automated payment reconciliation for LoanDrift.
--
-- Two separate features that share one property: both are records of talking to
-- somebody outside the system, so both keep the raw exchange alongside what we
-- made of it. When a bureau disputes a score or a gateway disputes a payment,
-- the argument is settled by what was actually sent and received.
--
-- Gateway credentials are NOT here — they already live per tenant in
-- core_platform.cp_tenant_payment_providers (20260824-02), and the payments
-- themselves in cp_payment_collections. This migration only adds the LoanDrift
-- side: which collection paid off which loan.
--
-- Idempotent; safe to re-run on every deploy.

-- =====================================================
-- CREDIT BUREAU
-- =====================================================
-- Per-scope provider configuration. Secrets are Fernet tokens inside the
-- credentials blob, never plaintext, matching cp_tenant_payment_providers.
CREATE TABLE IF NOT EXISTS loandrift.ld_credit_bureau_settings (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,
    loc_id            text        NOT NULL,

    -- 'xds' | 'mycreditscore' | 'dataghana' | … The catalogue lives in code
    -- (bureau/registry.py) because adding a bureau means adding a client
    -- anyway, so a new provider needs no migration.
    provider_code     text        NOT NULL,
    credentials       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    mode              text        NOT NULL DEFAULT 'test',

    -- Pull a bureau report automatically when a loan is captured, rather than
    -- only when an officer asks. Off by default: every enquiry costs money.
    auto_enquire_on_capture boolean NOT NULL DEFAULT false,
    -- How long a report may be reused before another enquiry is worth paying
    -- for. 0 means always re-enquire.
    cache_days        integer     NOT NULL DEFAULT 30,

    is_active         boolean     NOT NULL DEFAULT true,
    is_default        boolean     NOT NULL DEFAULT false,
    description       text,
    delete_status     text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate             text,
    ctime             text,
    cdatetime         timestamptz DEFAULT NOW(),
    created_by        text,
    updated_by        text,
    deleted_by        text,

    CONSTRAINT ck_ld_credit_bureau_settings_mode
        CHECK (mode IN ('test','live')),
    CONSTRAINT ck_ld_credit_bureau_settings_delete_status
        CHECK (delete_status IN ('PENDING','DELETED','NOT_DELETED')),
    CONSTRAINT ck_ld_credit_bureau_settings_cache_days
        CHECK (cache_days >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_credit_bureau_settings_provider
    ON loandrift.ld_credit_bureau_settings (tenant_id, org_id, bus_id, loc_id, provider_code)
    WHERE delete_status = 'NOT_DELETED';
-- At most one default per scope, enforced here rather than by hoping every
-- write path remembers to clear the previous one.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_credit_bureau_settings_one_default
    ON loandrift.ld_credit_bureau_settings (tenant_id, org_id, bus_id, loc_id)
    WHERE is_default = true AND delete_status = 'NOT_DELETED';

-- One row per enquiry. Kept even when the enquiry failed: a bureau that is
-- refusing requests is something the operator needs to see, and a failed
-- enquiry still cost an API call.
CREATE TABLE IF NOT EXISTS loandrift.ld_credit_bureau_enquiries (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    loc_id              text        NOT NULL,

    client_id           text        NOT NULL,
    loan_id             text,
    loan_reference      text,

    provider_code       text        NOT NULL,
    -- What we searched on, so a mismatched report can be explained.
    subject_id_type     text,
    subject_id_number   text,
    subject_name        text,

    status              text        NOT NULL DEFAULT 'PENDING',
    -- The bureau's own score and grade, kept separate from LoanDrift's internal
    -- credit score — the two are different numbers on different scales and must
    -- never be silently conflated.
    bureau_score        integer,
    bureau_grade        text,
    bureau_reference    text,
    report_summary      jsonb,
    raw_response        jsonb,
    error_message       text,

    enquired_at         timestamptz,
    -- When the report stops being reusable, from the settings' cache_days.
    expires_at          timestamptz,

    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,

    CONSTRAINT ck_ld_credit_bureau_enquiries_status
        CHECK (status IN ('PENDING','SUCCESS','FAILED','NOT_FOUND'))
);

CREATE INDEX IF NOT EXISTS idx_ld_credit_bureau_enquiries_scope
    ON loandrift.ld_credit_bureau_enquiries (tenant_id, org_id, bus_id, loc_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_credit_bureau_enquiries_client
    ON loandrift.ld_credit_bureau_enquiries (tenant_id, client_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_credit_bureau_enquiries_loan
    ON loandrift.ld_credit_bureau_enquiries (tenant_id, loan_id);

-- =====================================================
-- PAYMENT RECONCILIATION
-- =====================================================
-- Links a payment taken through a gateway (core_platform.cp_payment_collections)
-- to the repayment it settled. Reconciliation is currently a person reading a
-- statement and typing repayments in; this is the record of the machine doing
-- it, including the cases it could not decide.
--
-- A row exists for every collection LoanDrift has looked at, matched or not,
-- so an unmatched payment is visible rather than simply absent.
CREATE TABLE IF NOT EXISTS loandrift.ld_payment_reconciliations (
    id                    text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text        NOT NULL,
    org_id                text        NOT NULL,
    bus_id                text        NOT NULL,
    loc_id                text        NOT NULL,

    -- cp_payment_collections.id and .reference. Not a foreign key: the payment
    -- lives in another schema owned by another service, and a reconciliation
    -- row must survive that row being archived.
    collection_id         text        NOT NULL,
    collection_reference  text,
    provider_code         text,
    provider_reference    text,

    amount_minor          bigint      NOT NULL DEFAULT 0,
    currency              text,
    paid_at               timestamptz,

    -- What it was matched to, once it has been.
    client_id             text,
    loan_id               text,
    loan_reference        text,
    repayment_id          text,

    status                text        NOT NULL DEFAULT 'UNMATCHED',
    -- How the match was found, so a wrong one can be traced to its rule:
    --   LOAN_REFERENCE  the payment reference carried the loan reference
    --   ACCOUNT_NUMBER  matched on the client's account/phone number
    --   AMOUNT_AND_DATE a single loan expecting exactly this amount that day
    --   MANUAL          a person chose it
    match_method          text,
    match_confidence      numeric(5,2),
    -- Why an automatic match was not made, in words an operator can act on.
    unmatched_reason      text,

    reviewed_by           text,
    reviewed_at           timestamptz,

    cdate                 text,
    ctime                 text,
    cdatetime             timestamptz DEFAULT NOW(),
    created_by            text,
    updated_by            text,

    CONSTRAINT ck_ld_payment_reconciliations_status
        CHECK (status IN ('UNMATCHED','MATCHED','POSTED','IGNORED','FAILED')),
    CONSTRAINT ck_ld_payment_reconciliations_method
        CHECK (match_method IS NULL OR match_method IN
               ('LOAN_REFERENCE','ACCOUNT_NUMBER','AMOUNT_AND_DATE','MANUAL'))
);

-- The poller re-reads collections it has already seen; one row per collection
-- makes a repeat a no-op instead of a duplicate repayment.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_payment_reconciliations_collection
    ON loandrift.ld_payment_reconciliations (tenant_id, collection_id);
CREATE INDEX IF NOT EXISTS idx_ld_payment_reconciliations_scope
    ON loandrift.ld_payment_reconciliations (tenant_id, org_id, bus_id, loc_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_payment_reconciliations_loan
    ON loandrift.ld_payment_reconciliations (tenant_id, loan_id);

-- Audit trails, same shape as the other LoanDrift audit tables (20260802-01).
CREATE TABLE IF NOT EXISTS loandrift.ld_credit_bureau_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    loc_id                 text,
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
CREATE INDEX IF NOT EXISTS idx_ld_credit_bureau_audit_logs_scope
    ON loandrift.ld_credit_bureau_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_credit_bureau_audit_logs_entity
    ON loandrift.ld_credit_bureau_audit_logs (tenant_id, entity_id);

CREATE TABLE IF NOT EXISTS loandrift.ld_reconciliation_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    loc_id                 text,
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
CREATE INDEX IF NOT EXISTS idx_ld_reconciliation_audit_logs_scope
    ON loandrift.ld_reconciliation_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_reconciliation_audit_logs_entity
    ON loandrift.ld_reconciliation_audit_logs (tenant_id, entity_id);
