-- MyEduGuard: accounting and financial management -- each school's own double-entry books.
--
--   sms_gl_settings        a school's books: when they start, the fiscal year, the date before which
--                          nothing may be posted (period lock), numbering, and the approval rule
--   sms_gl_accounts        the chart of accounts (a school's own; a starter chart is made on setup):
--                          assets, liabilities, equity, income and expenses, in groups; cash, bank,
--                          mobile money and petty cash accounts are the school's banking
--   sms_gl_mappings        where fees and the rest post, when a school points a role at another
--                          account than its standard code
--   sms_gl_journals        journals: manual, from fees (posted by themselves), expenses, petty cash,
--   sms_gl_lines           transfers, payroll, assets and depreciation, opening balances. A posted
--                          journal never changes: it is reversed by another. Each balances to the cent.
--   sms_gl_fee_state       what each fee document (invoice, payment, credit, refund) last posted, so
--                          a change posts only its difference
--   sms_gl_expenses        expenses and petty cash vouchers, through the approval chain, then paid
--   sms_gl_expense_approvals
--   sms_gl_approval_steps  the approval chain: each step a role, and how much it may approve
--   sms_gl_bank_statements imported bank statements, and their lines matched to the books
--   sms_gl_bank_lines
--   sms_gl_budgets         budgets per year and department, by account and month
--   sms_gl_budget_lines
--   sms_gl_assets          the fixed assets register, depreciation by month, and disposals
--   sms_gl_depreciation
--   sms_fin_audit          every financial change, insert-only and hash-chained per school
--
-- Books are per school (a campus); a business's schools add up in the group (consolidated) reports.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_gl_settings (
    profile_id          text PRIMARY KEY REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    started_on          date NOT NULL,
    fiscal_year_start   integer NOT NULL DEFAULT 1,
    lock_before         date,
    journal_prefix      text NOT NULL DEFAULT 'JV',
    next_journal        integer NOT NULL DEFAULT 1,
    expense_prefix      text NOT NULL DEFAULT 'EXP',
    next_expense        integer NOT NULL DEFAULT 1,
    voucher_prefix      text NOT NULL DEFAULT 'PCV',
    next_voucher        integer NOT NULL DEFAULT 1,
    asset_prefix        text NOT NULL DEFAULT 'FA',
    next_asset          integer NOT NULL DEFAULT 1,
    post_fees           boolean NOT NULL DEFAULT true,
    approve_own         boolean NOT NULL DEFAULT false,
    updated_at          timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_gl_settings', 'sms_gl_settings_check', $q$fiscal_year_start$q$, $q$CHECK (fiscal_year_start BETWEEN 1 AND 12)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_gl_accounts (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id      text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    code            text NOT NULL,
    name            text NOT NULL,
    type            text NOT NULL,
    subtype         text,
    parent_id       text REFERENCES sms.sms_gl_accounts(id) ON DELETE SET NULL,
    is_group        boolean NOT NULL DEFAULT false,
    active          boolean NOT NULL DEFAULT true,
    system          boolean NOT NULL DEFAULT false,
    description     text,
    bank_name       text,
    account_number  text,
    float_amount    numeric(14,2),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, code)
);
SELECT sms.widen_check('sms.sms_gl_accounts', 'sms_gl_accounts_check', $q$'accumulated_depreciation'$q$, $q$CHECK (
    type IN ('asset', 'liability', 'equity', 'income', 'expense')
    AND (subtype IS NULL OR subtype IN ('cash', 'bank', 'mobile_money', 'petty_cash', 'receivable', 'payable', 'tax', 'fixed_asset',
        'accumulated_depreciation', 'deposit_liability', 'retained')))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_gl_mappings (
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    role        text NOT NULL,
    account_id  text NOT NULL REFERENCES sms.sms_gl_accounts(id) ON DELETE CASCADE,
    PRIMARY KEY (profile_id, role)
);

CREATE TABLE IF NOT EXISTS sms.sms_gl_journals (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number        text NOT NULL,
    entry_date    date NOT NULL,
    memo          text NOT NULL,
    source        text NOT NULL DEFAULT 'manual',
    source_id     text,
    reference     text,
    status        text NOT NULL DEFAULT 'posted',
    reversal_of   text REFERENCES sms.sms_gl_journals(id),
    reversed_by   text REFERENCES sms.sms_gl_journals(id),
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_gl_journals', 'sms_gl_journals_check', $q$'opening'$q$, $q$CHECK (
    source IN ('manual', 'fees', 'expense', 'petty_cash', 'transfer', 'payroll', 'asset', 'depreciation', 'disposal', 'bank', 'opening', 'reversal')
    AND status IN ('posted', 'reversed'))$q$);
