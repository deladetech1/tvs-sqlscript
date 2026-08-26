-- 20260824-06-loandrift-accounting.sql
-- Chart of accounts and double-entry journals for LoanDrift.
--
-- Every money movement the app already records — a disbursement, a repayment
-- split into principal/interest/penalty, an expense, a savings deposit, a
-- depreciation charge — gets a balanced journal entry against the chart of
-- accounts. That is what makes a Profit & Loss, a Prudential Report and a
-- fixed-asset register possible: they are all readings of the same ledger
-- rather than four separate ad-hoc queries over the operational tables.
--
-- Scope follows the rest of LoanDrift: (tenant, org, bus, loc). The chart is
-- per location so branches can differ, and seeded on first use by the app
-- rather than here, because account codes are a tenant's own choice.
--
-- Idempotent; safe to re-run on every deploy.

-- =====================================================
-- CHART OF ACCOUNTS
-- =====================================================
-- account_type drives which statement an account lands on: INCOME and EXPENSE
-- make up the P&L, ASSET/LIABILITY/EQUITY the balance sheet. normal_balance
-- says which side increases the account, so a report can present a credit
-- balance as a positive number without every caller re-deriving the sign.
CREATE TABLE IF NOT EXISTS loandrift.ld_chart_of_accounts (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    loc_id              text        NOT NULL,

    account_code        text        NOT NULL,
    account_name        text        NOT NULL,
    account_type        text        NOT NULL,
    account_subtype     text,
    parent_account_id   text,
    normal_balance      text        NOT NULL,

    -- Seeded accounts the posting rules depend on. They can be renamed or
    -- recoded, but not deleted, or posting would fail with no account to hit.
    is_system           boolean     NOT NULL DEFAULT false,
    -- Stable handle the posting rules look accounts up by, independent of the
    -- code and name a tenant chooses (e.g. 'LOANS_RECEIVABLE').
    system_key          text,

    currency_id         text,
    description         text,
    is_active           boolean     NOT NULL DEFAULT true,
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,
    updated_by          text,
    deleted_by          text,

    CONSTRAINT ck_ld_chart_of_accounts_type
        CHECK (account_type IN ('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE')),
    CONSTRAINT ck_ld_chart_of_accounts_normal_balance
        CHECK (normal_balance IN ('DEBIT','CREDIT')),
    CONSTRAINT ck_ld_chart_of_accounts_delete_status
        CHECK (delete_status IN ('PENDING','DELETED','NOT_DELETED'))
);

-- One code per location. Partial so a deleted account's code can be reused.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_chart_of_accounts_code
    ON loandrift.ld_chart_of_accounts (tenant_id, org_id, bus_id, loc_id, account_code)
    WHERE delete_status = 'NOT_DELETED';
-- The posting rules resolve accounts by system_key, so it must be unambiguous.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_chart_of_accounts_system_key
    ON loandrift.ld_chart_of_accounts (tenant_id, org_id, bus_id, loc_id, system_key)
    WHERE system_key IS NOT NULL AND delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS idx_ld_chart_of_accounts_scope
    ON loandrift.ld_chart_of_accounts (tenant_id, org_id, bus_id, loc_id, account_type);
CREATE INDEX IF NOT EXISTS idx_ld_chart_of_accounts_parent
    ON loandrift.ld_chart_of_accounts (tenant_id, parent_account_id);

