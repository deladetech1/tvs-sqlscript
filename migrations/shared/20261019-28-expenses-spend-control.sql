-- =====================================================================
-- Expenses, Releases 2-6: before the spend, vendors and bills, budgets,
-- statements and insight, and the suite
-- ---------------------------------------------------------------------
--   exp_requests          asking before spending: a purchase or a trip, with
--                         its estimate, approved like a claim; a trip can ask
--                         for a cash advance
--   exp_request_approvals every decision on a request
--   exp_advances          money given before a trip, paid back to the business
--                         by netting it off the claim (or returned)
--   (vendors are Core Platform's suppliers: 20261019-29)
--   exp_bills             what a vendor is owed: approved, paid through the
--                         payout gateway or by hand; can repeat
--   exp_budgets           a limit per business, department, project, category
--                         or person, per month, quarter or year; alerts at a
--                         share of it, optionally a hard stop
--   exp_budget_alerts     an alert sent, once per budget, period and level
--   exp_accounts          the business's bank, MoMo and card accounts
--   exp_statement_lines   lines of their imported statements, matched to what
--                         they paid
--   exp_claim_payouts     + payroll (paid on the next ZelosHR payslip) and the
--                         advance netted off
--   exp_expenses          + the request it fulfils, the vendor bill, and the
--                         Invoicing customer and invoice it was billed on
--   exp_claims            + the advance applied to it
--   Views for the suite, each read only when the business subscribes:
--     expenses.src_invoicing_receivables   money coming in (Invoicing)
--     expenses.src_mystoreguard_expenses   shop expenses (MyStoreGuard, kept in cp_expenses_history)
--     expenses.src_projects                projects to charge (Projects)
--     expenses.src_invoicing_customers     customers to bill (Invoicing)
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

-- ===================================================================== requests
CREATE TABLE IF NOT EXISTS expenses.exp_requests (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    number              text,
    kind                text NOT NULL CHECK (kind IN ('purchase', 'trip')),
    requester_id        text NOT NULL,
    requester_name      text NOT NULL DEFAULT '',
    title               text NOT NULL CHECK (btrim(title) <> ''),
    purpose             text NOT NULL DEFAULT '',
    category_id         text REFERENCES expenses.exp_categories (id) ON DELETE SET NULL,
    project_id          text,
    vendor_id           text,
    amount              numeric(18, 4) NOT NULL CHECK (amount >= 0),
    currency            char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    -- A trip: where and when, and the advance asked for.
    destination         text NOT NULL DEFAULT '',
    depart_on           date,
    return_on           date,
    advance_amount      numeric(18, 4) NOT NULL DEFAULT 0 CHECK (advance_amount >= 0),
    status              text NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'submitted', 'approved', 'returned', 'rejected', 'cancelled', 'closed')),
    current_step        integer,
    current_approver_id text,
    submitted_at        timestamptz,
    decided_at          timestamptz,
    closed_at           timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CHECK (return_on IS NULL OR depart_on IS NULL OR return_on >= depart_on)
);
CREATE UNIQUE INDEX IF NOT EXISTS exp_requests_number_uq ON expenses.exp_requests (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS exp_requests_bus_idx ON expenses.exp_requests (bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS exp_requests_requester_idx ON expenses.exp_requests (bus_id, requester_id);

CREATE TABLE IF NOT EXISTS expenses.exp_request_approvals (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    request_id  text NOT NULL REFERENCES expenses.exp_requests (id) ON DELETE CASCADE,
    step        integer NOT NULL,
    approver_id text NOT NULL,
    decision    text NOT NULL CHECK (decision IN ('approved', 'returned', 'rejected')),
    note        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exp_request_approvals_idx ON expenses.exp_request_approvals (request_id, cdatetime);

-- ===================================================================== advances
CREATE TABLE IF NOT EXISTS expenses.exp_advances (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    user_id          text NOT NULL,
    user_name        text NOT NULL DEFAULT '',
    request_id       text REFERENCES expenses.exp_requests (id) ON DELETE SET NULL,
    amount           numeric(18, 4) NOT NULL CHECK (amount > 0),
    currency         char(3) NOT NULL,
    -- approved: to be paid out; paid: with the employee, to be netted off claims;
    -- settled: netted (and any rest returned); cancelled.
    status           text NOT NULL DEFAULT 'approved' CHECK (status IN ('approved', 'paid', 'settled', 'cancelled')),
    netted           numeric(18, 4) NOT NULL DEFAULT 0,
    returned         numeric(18, 4) NOT NULL DEFAULT 0,
    payout_method    text CHECK (payout_method IS NULL OR payout_method IN ('gateway', 'manual')),
    payout_status    text,
    app_reference    text UNIQUE,
    recipient        jsonb NOT NULL DEFAULT '{}',
    manual_reference text NOT NULL DEFAULT '',
    failure_reason   text NOT NULL DEFAULT '',
    paid_at          timestamptz,
    settled_at       timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exp_advances_user_idx ON expenses.exp_advances (bus_id, user_id, status);

ALTER TABLE expenses.exp_claims ADD COLUMN IF NOT EXISTS advance_applied numeric(18, 4) NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS expenses.exp_claim_advances (
    claim_id   text NOT NULL REFERENCES expenses.exp_claims (id) ON DELETE CASCADE,
    advance_id text NOT NULL REFERENCES expenses.exp_advances (id) ON DELETE RESTRICT,
    amount     numeric(18, 4) NOT NULL CHECK (amount > 0),
    PRIMARY KEY (claim_id, advance_id)
);

-- ===================================================================== vendors and bills
CREATE TABLE IF NOT EXISTS expenses.exp_bills (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    -- A supplier in core_platform.cp_parties (20261019-29 adds the key).
    vendor_id        text NOT NULL,
    number           text NOT NULL DEFAULT '',
    description      text NOT NULL DEFAULT '',
    category_id      text REFERENCES expenses.exp_categories (id) ON DELETE SET NULL,
    project_id       text,
    issued_on        date NOT NULL DEFAULT CURRENT_DATE,
    due_on           date NOT NULL DEFAULT CURRENT_DATE,
    amount           numeric(18, 4) NOT NULL CHECK (amount > 0),
    tax_amount       numeric(18, 4) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    currency         char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    receipt_id       text REFERENCES expenses.exp_receipts (id) ON DELETE SET NULL,
    -- How it repeats; the next one is made when this one is due.
    repeat           text NOT NULL DEFAULT 'none' CHECK (repeat IN ('none', 'monthly', 'quarterly', 'yearly')),
    repeated_into    text,
    status           text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'approved', 'paid', 'cancelled')),
    approved_by      text,
    approved_at      timestamptz,
    paid_total       numeric(18, 4) NOT NULL DEFAULT 0,
    paid_at          timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE INDEX IF NOT EXISTS exp_bills_bus_idx ON expenses.exp_bills (bus_id, status, due_on);

CREATE TABLE IF NOT EXISTS expenses.exp_bill_payouts (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    bill_id          text NOT NULL REFERENCES expenses.exp_bills (id) ON DELETE RESTRICT,
    amount           numeric(18, 4) NOT NULL CHECK (amount > 0),
    currency         char(3) NOT NULL,
    method           text NOT NULL CHECK (method IN ('gateway', 'manual')),
    status           text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'success', 'failed', 'reversed', 'manual')),
    app_reference    text NOT NULL UNIQUE,
    recipient        jsonb NOT NULL DEFAULT '{}',
    manual_reference text NOT NULL DEFAULT '',
    failure_reason   text NOT NULL DEFAULT '',
    paid_by          text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    completed_at     timestamptz
);
CREATE INDEX IF NOT EXISTS exp_bill_payouts_bill_idx ON expenses.exp_bill_payouts (bill_id);

-- ===================================================================== budgets
CREATE TABLE IF NOT EXISTS expenses.exp_budgets (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    scope       text NOT NULL CHECK (scope IN ('business', 'department', 'project', 'category', 'person')),
    scope_id    text NOT NULL DEFAULT '',
    scope_label text NOT NULL DEFAULT '',
    period      text NOT NULL DEFAULT 'month' CHECK (period IN ('month', 'quarter', 'year')),
    amount      numeric(18, 4) NOT NULL CHECK (amount > 0),
    currency    char(3) NOT NULL,
    -- What is left of a period carries into the next.
    rollover    boolean NOT NULL DEFAULT false,
    alert_at    integer NOT NULL DEFAULT 80 CHECK (alert_at BETWEEN 1 AND 100),
    -- Spending past it is refused, not only warned.
    hard_stop   boolean NOT NULL DEFAULT false,
    starts_on   date NOT NULL DEFAULT date_trunc('month', CURRENT_DATE)::date,
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    CHECK ((scope = 'business') = (scope_id = ''))
);
CREATE INDEX IF NOT EXISTS exp_budgets_bus_idx ON expenses.exp_budgets (bus_id) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS expenses.exp_budget_alerts (
    budget_id    text NOT NULL REFERENCES expenses.exp_budgets (id) ON DELETE CASCADE,
    period_start date NOT NULL,
    level        integer NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (budget_id, period_start, level)
);

-- ===================================================================== statements
CREATE TABLE IF NOT EXISTS expenses.exp_accounts (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    kind        text NOT NULL DEFAULT 'bank' CHECK (kind IN ('bank', 'mobile_money', 'card', 'cash')),
    currency    char(3) NOT NULL,
    -- The columns of this account's statement, learnt from its first import.
    mapping     jsonb NOT NULL DEFAULT '{}',
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);

CREATE TABLE IF NOT EXISTS expenses.exp_statement_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    account_id   text NOT NULL REFERENCES expenses.exp_accounts (id) ON DELETE CASCADE,
    posted_on    date NOT NULL,
    description  text NOT NULL DEFAULT '',
    reference    text NOT NULL DEFAULT '',
    -- Money out is negative, in is positive.
    amount       numeric(18, 4) NOT NULL,
    balance      numeric(18, 4),
    -- One line once, however often the file is imported.
    fingerprint  text NOT NULL,
    status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'matched', 'ignored')),
    matched_kind text CHECK (matched_kind IS NULL OR matched_kind IN ('expense', 'claim_payout', 'bill_payout', 'advance')),
    matched_id   text,
    import_id    text NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS exp_statement_lines_fp_uq ON expenses.exp_statement_lines (account_id, fingerprint);