CREATE INDEX IF NOT EXISTS sms_gl_journals_date_idx ON sms.sms_gl_journals (profile_id, entry_date);
CREATE INDEX IF NOT EXISTS sms_gl_journals_source_idx ON sms.sms_gl_journals (source, source_id);

CREATE TABLE IF NOT EXISTS sms.sms_gl_lines (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    journal_id     text NOT NULL REFERENCES sms.sms_gl_journals(id) ON DELETE CASCADE,
    profile_id     text NOT NULL,
    account_id     text NOT NULL REFERENCES sms.sms_gl_accounts(id),
    debit          numeric(14,2) NOT NULL DEFAULT 0,
    credit         numeric(14,2) NOT NULL DEFAULT 0,
    department_id  text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    description    text,
    doc_key        text,
    bank_line_id   text,
    seq            integer NOT NULL DEFAULT 0
);
SELECT sms.widen_check('sms.sms_gl_lines', 'sms_gl_lines_check', $q$debit >= 0$q$, $q$CHECK (debit >= 0 AND credit >= 0 AND (debit = 0 OR credit = 0) AND debit + credit > 0)$q$);
CREATE INDEX IF NOT EXISTS sms_gl_lines_account_idx ON sms.sms_gl_lines (account_id);
CREATE INDEX IF NOT EXISTS sms_gl_lines_journal_idx ON sms.sms_gl_lines (journal_id);
CREATE INDEX IF NOT EXISTS sms_gl_lines_doc_idx ON sms.sms_gl_lines (profile_id, doc_key) WHERE doc_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS sms.sms_gl_fee_state (
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    doc_key      text NOT NULL,
    fingerprint  text NOT NULL,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (profile_id, doc_key)
);

-- A journal balances (checked at commit, once all its lines are in), and a posted one never
-- changes: only its status (reversed), and a line's bank match, may. A school's whole books go
-- only with the module's purge (sms.purge = on) or the school itself.
CREATE OR REPLACE FUNCTION sms.sms_gl_balanced() RETURNS trigger LANGUAGE plpgsql AS $f$
DECLARE d numeric; c numeric; j text;
BEGIN
    j := coalesce(NEW.journal_id, OLD.journal_id);
    IF NOT EXISTS (SELECT 1 FROM sms.sms_gl_journals WHERE id = j) THEN
        RETURN NULL;
    END IF;
    SELECT coalesce(sum(debit), 0), coalesce(sum(credit), 0) INTO d, c FROM sms.sms_gl_lines WHERE journal_id = j;
    IF d <> c THEN
        RAISE EXCEPTION 'The journal does not balance: debits %, credits %', d, c USING ERRCODE = 'check_violation';
    END IF;
    IF d = 0 THEN
        RAISE EXCEPTION 'A journal needs at least one debit and one credit' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NULL;
END $f$;
DROP TRIGGER IF EXISTS sms_gl_lines_balanced ON sms.sms_gl_lines;
CREATE CONSTRAINT TRIGGER sms_gl_lines_balanced AFTER INSERT OR UPDATE OR DELETE ON sms.sms_gl_lines
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION sms.sms_gl_balanced();

CREATE OR REPLACE FUNCTION sms.sms_gl_immutable() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
    IF coalesce(current_setting('sms.purge', true), '') = 'on' OR pg_trigger_depth() > 1 THEN
        RETURN coalesce(NEW, OLD);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Posted entries are never deleted: reverse the journal' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_TABLE_NAME = 'sms_gl_journals' THEN
        IF (NEW.number, NEW.entry_date, NEW.memo, NEW.source, NEW.profile_id) IS DISTINCT FROM (OLD.number, OLD.entry_date, OLD.memo, OLD.source, OLD.profile_id) THEN
            RAISE EXCEPTION 'A posted journal never changes: reverse it' USING ERRCODE = 'check_violation';
        END IF;
    ELSIF (NEW.account_id, NEW.debit, NEW.credit, NEW.journal_id, NEW.department_id) IS DISTINCT FROM (OLD.account_id, OLD.debit, OLD.credit, OLD.journal_id, OLD.department_id) THEN
        RAISE EXCEPTION 'A posted line never changes: reverse the journal' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS sms_gl_journals_immutable ON sms.sms_gl_journals;
