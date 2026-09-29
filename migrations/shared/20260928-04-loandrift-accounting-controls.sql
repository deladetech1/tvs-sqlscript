-- Accounting controls: manual journals, loan write-offs and recoveries, loan-loss
-- provisioning, and period close.
--
-- 1. Journal entries gain what a hand-written entry needs: an external reference
--    (cheque or bank slip number), who submitted and who approved it, and when.
--    A manual entry that needs a second person waits as DRAFT, which the ledger
--    already ignores.
-- 2. New journal source types: OPENING_BALANCE, PROVISION, WRITE_OFF_RECOVERY and
--    YEAR_END_CLOSE.
-- 3. ld_accounting_settings: the lock date (nothing is posted on or before it),
--    whether manual journals and write-offs need a second person, and the
--    financial year end.
-- 4. ld_accounting_period_closes: every close and reopen, with the year-end
--    closing entry when there is one.
-- 5. ld_loan_write_offs and ld_loan_write_off_recoveries: a write-off request,
--    its decision and ledger entry, and money recovered afterwards.
-- 6. ld_provision_runs: each loan-loss provision posting, with the classification
--    it was based on.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS reference TEXT;
ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS submitted_by TEXT;
ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS approved_by TEXT;
ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS rejected_reason TEXT;
-- The date the event happened, when it fell in a closed period and the entry was
-- dated into the first open day instead.
ALTER TABLE loandrift.ld_journal_entries ADD COLUMN IF NOT EXISTS original_date DATE;

DO $$
DECLARE c TEXT;
BEGIN
    FOR c IN SELECT conname FROM pg_constraint
             WHERE conrelid = 'loandrift.ld_journal_entries'::regclass AND contype = 'c'
               AND pg_get_constraintdef(oid) LIKE '%source_type%'
    LOOP
        EXECUTE format('ALTER TABLE loandrift.ld_journal_entries DROP CONSTRAINT %I', c);
    END LOOP;
END $$;
ALTER TABLE loandrift.ld_journal_entries ADD CONSTRAINT ck_ld_journal_entries_source_type CHECK (source_type IN (
    'LOAN_DISBURSEMENT','REPAYMENT','PENALTY','PENALTY_WAIVER','EXPENSE','SAVINGS_DEPOSIT','SAVINGS_WITHDRAWAL',
    'SAVINGS_INTEREST','INVESTMENT','INVESTMENT_RETURN','DEPRECIATION','ASSET_ACQUISITION','ASSET_DISPOSAL',
    'WRITE_OFF','MANUAL','CLIENT_CREDIT','OPENING_BALANCE','PROVISION','WRITE_OFF_RECOVERY','YEAR_END_CLOSE'));

CREATE TABLE IF NOT EXISTS loandrift.ld_accounting_settings (
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    lock_date DATE,
    manual_journal_approval BOOLEAN NOT NULL DEFAULT false,
    write_off_approval BOOLEAN NOT NULL DEFAULT false,
    -- Month and day the financial year ends (default 31 December).
    year_end_month INTEGER NOT NULL DEFAULT 12 CHECK (year_end_month BETWEEN 1 AND 12),
    year_end_day INTEGER NOT NULL DEFAULT 31 CHECK (year_end_day BETWEEN 1 AND 31),
    udatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by TEXT,
    PRIMARY KEY (tenant_id, org_id, bus_id, loc_id)
);

