-- Collateral management, and loan agreements generated after approval.
--
-- Two gaps this closes:
--   1. Collateral was one free-text item and a value on each guarantor. There was
--      nowhere to record what the asset is, who owns it, what it was valued at and
--      by whom, whether a lien is registered on it, or whether it has been released
--      or is being recovered.
--   2. An approved loan produced no paperwork. The agreement, the repayment
--      schedule, the offer letter and the guarantor and collateral agreements now
--      come from the approved terms, are signed in the branch, and are kept.
--
-- The guarantor collateral fields are left as they are: the credit score and the
-- credit bureau return read them, and a collateral record can name the guarantor
-- who pledged it.
--
-- Idempotent; safe to re-run on every deploy.

-- ------------------------------------------------------------------ collateral

CREATE TABLE IF NOT EXISTS loandrift.ld_collaterals (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    client_id        text NOT NULL,
    -- The loan it secures. Empty while it is registered but not yet pledged.
    loan_id          text,
    -- The guarantor who pledged it, when the owner is a guarantor. Informational:
    -- guarantor ids are replaced when a loan's capture is edited before approval.
    guarantor_id     text,

    collateral_type  text NOT NULL,
    title            text NOT NULL,
    description      text,
    -- What identifies this kind of asset: a vehicle's registration and chassis
    -- numbers, a property's title deed and address, and so on.
    details          jsonb NOT NULL DEFAULT '{}'::jsonb,
    estimated_value  numeric(18,2) NOT NULL DEFAULT 0,
    currency_id      text,

    ownership_type   text NOT NULL DEFAULT 'BORROWER',
    owner_name       text,
    owner_contact    text,
    owner_id_number  text,
    ownership_reference text,

    status           text NOT NULL DEFAULT 'REGISTERED',
    verified_by      text,
    verified_at      timestamp with time zone,

    lien_status      text NOT NULL DEFAULT 'NONE',
    lien_holder      text,
    lien_registry    text,
    lien_reference   text,
    lien_registered_at date,
    lien_discharged_at date,
    lien_notes       text,

    release_status   text NOT NULL DEFAULT 'NOT_RELEASED',
    release_requested_at timestamp with time zone,
    release_requested_by text,
    released_at      timestamp with time zone,
    released_by      text,
    release_notes    text,

    recovery_status  text NOT NULL DEFAULT 'NONE',
    recovery_started_at timestamp with time zone,
    recovery_updated_at timestamp with time zone,
    recovered_amount numeric(18,2),
    recovery_notes   text,

    -- ld_client_documents_paths ids, as for clients and guarantors.
    document_ids     text[] NOT NULL DEFAULT '{}',
    photo_ids        text[] NOT NULL DEFAULT '{}',

    cdate            text,
    ctime            text,
    cdatetime        timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by       text,
    updated_by       text,
    deleted_by       text,
    delete_status    text NOT NULL DEFAULT 'NOT_DELETED',
    is_active        boolean NOT NULL DEFAULT true,

    CONSTRAINT pk_ld_collaterals PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_collaterals_delete_status CHECK (delete_status IN ('NOT_DELETED', 'DELETED', 'PENDING_DELETION')),
    CONSTRAINT ck_ld_collaterals_type CHECK (collateral_type IN ('VEHICLE', 'PROPERTY', 'EQUIPMENT', 'INVENTORY', 'LAND', 'OTHER')),
    CONSTRAINT ck_ld_collaterals_value CHECK (estimated_value >= 0),
    CONSTRAINT ck_ld_collaterals_ownership CHECK (ownership_type IN ('BORROWER', 'GUARANTOR', 'THIRD_PARTY', 'JOINT')),
    CONSTRAINT ck_ld_collaterals_status CHECK (status IN (
        'REGISTERED', 'VERIFIED', 'REJECTED', 'PLEDGED', 'RELEASED', 'UNDER_RECOVERY', 'RECOVERED', 'WRITTEN_OFF')),
    CONSTRAINT ck_ld_collaterals_lien CHECK (lien_status IN ('NONE', 'PENDING', 'REGISTERED', 'DISCHARGED')),
    CONSTRAINT ck_ld_collaterals_release CHECK (release_status IN ('NOT_RELEASED', 'REQUESTED', 'RELEASED')),
    CONSTRAINT ck_ld_collaterals_recovery CHECK (recovery_status IN ('NONE', 'INITIATED', 'IN_PROGRESS', 'RECOVERED', 'SOLD', 'WRITTEN_OFF')),
    CONSTRAINT fk_ld_collaterals_client FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, client_id)
        REFERENCES loandrift.ld_clients(tenant_id, org_id, bus_id, loc_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_ld_collaterals_loan FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, loan_id)
        REFERENCES loandrift.ld_loan_details(tenant_id, org_id, bus_id, loc_id, id) ON DELETE SET NULL (loan_id)
);