CREATE TRIGGER sms_gl_journals_immutable BEFORE UPDATE OR DELETE ON sms.sms_gl_journals FOR EACH ROW EXECUTE FUNCTION sms.sms_gl_immutable();
DROP TRIGGER IF EXISTS sms_gl_lines_immutable ON sms.sms_gl_lines;
CREATE TRIGGER sms_gl_lines_immutable BEFORE UPDATE OR DELETE ON sms.sms_gl_lines FOR EACH ROW EXECUTE FUNCTION sms.sms_gl_immutable();

-- =================================================================== expenses, petty cash, approvals
CREATE TABLE IF NOT EXISTS sms.sms_gl_approval_steps (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    seq         integer NOT NULL,
    label       text NOT NULL,
    role_id     text NOT NULL,
    up_to       numeric(14,2),
    UNIQUE (profile_id, seq)
);

CREATE TABLE IF NOT EXISTS sms.sms_gl_expenses (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id       text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number           text NOT NULL,
    kind             text NOT NULL DEFAULT 'expense',
    spent_on         date NOT NULL,
    payee            text NOT NULL,
    description      text NOT NULL,
    account_id       text NOT NULL REFERENCES sms.sms_gl_accounts(id),
    amount           numeric(14,2) NOT NULL,
    department_id    text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    paid_from_id     text REFERENCES sms.sms_gl_accounts(id),
    reference        text,
    status           text NOT NULL DEFAULT 'pending',
    step             integer NOT NULL DEFAULT 1,
    steps_needed     integer NOT NULL DEFAULT 1,
    requested_by     text,
    paid_by          text,
    paid_on          date,
    journal_id       text REFERENCES sms.sms_gl_journals(id),
    note             text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_gl_expenses', 'sms_gl_expenses_check', $q$'petty'$q$, $q$CHECK (
    kind IN ('expense', 'petty') AND status IN ('pending', 'approved', 'rejected', 'paid', 'void') AND amount > 0)$q$);
