-- =====================================================================
-- Audit trail for the company and branch profile
-- ---------------------------------------------------------------------
-- The company profile holds the identity a lender files regulatory returns
-- under — its Bank of Ghana institution code, licence number and TIN — and the
-- branch profile holds the branch codes those returns are keyed on. Get one of
-- them wrong and every facility in a submission is misattributed, so "who
-- changed the institution code, and when" is a question a supervisor will ask.
--
-- Same shape as every other ld_*_audit_logs table (20260802-01), so the
-- audit-log reader and the retention purge both pick it up without changes.
--
-- Retention is by convention, not registration: the purge walks every table in
-- a schema named in core_platform.cp_app_schemas and deletes by tenant_id +
-- cdatetime. Both columns are here, and LoanDrift already has its row, so
-- nothing further is needed for this table to age out with the rest.
--
-- One table for both profiles rather than two. A branch profile is only ever
-- edited as part of setting the institution up for reporting, and entity_name
-- already distinguishes "Company profile" from "Branch profile" in the reader,
-- so a second table would split one story across two screens.
--
-- loc_id is nullable, as on the other LoanDrift audit tables: the company
-- profile is business-level and leaves it null; a branch profile sets it to the
-- location it describes.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

CREATE TABLE IF NOT EXISTS loandrift.ld_company_profile_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_ld_company_profile_audit_logs_scope
    ON loandrift.ld_company_profile_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_company_profile_audit_logs_action
    ON loandrift.ld_company_profile_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_company_profile_audit_logs_performed_by
    ON loandrift.ld_company_profile_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_company_profile_audit_logs_entity
    ON loandrift.ld_company_profile_audit_logs (tenant_id, entity_id);
