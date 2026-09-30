-- Repayments: every way a loan is paid, and every way a payment is undone.
--
-- 1. ld_repayments gains what kind of payment it was (installment, partial,
--    full, early settlement, overpayment), how it arrived (manual, online,
--    automatic), any early-settlement charge and overpaid excess, and a
--    reversal record. A reversed payment is kept, marked REVERSED, and leaves
--    every balance the way it was before it was made.
-- 2. SAVINGS is a payment method: an automatic repayment taken from the
--    client's savings account.
-- 3. ld_client_credits: money a client paid beyond what they owed, held for
--    them until refunded or applied to another loan.
-- 4. ld_auto_repayment_mandates / _runs: standing instructions to take each
--    installment from savings on its due date, and every attempt made.
-- 5. Journal source type CLIENT_CREDIT, for refunds of that credit.
-- 6. Permissions to reverse, to refund, and to set up automatic repayment.
--
-- Idempotent; safe to re-run on every deploy.

-- 1 -----------------------------------------------------------------------
ALTER TABLE loandrift.ld_repayments
    ADD COLUMN IF NOT EXISTS repayment_type TEXT,
    ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'MANUAL',
    ADD COLUMN IF NOT EXISTS early_charge NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS overpaid_amount NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'POSTED',
    ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reversed_by TEXT,
    ADD COLUMN IF NOT EXISTS reversal_reason TEXT,
    ADD COLUMN IF NOT EXISTS auto_run_id TEXT,
    -- When the row was written, to the microsecond. cdatetime is when the payment
    -- happened (and can be backdated); this is the order payments were recorded
    -- in, which is the order a reversal must undo them.
    ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ DEFAULT clock_timestamp();