-- =====================================================
-- JOURNAL ENTRIES
-- =====================================================
-- One entry per business event, carrying its own lines. total_debit and
-- total_credit are stored rather than derived so an unbalanced entry can be
-- detected without joining, and status carries reversal: entries are never
-- edited or deleted once posted, they are reversed by a mirror entry.
CREATE TABLE IF NOT EXISTS loandrift.ld_journal_entries (
    id                    text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text        NOT NULL,
    org_id                text        NOT NULL,
    bus_id                text        NOT NULL,
    loc_id                text        NOT NULL,

    entry_number          text,
    entry_date            date        NOT NULL,
    description           text,

    -- What the entry came from, so a ledger line can be traced back to the
    -- loan or expense that caused it — and so posting is idempotent.
    source_type           text        NOT NULL DEFAULT 'MANUAL',
    source_id             text,
    loan_reference        text,

    status                text        NOT NULL DEFAULT 'POSTED',
    reversal_of_entry_id  text,
    reversed_by_entry_id  text,

    total_debit           numeric(20,6) NOT NULL DEFAULT 0,
    total_credit          numeric(20,6) NOT NULL DEFAULT 0,
    currency_id           text,

    is_active             boolean     NOT NULL DEFAULT true,
    delete_status         text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate                 text,
    ctime                 text,
    cdatetime             timestamptz DEFAULT NOW(),
    created_by            text,
    updated_by            text,
    deleted_by            text,

    CONSTRAINT ck_ld_journal_entries_status
        CHECK (status IN ('DRAFT','POSTED','REVERSED')),
    CONSTRAINT ck_ld_journal_entries_source_type
        CHECK (source_type IN ('LOAN_DISBURSEMENT','REPAYMENT','PENALTY','PENALTY_WAIVER',
                               'EXPENSE','SAVINGS_DEPOSIT','SAVINGS_WITHDRAWAL','SAVINGS_INTEREST',
                               'INVESTMENT','INVESTMENT_RETURN','DEPRECIATION','ASSET_ACQUISITION',
                               'ASSET_DISPOSAL','WRITE_OFF','MANUAL')),
    CONSTRAINT ck_ld_journal_entries_delete_status
        CHECK (delete_status IN ('PENDING','DELETED','NOT_DELETED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_journal_entries_number
    ON loandrift.ld_journal_entries (tenant_id, entry_number)
    WHERE entry_number IS NOT NULL;
-- Posting is driven by events that can fire more than once (a nightly job
-- catching up, a retried request). One entry per (source_type, source_id) makes
-- a repeat a no-op instead of a double posting.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_journal_entries_source
    ON loandrift.ld_journal_entries (tenant_id, org_id, bus_id, loc_id, source_type, source_id)
    WHERE source_id IS NOT NULL AND status <> 'REVERSED' AND delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS idx_ld_journal_entries_scope_date
    ON loandrift.ld_journal_entries (tenant_id, org_id, bus_id, loc_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_ld_journal_entries_loan_reference
    ON loandrift.ld_journal_entries (tenant_id, loan_reference);

-- =====================================================
-- JOURNAL LINES
-- =====================================================
-- Each line hits exactly one account on exactly one side. A repayment of 500
-- that is 400 principal, 80 interest and 20 penalty is one entry with a debit
-- to cash and three credits, which is what makes the P&L able to separate
-- interest income from a principal repayment that is not income at all.
CREATE TABLE IF NOT EXISTS loandrift.ld_journal_lines (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    loc_id              text        NOT NULL,

    journal_entry_id    text        NOT NULL,
    account_id          text        NOT NULL,
    line_number         integer     NOT NULL DEFAULT 1,

    debit               numeric(20,6) NOT NULL DEFAULT 0,
    credit              numeric(20,6) NOT NULL DEFAULT 0,
    description         text,

    -- Denormalised so the ledger can be filtered by client or loan without
    -- joining back through the source tables.
    client_id           text,
    loan_id             text,

    cdate               text,
    ctime               text,
    cdatetime           timestamptz DEFAULT NOW(),
    created_by          text,

    -- A line is one side or the other, never both and never neither.
    CONSTRAINT ck_ld_journal_lines_one_side
        CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)),
    CONSTRAINT ck_ld_journal_lines_non_negative
        CHECK (debit >= 0 AND credit >= 0)
);

CREATE INDEX IF NOT EXISTS idx_ld_journal_lines_entry
    ON loandrift.ld_journal_lines (tenant_id, journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_ld_journal_lines_account
    ON loandrift.ld_journal_lines (tenant_id, org_id, bus_id, loc_id, account_id);
CREATE INDEX IF NOT EXISTS idx_ld_journal_lines_loan
    ON loandrift.ld_journal_lines (tenant_id, loan_id);

-- =====================================================
-- LEDGER VIEW
-- =====================================================
-- Lines with their entry and account attached — what every accounting report
-- reads, so none of them re-derives the same three-way join.
DROP VIEW IF EXISTS loandrift.ld_general_ledger_view;
CREATE VIEW loandrift.ld_general_ledger_view AS
SELECT
    l.id                AS line_id,
    l.tenant_id, l.org_id, l.bus_id, l.loc_id,
    l.journal_entry_id,
    l.account_id,
    l.debit, l.credit,
    l.description       AS line_description,
    l.client_id, l.loan_id,
    a.account_code, a.account_name, a.account_type, a.account_subtype,
    a.normal_balance, a.system_key,
    e.entry_number, e.entry_date, e.source_type, e.source_id,
    e.loan_reference, e.status, e.currency_id,
    e.description       AS entry_description,
    e.created_by, e.cdatetime
FROM loandrift.ld_journal_lines l
JOIN loandrift.ld_journal_entries e
    ON e.id = l.journal_entry_id AND e.tenant_id = l.tenant_id
JOIN loandrift.ld_chart_of_accounts a
    ON a.id = l.account_id AND a.tenant_id = l.tenant_id
WHERE e.delete_status = 'NOT_DELETED';

-- =====================================================
-- AUDIT TRAILS
-- =====================================================
-- Same shape as the other LoanDrift audit tables (20260802-01), so they list on
-- the shared Audit Logs page without a special case.
CREATE TABLE IF NOT EXISTS loandrift.ld_account_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_account_audit_logs_scope
    ON loandrift.ld_account_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_account_audit_logs_entity
    ON loandrift.ld_account_audit_logs (tenant_id, entity_id);

CREATE TABLE IF NOT EXISTS loandrift.ld_journal_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_ld_journal_audit_logs_scope
    ON loandrift.ld_journal_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_journal_audit_logs_entity
    ON loandrift.ld_journal_audit_logs (tenant_id, entity_id);
