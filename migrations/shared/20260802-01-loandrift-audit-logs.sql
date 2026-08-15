-- 20260802-01-loandrift-audit-logs.sql
-- Per-entity audit logs for LoanDrift, mirroring the MyStoreGuard audit tables
-- (20260714-11 customers/suppliers, 20260714-13 inventory, 20260715-03 sales, ...).
-- One dedicated table per audited entity. Every create/update/delete/etc. appends
-- one row, written in the same transaction as the operation so it commits or rolls
-- back atomically with it. old_data/new_data are JSONB so the UI can render a clean
-- before/after diff, with reference ids already resolved to names by AuditLogService.
--
-- LoanDrift is location-scoped, so unlike the MyStoreGuard tables these carry a
-- nullable loc_id: location-scoped entities (loans, repayments, savings, ...) set it,
-- org/business-level reference data and settings (sectors, loan types, ...) leave it null.
--
-- Idempotent; safe to re-run on every deploy.

-- Clients captured in LoanDrift
CREATE TABLE IF NOT EXISTS loandrift.ld_client_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_client_audit_logs_scope
    ON loandrift.ld_client_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_client_audit_logs_action
    ON loandrift.ld_client_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_client_audit_logs_performed_by
    ON loandrift.ld_client_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_client_audit_logs_entity
    ON loandrift.ld_client_audit_logs (tenant_id, entity_id);

-- Loans across their whole lifecycle (registration, capture, approval, disbursement, activation, completion)
CREATE TABLE IF NOT EXISTS loandrift.ld_loan_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_loan_audit_logs_scope
    ON loandrift.ld_loan_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_loan_audit_logs_action
    ON loandrift.ld_loan_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_loan_audit_logs_performed_by
    ON loandrift.ld_loan_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_loan_audit_logs_entity
    ON loandrift.ld_loan_audit_logs (tenant_id, entity_id);

-- Loan repayments
CREATE TABLE IF NOT EXISTS loandrift.ld_repayment_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_repayment_audit_logs_scope
    ON loandrift.ld_repayment_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_repayment_audit_logs_action
    ON loandrift.ld_repayment_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_repayment_audit_logs_performed_by
    ON loandrift.ld_repayment_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_repayment_audit_logs_entity
    ON loandrift.ld_repayment_audit_logs (tenant_id, entity_id);

-- Credit score calculations
CREATE TABLE IF NOT EXISTS loandrift.ld_credit_score_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_audit_logs_scope
    ON loandrift.ld_credit_score_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_audit_logs_action
    ON loandrift.ld_credit_score_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_audit_logs_performed_by
    ON loandrift.ld_credit_score_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_audit_logs_entity
    ON loandrift.ld_credit_score_audit_logs (tenant_id, entity_id);

-- Loan penalties (applied, waived, cleared)
CREATE TABLE IF NOT EXISTS loandrift.ld_penalty_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_penalty_audit_logs_scope
    ON loandrift.ld_penalty_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_audit_logs_action
    ON loandrift.ld_penalty_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_audit_logs_performed_by
    ON loandrift.ld_penalty_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_audit_logs_entity
    ON loandrift.ld_penalty_audit_logs (tenant_id, entity_id);

-- Penalty waiver requests and their approval/rejection
CREATE TABLE IF NOT EXISTS loandrift.ld_penalty_waiver_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_penalty_waiver_audit_logs_scope
    ON loandrift.ld_penalty_waiver_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_waiver_audit_logs_action
    ON loandrift.ld_penalty_waiver_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_waiver_audit_logs_performed_by
    ON loandrift.ld_penalty_waiver_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_penalty_waiver_audit_logs_entity
    ON loandrift.ld_penalty_waiver_audit_logs (tenant_id, entity_id);

-- Savings products
CREATE TABLE IF NOT EXISTS loandrift.ld_savings_product_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_savings_product_audit_logs_scope
    ON loandrift.ld_savings_product_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_savings_product_audit_logs_action
    ON loandrift.ld_savings_product_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_savings_product_audit_logs_performed_by
    ON loandrift.ld_savings_product_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_savings_product_audit_logs_entity
    ON loandrift.ld_savings_product_audit_logs (tenant_id, entity_id);

-- Savings accounts
CREATE TABLE IF NOT EXISTS loandrift.ld_savings_account_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_savings_account_audit_logs_scope
    ON loandrift.ld_savings_account_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_savings_account_audit_logs_action
    ON loandrift.ld_savings_account_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_savings_account_audit_logs_performed_by
    ON loandrift.ld_savings_account_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_savings_account_audit_logs_entity
    ON loandrift.ld_savings_account_audit_logs (tenant_id, entity_id);

