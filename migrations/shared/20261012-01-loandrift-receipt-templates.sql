-- LoanDrift receipt templates.
--
-- Every business prints repayment receipts in LoanDrift Standard, the plain design it
-- has always had. Choosing one of the ready-made designs, or making its own, is a
-- Premium feature (loandrift.receipt-templates). The ready-made designs live in the
-- API (rc_receipt_templates.py); a business's own live here.
--
-- A template is design only: layout, colour, typeface, title, how the total is shown,
-- a PAID stamp and signature lines. What a receipt shows stays in ld_receipt_settings,
-- and every figure still comes from the ledger.
--
-- Idempotent; safe to re-run on every deploy.

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.receipt-templates', 'app-loandrift', 'Receipt Templates', 3,
 'Choose a ready-made repayment receipt design, or make and edit your own')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;

CREATE TABLE IF NOT EXISTS loandrift.ld_receipt_templates (
    tenant_id   text NOT NULL,
    id          text NOT NULL,
    org_id      text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL,
    description text,
    -- The ready-made design it was started from, if any.
    based_on    text,
    style       jsonb,
    is_deleted  boolean NOT NULL DEFAULT false,
    created_by  text,
    updated_by  text,
    cdatetime   timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_receipt_templates PRIMARY KEY (id, tenant_id)
);
CREATE INDEX IF NOT EXISTS ix_ld_receipt_templates_business
    ON loandrift.ld_receipt_templates (tenant_id, org_id, bus_id) WHERE NOT is_deleted;

-- Which design receipts print in: a ready-made key (e.g. 'modern-navy') or the id of
-- one of the business's own. NULL means LoanDrift Standard.
ALTER TABLE loandrift.ld_receipt_settings ADD COLUMN IF NOT EXISTS template_key text;