CREATE INDEX IF NOT EXISTS exp_statement_lines_open_idx ON expenses.exp_statement_lines (bus_id, status, posted_on DESC);

-- ===================================================================== links
ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS request_id text REFERENCES expenses.exp_requests (id) ON DELETE SET NULL;
ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS billable_customer_id text;
ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS invoice_id text;
ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS invoiced_at timestamptz;
ALTER TABLE expenses.exp_expenses ADD COLUMN IF NOT EXISTS project_id text;
CREATE INDEX IF NOT EXISTS exp_expenses_billable_idx ON expenses.exp_expenses (bus_id, billable_customer_id) WHERE billable AND invoice_id IS NULL;

-- Paying back on the next payslip: the ZelosHR one-off it became.
ALTER TABLE expenses.exp_claim_payouts DROP CONSTRAINT IF EXISTS exp_claim_payouts_method_check;
ALTER TABLE expenses.exp_claim_payouts ADD CONSTRAINT exp_claim_payouts_method_check CHECK (method IN ('gateway', 'manual', 'payroll', 'advance'));
ALTER TABLE expenses.exp_claim_payouts ADD COLUMN IF NOT EXISTS payroll_one_off_id text;


-- ===================================================================== what is spent
-- Every amount against the business's budgets, in one place: claimed expenses (spent once the
-- claim is approved, committed while it is being decided), vendor bills (committed while open,
-- spent once approved), and approved requests (committed, less what has been claimed against
-- them). Expenses are in the claim's currency (the business's); bills and requests in their own.
CREATE OR REPLACE VIEW expenses.exp_spend_lines AS
SELECT e.tenant_id, e.bus_id, 'expense'::text AS source, e.id, e.spent_on AS on_date, e.amount_base AS amount, c.currency::text AS currency,
       e.category_id, e.user_id, coalesce(e.project_id, c.project_id) AS project_id,
       CASE WHEN c.status IN ('approved', 'paid') THEN 'spent' ELSE 'committed' END AS stage
  FROM expenses.exp_expenses e
  JOIN expenses.exp_claims c ON c.id = e.claim_id
 WHERE c.status IN ('submitted', 'approved', 'paid')