-- Savings deposits, withdrawals and interest postings
CREATE TABLE IF NOT EXISTS loandrift.ld_savings_transaction_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_savings_transaction_audit_logs_scope
    ON loandrift.ld_savings_transaction_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_savings_transaction_audit_logs_action
    ON loandrift.ld_savings_transaction_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_savings_transaction_audit_logs_performed_by
    ON loandrift.ld_savings_transaction_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_savings_transaction_audit_logs_entity
    ON loandrift.ld_savings_transaction_audit_logs (tenant_id, entity_id);

-- Investment products
CREATE TABLE IF NOT EXISTS loandrift.ld_investment_product_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_investment_product_audit_logs_scope
    ON loandrift.ld_investment_product_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_investment_product_audit_logs_action
    ON loandrift.ld_investment_product_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_investment_product_audit_logs_performed_by
    ON loandrift.ld_investment_product_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_investment_product_audit_logs_entity
    ON loandrift.ld_investment_product_audit_logs (tenant_id, entity_id);

-- Investments
CREATE TABLE IF NOT EXISTS loandrift.ld_investment_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_investment_audit_logs_scope
    ON loandrift.ld_investment_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_investment_audit_logs_action
    ON loandrift.ld_investment_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_investment_audit_logs_performed_by
    ON loandrift.ld_investment_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_investment_audit_logs_entity
    ON loandrift.ld_investment_audit_logs (tenant_id, entity_id);

-- Investment funding, payouts and terminations
CREATE TABLE IF NOT EXISTS loandrift.ld_investment_transaction_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_investment_transaction_audit_logs_scope
    ON loandrift.ld_investment_transaction_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_investment_transaction_audit_logs_action
    ON loandrift.ld_investment_transaction_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_investment_transaction_audit_logs_performed_by
    ON loandrift.ld_investment_transaction_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_investment_transaction_audit_logs_entity
    ON loandrift.ld_investment_transaction_audit_logs (tenant_id, entity_id);

-- Expenses
CREATE TABLE IF NOT EXISTS loandrift.ld_expense_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_expense_audit_logs_scope
    ON loandrift.ld_expense_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_expense_audit_logs_action
    ON loandrift.ld_expense_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_expense_audit_logs_performed_by
    ON loandrift.ld_expense_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_expense_audit_logs_entity
    ON loandrift.ld_expense_audit_logs (tenant_id, entity_id);

-- Sectors (reference data)
CREATE TABLE IF NOT EXISTS loandrift.ld_sector_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_sector_audit_logs_scope
    ON loandrift.ld_sector_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_sector_audit_logs_action
    ON loandrift.ld_sector_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_sector_audit_logs_performed_by
    ON loandrift.ld_sector_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_sector_audit_logs_entity
    ON loandrift.ld_sector_audit_logs (tenant_id, entity_id);

-- Loan types / loan products (reference data)
CREATE TABLE IF NOT EXISTS loandrift.ld_loan_type_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_loan_type_audit_logs_scope
    ON loandrift.ld_loan_type_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_loan_type_audit_logs_action
    ON loandrift.ld_loan_type_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_loan_type_audit_logs_performed_by
    ON loandrift.ld_loan_type_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_loan_type_audit_logs_entity
    ON loandrift.ld_loan_type_audit_logs (tenant_id, entity_id);

-- Interest types (reference data)
CREATE TABLE IF NOT EXISTS loandrift.ld_interest_type_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_interest_type_audit_logs_scope
    ON loandrift.ld_interest_type_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_interest_type_audit_logs_action
    ON loandrift.ld_interest_type_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_interest_type_audit_logs_performed_by
    ON loandrift.ld_interest_type_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_interest_type_audit_logs_entity
    ON loandrift.ld_interest_type_audit_logs (tenant_id, entity_id);

-- Credit score settings
CREATE TABLE IF NOT EXISTS loandrift.ld_credit_score_setting_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_setting_audit_logs_scope
    ON loandrift.ld_credit_score_setting_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_setting_audit_logs_action
    ON loandrift.ld_credit_score_setting_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_setting_audit_logs_performed_by
    ON loandrift.ld_credit_score_setting_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_ld_credit_score_setting_audit_logs_entity
    ON loandrift.ld_credit_score_setting_audit_logs (tenant_id, entity_id);