CREATE TABLE IF NOT EXISTS loandrift.ld_accounting_period_closes (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('CLOSE','YEAR_END','REOPEN')),
    lock_date DATE,
    previous_lock_date DATE,
    closing_entry_id TEXT,
    net_profit NUMERIC(18,2),
    note TEXT,
    -- clock_timestamp: several actions in one transaction still sort in order.
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    created_by TEXT
);
ALTER TABLE loandrift.ld_accounting_period_closes ALTER COLUMN cdatetime SET DEFAULT clock_timestamp();
CREATE INDEX IF NOT EXISTS idx_ld_accounting_period_closes_scope ON loandrift.ld_accounting_period_closes (tenant_id, org_id, bus_id, loc_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS loandrift.ld_loan_write_offs (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    loan_id TEXT NOT NULL,
    client_id TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),
    previous_status TEXT,
    principal_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    interest_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    penalty_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    from_allowance NUMERIC(18,2) NOT NULL DEFAULT 0,
    days_overdue INTEGER,
    reason TEXT NOT NULL,
    write_off_date DATE NOT NULL DEFAULT CURRENT_DATE,
    requested_by TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by TEXT,
    decided_at TIMESTAMPTZ,
    decision_note TEXT,
    journal_entry_id TEXT,
    recovered_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    -- The penalty rows cleared by the write-off, so reversing it can restore them.
    penalties_cleared JSONB NOT NULL DEFAULT '[]'::jsonb
);
ALTER TABLE loandrift.ld_loan_write_offs ADD COLUMN IF NOT EXISTS penalties_cleared JSONB NOT NULL DEFAULT '[]'::jsonb;
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_loan_write_offs_open ON loandrift.ld_loan_write_offs (tenant_id, loan_id) WHERE status IN ('PENDING','APPROVED');
CREATE INDEX IF NOT EXISTS idx_ld_loan_write_offs_scope ON loandrift.ld_loan_write_offs (tenant_id, org_id, bus_id, loc_id, status);

CREATE TABLE IF NOT EXISTS loandrift.ld_loan_write_off_recoveries (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    write_off_id TEXT NOT NULL REFERENCES loandrift.ld_loan_write_offs (id),
    loan_id TEXT NOT NULL,
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'CASH',
    reference TEXT,
    note TEXT,
    recovered_on DATE NOT NULL DEFAULT CURRENT_DATE,
    journal_entry_id TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);
CREATE INDEX IF NOT EXISTS idx_ld_loan_write_off_recoveries_wo ON loandrift.ld_loan_write_off_recoveries (write_off_id);

CREATE TABLE IF NOT EXISTS loandrift.ld_provision_runs (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    as_of DATE NOT NULL,
    required NUMERIC(18,2) NOT NULL,
    previous_balance NUMERIC(18,2) NOT NULL,
    adjustment NUMERIC(18,2) NOT NULL,
    journal_entry_id TEXT,
    breakdown JSONB NOT NULL DEFAULT '[]'::jsonb,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);
CREATE INDEX IF NOT EXISTS idx_ld_provision_runs_scope ON loandrift.ld_provision_runs (tenant_id, org_id, bus_id, loc_id, as_of DESC);

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT v.id, v.name, 'rt-capturing', v.description, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM (VALUES
    ('permission-loandrift-capturing-write-off', 'Loandrift Capturing Write Off', 'Can request that a loan be written off'),
    ('permission-loandrift-capturing-write-off-approve', 'Loandrift Capturing Write Off Approve', 'Can approve loan write-offs and record recoveries')
) AS v(id, name, description)
ON CONFLICT (id) DO UPDATE SET permission_name=EXCLUDED.permission_name, description=EXCLUDED.description, resource_type_id=EXCLUDED.resource_type_id;

-- role-owner, role-admin and role-subscribed-app-loandrift-admin are deliberately absent from the
-- grant below. Both are allowed by being the role (tvs-package 1.0.42 / 1.0.43), and
-- listing them meant every deploy quietly re-granted rows that 20260929-03 removes --
-- which is how Owner drifted back from 0 to 29 rows overnight.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT r.tenant_id, r.id, p.id, r.role_name || ' can ' || lower(p.permission_name), CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
FROM core_platform.cp_roles r JOIN core_platform.cp_permissions p ON p.id LIKE 'permission-loandrift-capturing-write-off%'
WHERE r.is_system = true AND r.id IN ('role-loandrift-finance-manager', 'role-loandrift-capturing-admin')
ON CONFLICT DO NOTHING;