DO $$ BEGIN
    ALTER TABLE loandrift.ld_repayments ADD CONSTRAINT ck_ld_repayments_repayment_type
        CHECK (repayment_type IS NULL OR repayment_type IN ('INSTALLMENT', 'PARTIAL', 'FULL', 'EARLY_SETTLEMENT', 'OVERPAYMENT'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    ALTER TABLE loandrift.ld_repayments ADD CONSTRAINT ck_ld_repayments_channel
        CHECK (channel IN ('MANUAL', 'ONLINE', 'AUTOMATIC'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    ALTER TABLE loandrift.ld_repayments ADD CONSTRAINT ck_ld_repayments_status
        CHECK (status IN ('POSTED', 'REVERSED'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Payments recorded before this migration: online ones are known by their reference.
UPDATE loandrift.ld_repayments SET channel = 'ONLINE'
 WHERE online_payment_reference IS NOT NULL AND channel = 'MANUAL';

-- 2 -----------------------------------------------------------------------
ALTER TABLE loandrift.ld_repayments DROP CONSTRAINT IF EXISTS ck_ld_repayments_payment_method;
ALTER TABLE loandrift.ld_repayments ADD CONSTRAINT ck_ld_repayments_payment_method
    CHECK (payment_method IS NULL OR payment_method IN ('CASH', 'CHEQUE', 'MOMO', 'BANK_TRANSFER', 'CARD', 'SAVINGS', 'OTHERS'));

-- 3 -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS loandrift.ld_client_credits (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    client_id TEXT NOT NULL,
    loan_id TEXT,
    repayment_id TEXT,
    -- OVERPAYMENT adds to the credit; REFUND and REVERSAL take from it.
    entry_type TEXT NOT NULL CHECK (entry_type IN ('OVERPAYMENT', 'REFUND', 'REVERSAL')),
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_method TEXT,
    reference TEXT,
    notes TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);
CREATE INDEX IF NOT EXISTS idx_ld_client_credits_client ON loandrift.ld_client_credits (tenant_id, client_id);

-- 4 -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS loandrift.ld_auto_repayment_mandates (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    client_id TEXT NOT NULL,
    loan_id TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'SAVINGS' CHECK (source IN ('SAVINGS')),
    savings_id TEXT NOT NULL,
    -- INSTALLMENT takes whatever is due; FIXED takes the same amount each time.
    amount_mode TEXT NOT NULL DEFAULT 'INSTALLMENT' CHECK (amount_mode IN ('INSTALLMENT', 'FIXED')),
    fixed_amount NUMERIC CHECK (fixed_amount IS NULL OR fixed_amount > 0),
    -- Take what is in the account when it holds less than the amount due.
    allow_partial BOOLEAN NOT NULL DEFAULT true,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'PAUSED', 'CANCELLED', 'COMPLETED')),
    last_run_at TIMESTAMPTZ,
    last_result TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    udatetime TIMESTAMPTZ,
    updated_by TEXT
);
-- One live instruction per loan.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_auto_repayment_mandates_live
    ON loandrift.ld_auto_repayment_mandates (tenant_id, loan_id) WHERE status IN ('ACTIVE', 'PAUSED');

CREATE TABLE IF NOT EXISTS loandrift.ld_auto_repayment_runs (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    mandate_id TEXT NOT NULL REFERENCES loandrift.ld_auto_repayment_mandates (id) ON DELETE CASCADE,
    loan_id TEXT NOT NULL,
    due_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('SUCCESS', 'PARTIAL', 'FAILED', 'SKIPPED')),
    amount_due NUMERIC,
    amount_taken NUMERIC NOT NULL DEFAULT 0,
    repayment_id TEXT,
    message TEXT,
    triggered_by TEXT NOT NULL DEFAULT 'SCHEDULE' CHECK (triggered_by IN ('SCHEDULE', 'MANUAL')),
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- An installment is collected once, however often the job runs.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_auto_repayment_runs_collected
    ON loandrift.ld_auto_repayment_runs (mandate_id, due_date) WHERE status IN ('SUCCESS', 'PARTIAL');
CREATE INDEX IF NOT EXISTS idx_ld_auto_repayment_runs_mandate ON loandrift.ld_auto_repayment_runs (mandate_id, cdatetime DESC);

-- 5 -----------------------------------------------------------------------
ALTER TABLE loandrift.ld_journal_entries DROP CONSTRAINT IF EXISTS ck_ld_journal_entries_source_type;
ALTER TABLE loandrift.ld_journal_entries ADD CONSTRAINT ck_ld_journal_entries_source_type
    CHECK (source_type IN ('LOAN_DISBURSEMENT', 'REPAYMENT', 'PENALTY', 'PENALTY_WAIVER', 'EXPENSE',
        'SAVINGS_DEPOSIT', 'SAVINGS_WITHDRAWAL', 'SAVINGS_INTEREST', 'INVESTMENT', 'INVESTMENT_RETURN',
        'DEPRECIATION', 'ASSET_ACQUISITION', 'ASSET_DISPOSAL', 'WRITE_OFF', 'MANUAL', 'CLIENT_CREDIT'));

-- 6 -----------------------------------------------------------------------
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES
('permission-loandrift-repayment-reverse', 'Loandrift Repayment Reverse', 'rt-repayment',
 'Can reverse a repayment, restoring the balance, penalties and books as they were before it', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-refund', 'Loandrift Repayment Refund', 'rt-repayment',
 'Can refund a client''s credit from an overpayment', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-loandrift-repayment-auto', 'Loandrift Repayment Automatic', 'rt-repayment',
 'Can set up, pause and cancel automatic repayment from a client''s savings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name, description=EXCLUDED.description,
    resource_type_id=EXCLUDED.resource_type_id;

-- role-owner, role-admin and role-subscribed-app-loandrift-admin are deliberately absent from the
-- grant below. Both are allowed by being the role (tvs-package 1.0.42 / 1.0.43), and
-- listing them meant every deploy quietly re-granted rows that 20260929-03 removes --
-- which is how Owner drifted back from 0 to 29 rows overnight.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name),
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r
JOIN core_platform.cp_permissions p ON p.id IN (
  'permission-loandrift-repayment-reverse', 'permission-loandrift-repayment-refund', 'permission-loandrift-repayment-auto')
WHERE r.is_system = true
  AND r.id IN ('role-loandrift-repayment-admin')
ON CONFLICT DO NOTHING;

-- Automatic repayment draws on savings, so it sits on the same plan (Advance).
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.auto-repayments', 'app-loandrift', 'Automatic Repayment', 2,
 'Installments taken from the borrower''s savings on their due dates')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