UNION ALL
SELECT b.tenant_id, b.bus_id, 'bill', b.id, b.issued_on, b.amount, b.currency::text, b.category_id, coalesce(b.created_by, ''), b.project_id,
       CASE WHEN b.status IN ('approved', 'paid') THEN 'spent' ELSE 'committed' END
  FROM expenses.exp_bills b
 WHERE b.status IN ('open', 'approved', 'paid')
UNION ALL
SELECT r.tenant_id, r.bus_id, 'request', r.id, coalesce(r.depart_on, r.decided_at::date, r.cdatetime::date),
       greatest(r.amount - coalesce((SELECT sum(x.amount_base) FROM expenses.exp_expenses x JOIN expenses.exp_claims xc ON xc.id = x.claim_id
                                      WHERE x.request_id = r.id AND xc.status IN ('submitted', 'approved', 'paid')), 0), 0),
       r.currency::text, r.category_id, r.requester_id, r.project_id, 'committed'
  FROM expenses.exp_requests r
 WHERE r.status = 'approved';

-- ===================================================================== the suite's views
DO $$
BEGIN
    IF to_regclass('invoicing.inv_invoices') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW expenses.src_invoicing_receivables AS
        SELECT i.tenant_id, i.bus_id, i.id, coalesce(i.number, '') AS number, i.currency, i.balance, i.due_date,
               coalesce(i.customer_snapshot->>'name', '') AS customer_name
          FROM invoicing.inv_invoices i
         WHERE i.kind = 'invoice' AND i.status = 'open' AND i.balance > 0
        $v$;
        EXECUTE $v$
        CREATE OR REPLACE VIEW expenses.src_invoicing_customers AS
        SELECT c.tenant_id, c.bus_id, c.id, c.name, coalesce(c.email, '') AS email, coalesce(c.currency, '') AS currency
          FROM invoicing.inv_customers c
         WHERE c.archived_at IS NULL AND c.role IN ('customer', 'both')
        $v$;
    END IF;
    -- MyStoreGuard's shop expenses are kept in Core Platform's expense history.
    IF to_regclass('core_platform.cp_expenses_history') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW expenses.src_mystoreguard_expenses AS
        SELECT e.tenant_id, e.bus_id, e.id, e.cdatetime::date AS spent_on, e.amount, coalesce(e.description, '') AS description,
               coalesce((SELECT upper(btrim(cu.code)) FROM core_platform.cp_currencies cu WHERE cu.id = e.currency_id), '') AS currency
          FROM core_platform.cp_expenses_history e
         WHERE coalesce(e.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND coalesce(e.is_active, true)
           AND (e.app ILIKE '%mystoreguard%' OR e.source ILIKE '%mystoreguard%')
        $v$;
    END IF;
    IF to_regclass('projects.prj_projects') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW expenses.src_projects AS
        SELECT p.tenant_id, p.bus_id, p.id, p.name, coalesce(p.key, '') AS key
          FROM projects.prj_projects p
         WHERE p.status = 'active' AND coalesce(p.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND NOT coalesce(p.is_template, false)
        $v$;
    END IF;
END $$;

-- An Invoicing line can bill expenses from Expenses (source_kind 'expenses_app'). The constraint
-- keeps 20261019-13's name, so that file (which adds it only when missing) leaves this one be.
DO $$
BEGIN
    IF to_regclass('invoicing.inv_invoice_lines') IS NOT NULL THEN
        ALTER TABLE invoicing.inv_invoice_lines DROP CONSTRAINT IF EXISTS inv_invoice_lines_source_check;
        ALTER TABLE invoicing.inv_invoice_lines ADD CONSTRAINT inv_invoice_lines_source_check
            CHECK (source_kind IS NULL OR source_kind IN ('time', 'expense', 'expenses_app'));
    END IF;
END $$;

COMMIT;