CREATE INDEX IF NOT EXISTS sms_gl_expenses_status_idx ON sms.sms_gl_expenses (profile_id, status, spent_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_gl_expense_approvals (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    expense_id  text NOT NULL REFERENCES sms.sms_gl_expenses(id) ON DELETE CASCADE,
    step        integer NOT NULL,
    user_id     text NOT NULL,
    decision    text NOT NULL,
    note        text,
    at          timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_gl_expense_approvals', 'sms_gl_expense_approvals_check', $q$'rejected'$q$, $q$CHECK (decision IN ('approved', 'rejected'))$q$);

-- =================================================================== bank reconciliation
CREATE TABLE IF NOT EXISTS sms.sms_gl_bank_statements (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id   text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    account_id   text NOT NULL REFERENCES sms.sms_gl_accounts(id) ON DELETE CASCADE,
    name         text NOT NULL,
    period_from  date,
    period_to    date,
    closing      numeric(14,2),
    imported_by  text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_gl_bank_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    statement_id  text NOT NULL REFERENCES sms.sms_gl_bank_statements(id) ON DELETE CASCADE,
    profile_id    text NOT NULL,
    account_id    text NOT NULL,
    on_date       date NOT NULL,
    description   text NOT NULL,
    reference     text,
    amount        numeric(14,2) NOT NULL,
    status        text NOT NULL DEFAULT 'unmatched',
    gl_line_id    text,
    seq           integer NOT NULL DEFAULT 0
);
SELECT sms.widen_check('sms.sms_gl_bank_lines', 'sms_gl_bank_lines_check', $q$'excluded'$q$, $q$CHECK (status IN ('unmatched', 'matched', 'excluded') AND amount <> 0)$q$);
CREATE INDEX IF NOT EXISTS sms_gl_bank_lines_account_idx ON sms.sms_gl_bank_lines (account_id, status, on_date);

-- =================================================================== budgets
CREATE TABLE IF NOT EXISTS sms.sms_gl_budgets (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id     text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name           text NOT NULL,
    fiscal_year    integer NOT NULL,
    department_id  text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    status         text NOT NULL DEFAULT 'draft',
    approved_by    text,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_gl_budgets', 'sms_gl_budgets_check', $q$'approved'$q$, $q$CHECK (status IN ('draft', 'approved'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_gl_budgets_uq ON sms.sms_gl_budgets (profile_id, fiscal_year, coalesce(department_id, ''), lower(name));

CREATE TABLE IF NOT EXISTS sms.sms_gl_budget_lines (
    budget_id   text NOT NULL REFERENCES sms.sms_gl_budgets(id) ON DELETE CASCADE,
    account_id  text NOT NULL REFERENCES sms.sms_gl_accounts(id) ON DELETE CASCADE,
    months      numeric(14,2)[] NOT NULL,
    PRIMARY KEY (budget_id, account_id)
);
SELECT sms.widen_check('sms.sms_gl_budget_lines', 'sms_gl_budget_lines_check', $q$cardinality(months) = 12$q$, $q$CHECK (cardinality(months) = 12)$q$);

-- =================================================================== fixed assets
CREATE TABLE IF NOT EXISTS sms.sms_gl_assets (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    profile_id           text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    number               text NOT NULL,
    name                 text NOT NULL,
    category             text,
    serial               text,
    location             text,
    department_id        text REFERENCES sms.sms_departments(id) ON DELETE SET NULL,
    asset_account_id     text NOT NULL REFERENCES sms.sms_gl_accounts(id),
    acquired_on          date NOT NULL,
    cost                 numeric(14,2) NOT NULL,
    residual             numeric(14,2) NOT NULL DEFAULT 0,
    life_months          integer NOT NULL,
    method               text NOT NULL DEFAULT 'straight_line',
    rate_pct             numeric(6,2),
    status               text NOT NULL DEFAULT 'active',
    disposed_on          date,
    proceeds             numeric(14,2),
    disposal_note        text,
    purchase_journal_id  text REFERENCES sms.sms_gl_journals(id),
    disposal_journal_id  text REFERENCES sms.sms_gl_journals(id),
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, number)
);
SELECT sms.widen_check('sms.sms_gl_assets', 'sms_gl_assets_check', $q$'reducing_balance'$q$, $q$CHECK (
    method IN ('straight_line', 'reducing_balance') AND status IN ('active', 'disposed') AND cost > 0 AND residual >= 0 AND residual < cost AND life_months > 0)$q$);

CREATE TABLE IF NOT EXISTS sms.sms_gl_depreciation (
    asset_id    text NOT NULL REFERENCES sms.sms_gl_assets(id) ON DELETE CASCADE,
    period      date NOT NULL,
    amount      numeric(14,2) NOT NULL,
    journal_id  text NOT NULL REFERENCES sms.sms_gl_journals(id),
    PRIMARY KEY (asset_id, period)
);

-- =================================================================== the audit trail
-- Every financial change, as it happened: never updated or deleted, and each row hashed with the
-- one before it (per school), so a gap or an edit shows when the chain is checked.
CREATE TABLE IF NOT EXISTS sms.sms_fin_audit (
    id          bigserial PRIMARY KEY,
    profile_id  text NOT NULL,
    at          timestamptz NOT NULL DEFAULT clock_timestamp(),
    actor_id    text,
    entity      text NOT NULL,
    entity_id   text NOT NULL,
    action      text NOT NULL,
    data        jsonb NOT NULL DEFAULT '{}',
    prev_hash   text NOT NULL DEFAULT '',
    hash        text NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS sms_fin_audit_profile_idx ON sms.sms_fin_audit (profile_id, id DESC);
CREATE INDEX IF NOT EXISTS sms_fin_audit_entity_idx ON sms.sms_fin_audit (entity, entity_id);

CREATE OR REPLACE FUNCTION sms.sms_fin_audit_chain() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        IF coalesce(current_setting('sms.purge', true), '') = 'on' THEN
            RETURN coalesce(NEW, OLD);
        END IF;
        RAISE EXCEPTION 'The financial audit trail is never changed' USING ERRCODE = 'check_violation';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext('sms_fin_audit:' || NEW.profile_id));
    NEW.prev_hash := coalesce((SELECT hash FROM sms.sms_fin_audit WHERE profile_id = NEW.profile_id ORDER BY id DESC LIMIT 1), '');
    NEW.hash := encode(sha256(convert_to(NEW.prev_hash || '|' || NEW.profile_id || '|' || to_char(NEW.at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || '|' ||
        coalesce(NEW.actor_id, '') || '|' || NEW.entity || '|' || NEW.entity_id || '|' || NEW.action || '|' || NEW.data::text, 'UTF8')), 'hex');
    RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS sms_fin_audit_chain ON sms.sms_fin_audit;
CREATE TRIGGER sms_fin_audit_chain BEFORE INSERT OR UPDATE OR DELETE ON sms.sms_fin_audit FOR EACH ROW EXECUTE FUNCTION sms.sms_fin_audit_chain();

-- Receipts on expenses and vouchers; an asset's invoice or photo.
SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'gl_expense'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset'))$q$);

-- Finance is a module a school can turn off (Settings, Modules).
SELECT sms.widen_check('sms.sms_profiles', 'sms_profiles_modules_check', $q$'finance'$q$, $q$CHECK (modules IS NULL OR (cardinality(modules) > 0 AND modules <@ ARRAY[
    'admissions', 'teaching', 'scheduling', 'attendance', 'grading', 'learning', 'welfare', 'inclusion', 'boarding', 'library', 'activities', 'transport',
    'catering', 'hr', 'fees', 'finance']::text[]))$q$);

-- =================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-sms-finance', 'MyEduGuard Finance', 'The school''s books: accounts, journals, statements, expenses, petty cash, banking, budgets and fixed assets', 'rt-subscribed-app-sms')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('finance', 'get',      'View the books: accounts, journals, financial statements, budgets, assets and finance reports'),
    ('finance', 'transact', 'Record expenses and petty cash vouchers, and pay approved expenses'),
    ('finance', 'approve',  'Approve or reject expenses, within the approval chain'),
    ('finance', 'manage',   'Keep the chart of accounts and the books: journals, banking and reconciliation, budgets, fixed assets and the finance settings')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-sms-' || spec.resource_key || '-' || spec.action,
       'MyEduGuard ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       'rt-sms-finance', spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'sms',
       resource_key = substring(p.id FROM '^permission-sms-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-sms-%'
   AND (p.app_prefix IS DISTINCT FROM 'sms' OR p.action IS NULL);

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-sms-accountant', 'system-tenant-id', 'MyEduGuard Accountant', 'Keeps the school''s books: the chart of accounts, journals, statements, banking and reconciliation, budgets, fixed assets and expenses', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name        = EXCLUDED.role_name,
                               description      = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id,
                               is_system        = EXCLUDED.is_system,
                               is_active        = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT 'role-sms-head' AS role_id, p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2 WHERE p2.app_prefix = 'sms'
    UNION ALL
    SELECT 'role-sms-accountant', k, a FROM (VALUES ('finance', 'get'), ('finance', 'transact'), ('finance', 'approve'), ('finance', 'manage'), ('fees', 'get'),
        ('students', 'get'), ('families', 'get'), ('structure', 'get'), ('profiles', 'get')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-bursar', k, a FROM (VALUES ('finance', 'get'), ('finance', 'transact')) AS g(k, a)
    UNION ALL
    SELECT 'role-sms-accounts', k, a FROM (VALUES ('finance', 'transact')) AS g(k, a)
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'sms' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', 'role-sms-accountant', p.id
  FROM core_platform.cp_permissions p
 WHERE p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations', 'permission-user-get-locations')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- =================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.ledger',            'app-sms', 'Double Entry Accounting',        2, 'Chart of accounts, journals and auto posting from billing and payroll'),
('sms.fin-statements',    'app-sms', 'Financial Statements',           2, 'Trial balance, income statement, balance sheet and cash flow'),
('sms.expenses',          'app-sms', 'Expenses & Petty Cash',          1, 'Expense recording, petty cash and banking'),
('sms.bank-rec',          'app-sms', 'Bank Reconciliation',            2, 'Import bank statements and reconcile'),
('sms.budgets',           'app-sms', 'Budgeting',                      2, 'Budgets per department with budget versus actual reports'),
('sms.expense-approvals', 'app-sms', 'Expense Approval Workflow',      2, 'Approval chains and spending limits by role'),
('sms.fixed-assets',      'app-sms', 'Fixed Assets Register',          3, 'Depreciation computation and disposal recording'),
('sms.finance-reports',   'app-sms', 'Finance Reports',                1, 'Payment history, class ledger, tellers, debtors list and expected revenue'),
('sms.multi-entity',      'app-sms', 'Multi Entity & Consolidation',   3, 'Separate books per campus with group consolidation'),
('sms.acc-integration',   'app-sms', 'Accounting Software Integration', 3, 'Export or sync to QuickBooks, Xero, Sage or Tally'),
('sms.fin-audit',         'app-sms', 'Financial Audit Trail',          2, 'Immutable log of every financial change')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

-- =================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'sms' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-sms-head' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-sms-head lacks % SMS permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-sms-accountant' AND p.app_prefix = 'sms' AND p.resource_key IN ('counselling', 'safeguarding', 'hr')) THEN
        RAISE EXCEPTION 'counselling, safeguarding and staff records are not the accountant''s';
    END IF;
    -- The books are confidential: the read-only viewer does not see them.
    DELETE FROM core_platform.cp_role_permissions rp USING core_platform.cp_permissions p
     WHERE p.id = rp.permission_id AND rp.role_id = 'role-sms-viewer' AND p.app_prefix = 'sms' AND p.resource_key = 'finance';
END $$;

COMMIT;
