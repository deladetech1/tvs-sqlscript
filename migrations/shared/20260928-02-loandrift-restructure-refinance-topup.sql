-- Restructuring, refinancing and top-ups.
--
-- Each is a new loan that replaces an existing one. The new loan carries the old
-- loan's outstanding balance (and any penalties) as part of its principal, plus
-- any new cash for a top-up, on new terms. When the new loan is disbursed, the
-- old one is settled in full by an internal transfer and closed. Until then the
-- old loan runs as normal.
--
--   RESTRUCTURE: the same debt on new terms (longer term, different frequency),
--                no new cash.
--   REFINANCE:   new terms, optionally a new rate, optionally some new cash.
--   TOPUP:       new cash on top of the balance.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS origin_type TEXT NOT NULL DEFAULT 'NEW',
    ADD COLUMN IF NOT EXISTS parent_loan_id TEXT,
    ADD COLUMN IF NOT EXISTS settlement_amount NUMERIC,
    ADD COLUMN IF NOT EXISTS replaced_by_loan_id TEXT,
    ADD COLUMN IF NOT EXISTS origin_reason TEXT;

DO $$ BEGIN
    ALTER TABLE loandrift.ld_loan_details ADD CONSTRAINT ck_ld_loan_details_origin_type
        CHECK (origin_type IN ('NEW', 'RESTRUCTURE', 'REFINANCE', 'TOPUP', 'GROUP'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_ld_loan_details_parent ON loandrift.ld_loan_details (tenant_id, parent_loan_id) WHERE parent_loan_id IS NOT NULL;

-- The old loan's settlement is an internal transfer, not money handed over.
ALTER TABLE loandrift.ld_repayments DROP CONSTRAINT IF EXISTS ck_ld_repayments_payment_method;
ALTER TABLE loandrift.ld_repayments ADD CONSTRAINT ck_ld_repayments_payment_method
    CHECK (payment_method IS NULL OR payment_method IN ('CASH', 'CHEQUE', 'MOMO', 'BANK_TRANSFER', 'CARD', 'SAVINGS', 'REFINANCE', 'OTHERS'));

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.restructuring', 'app-loandrift', 'Restructuring, Refinancing & Top-ups', 2,
 'Replace a running loan with a new one on new terms, with or without new cash')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-capturing-restructure', 'Loandrift Loan Restructure', 'rt-capturing',
 'Can restructure, refinance or top up a running loan (the new loan still goes through approval)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name, description=EXCLUDED.description, resource_type_id=EXCLUDED.resource_type_id;

-- role-owner and role-subscribed-app-loandrift-admin are deliberately absent from the
-- grant below. Both are allowed by being the role (tvs-package 1.0.42 / 1.0.43), and
-- listing them meant every deploy quietly re-granted rows that 20260929-03 removes --
-- which is how Owner drifted back from 0 to 29 rows overnight.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name), CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r JOIN core_platform.cp_permissions p ON p.id = 'permission-loandrift-capturing-restructure'
WHERE r.is_system = true AND r.id IN ('role-admin', 'role-loandrift-capturing-admin')
ON CONFLICT DO NOTHING;
