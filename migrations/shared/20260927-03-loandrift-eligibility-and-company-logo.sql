-- Who may borrow, and the lender's logo on its documents.
--
-- 1. ld_loan_eligibility_settings: the checks a client must pass before a loan
--    goes ahead. Minimum age defaults to 18; a business may raise it, set a
--    maximum age, or relax the identification rule.
-- 2. ld_company_profile.logo_document_id: the logo uploaded under Settings >
--    Company Information, printed on loan agreements and other documents.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_loan_eligibility_settings (
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    min_age INTEGER NOT NULL DEFAULT 18,
    max_age INTEGER,
    require_valid_id BOOLEAN NOT NULL DEFAULT true,
    updated_by TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    udatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, org_id, bus_id),
    CONSTRAINT ld_loan_eligibility_min_age_chk CHECK (min_age BETWEEN 16 AND 100),
    CONSTRAINT ld_loan_eligibility_max_age_chk CHECK (max_age IS NULL OR (max_age BETWEEN 18 AND 120 AND max_age >= min_age))
);

ALTER TABLE loandrift.ld_company_profile ADD COLUMN IF NOT EXISTS logo_document_id TEXT;
COMMENT ON COLUMN loandrift.ld_company_profile.logo_document_id IS
    'ld_client_documents_paths id of the logo, printed on loan agreements and other documents';