CREATE INDEX IF NOT EXISTS ix_ld_collaterals_scope
    ON loandrift.ld_collaterals (tenant_id, org_id, bus_id, loc_id, status) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS ix_ld_collaterals_loan
    ON loandrift.ld_collaterals (tenant_id, loan_id) WHERE delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS ix_ld_collaterals_client
    ON loandrift.ld_collaterals (tenant_id, client_id) WHERE delete_status = 'NOT_DELETED';

COMMENT ON TABLE loandrift.ld_collaterals IS
    'Assets pledged as security: what they are, who owns them, their value, lien, release and recovery.';

-- Each time someone put a value on the asset. The newest is the current value.
CREATE TABLE IF NOT EXISTS loandrift.ld_collateral_valuations (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    collateral_id    text NOT NULL,
    valuation_date   date NOT NULL,
    valuation_type   text NOT NULL DEFAULT 'INTERNAL',
    valuer_name      text,
    valuer_company   text,
    market_value     numeric(18,2) NOT NULL,
    -- What it would fetch in a quick sale: the figure that matters on recovery.
    forced_sale_value numeric(18,2),
    notes            text,
    document_ids     text[] NOT NULL DEFAULT '{}',
    cdate            text,
    ctime            text,
    cdatetime        timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by       text,
    delete_status    text NOT NULL DEFAULT 'NOT_DELETED',

    CONSTRAINT pk_ld_collateral_valuations PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_collateral_valuations_type CHECK (valuation_type IN ('INTERNAL', 'INDEPENDENT', 'MARKET_ESTIMATE')),
    CONSTRAINT ck_ld_collateral_valuations_values CHECK (market_value >= 0 AND (forced_sale_value IS NULL OR forced_sale_value >= 0)),
    CONSTRAINT fk_ld_collateral_valuations_collateral FOREIGN KEY (collateral_id, tenant_id)
        REFERENCES loandrift.ld_collaterals(id, tenant_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_ld_collateral_valuations_collateral
    ON loandrift.ld_collateral_valuations (tenant_id, collateral_id, valuation_date DESC);

-- Everything that happened to an asset, in order: registered, verified, valued,
-- pledged, lien registered, release requested, released, recovery steps.
CREATE TABLE IF NOT EXISTS loandrift.ld_collateral_events (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    collateral_id    text NOT NULL,
    event_type       text NOT NULL,
    from_status      text,
    to_status        text,
    notes            text,
    data             jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_by       text,
    cdatetime        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_collateral_events PRIMARY KEY (id, tenant_id),
    CONSTRAINT fk_ld_collateral_events_collateral FOREIGN KEY (collateral_id, tenant_id)
        REFERENCES loandrift.ld_collaterals(id, tenant_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_ld_collateral_events_collateral
    ON loandrift.ld_collateral_events (tenant_id, collateral_id, cdatetime DESC);

-- ------------------------------------------------------------- loan agreements

-- The wording a business puts in its agreements. Business-wide, like the
-- company profile; LoanDrift supplies default terms until one is saved.
CREATE TABLE IF NOT EXISTS loandrift.ld_agreement_settings (
    tenant_id        text NOT NULL,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    terms_and_conditions text,
    offer_validity_days integer NOT NULL DEFAULT 14,
    governing_law    text NOT NULL DEFAULT 'the laws of the Republic of Ghana',
    lender_signatory_name  text,
    lender_signatory_title text,
    -- When on, a loan cannot be disbursed until its agreement is fully signed.
    require_signed_before_disbursement boolean NOT NULL DEFAULT false,
    updated_by       text,
    cdatetime        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_agreement_settings PRIMARY KEY (tenant_id, org_id, bus_id),
    CONSTRAINT ck_ld_agreement_settings_validity CHECK (offer_validity_days BETWEEN 1 AND 365)
);

-- One row per generated set of documents. The snapshot freezes every figure,
-- name and clause the documents were printed from, so they read the same years
-- later whatever happens to the loan, the settings or the client record.
CREATE TABLE IF NOT EXISTS loandrift.ld_loan_agreements (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    loan_id          text NOT NULL,
    client_id        text NOT NULL,
    agreement_number text NOT NULL,
    version          integer NOT NULL DEFAULT 1,
    status           text NOT NULL DEFAULT 'PENDING_SIGNATURE',
    snapshot         jsonb NOT NULL,
    -- SHA-256 of the snapshot, printed on every page: proof the terms signed are
    -- the terms generated.
    content_hash     text NOT NULL,
    offer_expires_on date,
    generated_by     text,
    generated_at     timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accepted_at      timestamp with time zone,
    voided_at        timestamp with time zone,
    voided_by        text,
    void_reason      text,
    cdate            text,
    ctime            text,
    cdatetime        timestamp with time zone DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_loan_agreements PRIMARY KEY (id, tenant_id),
    CONSTRAINT uq_ld_loan_agreements_version UNIQUE (tenant_id, loan_id, version),
    CONSTRAINT ck_ld_loan_agreements_status CHECK (status IN ('PENDING_SIGNATURE', 'ACCEPTED', 'VOIDED', 'SUPERSEDED')),
    CONSTRAINT fk_ld_loan_agreements_loan FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, loan_id)
        REFERENCES loandrift.ld_loan_details(tenant_id, org_id, bus_id, loc_id, id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_ld_loan_agreements_loan
    ON loandrift.ld_loan_agreements (tenant_id, loan_id, version DESC);

-- The PDFs made from an agreement, and where each was stored.
CREATE TABLE IF NOT EXISTS loandrift.ld_loan_agreement_documents (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    agreement_id     text NOT NULL,
    doc_type         text NOT NULL,
    -- For a guarantor agreement: which guarantor it binds.
    guarantor_id     text,
    -- ld_client_documents_paths id. Empty when storage failed; the document can
    -- still be downloaded, because it is rebuilt from the snapshot.
    document_id      text,
    file_name        text NOT NULL,
    storage_error    text,
    cdatetime        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_loan_agreement_documents PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_loan_agreement_documents_type CHECK (doc_type IN (
        'LOAN_AGREEMENT', 'REPAYMENT_SCHEDULE', 'OFFER_LETTER', 'GUARANTOR_AGREEMENT',
        'COLLATERAL_AGREEMENT', 'SIGNED_LOAN_AGREEMENT')),
    CONSTRAINT fk_ld_loan_agreement_documents_agreement FOREIGN KEY (agreement_id, tenant_id)
        REFERENCES loandrift.ld_loan_agreements(id, tenant_id) ON DELETE CASCADE
);

-- Who signed, how, and when. Signing happens in the branch: the borrower,
-- each guarantor and a lender officer sign on screen or type their name.
CREATE TABLE IF NOT EXISTS loandrift.ld_loan_agreement_signatures (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    agreement_id     text NOT NULL,
    signer_role      text NOT NULL,
    guarantor_id     text,
    signer_name      text NOT NULL,
    method           text NOT NULL,
    -- A drawn signature as a PNG data URL; empty for a typed one.
    signature_data   text,
    consent_text     text NOT NULL,
    signed_at        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- The staff member whose session the signature was captured on.
    captured_by      text,
    ip_address       text,
    user_agent       text,

    CONSTRAINT pk_ld_loan_agreement_signatures PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_loan_agreement_signatures_role CHECK (signer_role IN ('BORROWER', 'GUARANTOR', 'LENDER', 'WITNESS')),
    CONSTRAINT ck_ld_loan_agreement_signatures_method CHECK (method IN ('DRAWN', 'TYPED')),
    CONSTRAINT ck_ld_loan_agreement_signatures_drawn CHECK (method <> 'DRAWN' OR signature_data IS NOT NULL),
    CONSTRAINT ck_ld_loan_agreement_signatures_size CHECK (signature_data IS NULL OR length(signature_data) <= 400000),
    CONSTRAINT fk_ld_loan_agreement_signatures_agreement FOREIGN KEY (agreement_id, tenant_id)
        REFERENCES loandrift.ld_loan_agreements(id, tenant_id) ON DELETE CASCADE
);

-- Each party signs a given agreement once.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_loan_agreement_signatures_party
    ON loandrift.ld_loan_agreement_signatures (tenant_id, agreement_id, signer_role, COALESCE(guarantor_id, ''));
