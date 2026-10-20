-- =====================================================================
-- Expenses, Release 1: claims, receipts, approvals and paying back
-- ---------------------------------------------------------------------
--   exp_settings          per business: its currency (else Core Platform's
--                         default), claim numbering, how approval goes, the
--                         receipt threshold, reminders
--   exp_categories        what money is spent on; each can carry a central tax
--                         (core_platform.cp_tax_rates) for the reclaimable-tax report
--   exp_mileage_rates     per distance, from a date
--   exp_per_diem_rates    per day, by country and city, from a date
--   exp_policies          rules checked on every expense: a limit per item, day or
--                         month, receipts over an amount, no weekends, a purpose,
--                         a maximum age -- each a warning or a block
--   exp_approval_steps    who approves, in order: the claimant's manager or
--                         department head (from ZelosHR), a named person, or
--                         finance; a step can start from an amount
--   exp_claims            a claim: one person's expenses sent together, numbered
--                         when submitted, approved step by step, paid back
--   exp_expenses          one expense: a receipt, a mileage trip or a per diem;
--                         in its own currency and the claim's; its policy and
--                         audit flags
--   exp_receipts          the file (private blob), its fingerprint (duplicates
--                         are flagged) and what was read from it
--   exp_approvals         every decision on a claim: approved, sent back, rejected
--   exp_claim_payouts     paying a claim back: through the business's payout
--                         gateway (core_platform.cp_payouts), or by hand
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS expenses.exp_settings (
    tenant_id             text NOT NULL,
    org_id                text,
    bus_id                text PRIMARY KEY,
    base_currency         char(3) CHECK (base_currency IS NULL OR base_currency ~ '^[A-Z]{3}$'),
    claim_prefix          text NOT NULL DEFAULT 'EXP-',
    next_number           integer NOT NULL DEFAULT 1 CHECK (next_number > 0),
    -- Expenses with no step set: the claimant's manager approves, finance pays.
    receipt_required_over numeric(18, 4) NOT NULL DEFAULT 0 CHECK (receipt_required_over >= 0),
    auto_approve_under    numeric(18, 4) CHECK (auto_approve_under IS NULL OR auto_approve_under >= 0),
    distance_unit         text NOT NULL DEFAULT 'km' CHECK (distance_unit IN ('km', 'mi')),
    reminder_days         integer NOT NULL DEFAULT 2 CHECK (reminder_days BETWEEN 0 AND 30),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text
);

CREATE TABLE IF NOT EXISTS expenses.exp_categories (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    name             text NOT NULL CHECK (btrim(name) <> ''),
    -- The accountant's code, carried into exports.
    code             text NOT NULL DEFAULT '',
    kind             text NOT NULL DEFAULT 'expense' CHECK (kind IN ('expense', 'mileage', 'per_diem')),
    description      text NOT NULL DEFAULT '',
    icon             text NOT NULL DEFAULT '',
    limit_amount     numeric(18, 4) CHECK (limit_amount IS NULL OR limit_amount > 0),
    receipt_required boolean NOT NULL DEFAULT true,
    tax_rate_id      text REFERENCES core_platform.cp_tax_rates (id) ON DELETE SET NULL,
    position         integer NOT NULL DEFAULT 0,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS exp_categories_name_uq ON expenses.exp_categories (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS expenses.exp_mileage_rates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL DEFAULT 'Car',
    rate        numeric(18, 6) NOT NULL CHECK (rate > 0),
    currency    char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    valid_from  date NOT NULL DEFAULT DATE '2000-01-01',
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS exp_mileage_rates_bus_idx ON expenses.exp_mileage_rates (bus_id);

CREATE TABLE IF NOT EXISTS expenses.exp_per_diem_rates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    country     char(2) NOT NULL CHECK (country ~ '^[A-Z]{2}$'),
    city        text NOT NULL DEFAULT '',
    amount      numeric(18, 4) NOT NULL CHECK (amount > 0),
    currency    char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    valid_from  date NOT NULL DEFAULT DATE '2000-01-01',
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS exp_per_diem_rates_bus_idx ON expenses.exp_per_diem_rates (bus_id);

CREATE TABLE IF NOT EXISTS expenses.exp_policies (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    name         text NOT NULL CHECK (btrim(name) <> ''),
    kind         text NOT NULL CHECK (kind IN ('max_per_item', 'max_per_day', 'max_per_month', 'receipt_over',
                                               'no_weekend', 'purpose_required', 'max_age_days')),
    category_id  text REFERENCES expenses.exp_categories (id) ON DELETE CASCADE,
    amount       numeric(18, 4),
    action       text NOT NULL DEFAULT 'warn' CHECK (action IN ('warn', 'block')),
    is_active    boolean NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    CHECK (kind IN ('no_weekend', 'purpose_required') OR (amount IS NOT NULL AND amount > 0))
);
CREATE INDEX IF NOT EXISTS exp_policies_bus_idx ON expenses.exp_policies (bus_id);

CREATE TABLE IF NOT EXISTS expenses.exp_approval_steps (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    position         integer NOT NULL DEFAULT 0,
    approver_kind    text NOT NULL CHECK (approver_kind IN ('manager', 'department_head', 'user', 'finance')),
    approver_user_id text,
    -- The step applies to claims of at least this much (in the business's currency).
    min_amount       numeric(18, 4) NOT NULL DEFAULT 0 CHECK (min_amount >= 0),
    is_active        boolean NOT NULL DEFAULT true,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    CHECK ((approver_kind = 'user') = (approver_user_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS exp_approval_steps_bus_idx ON expenses.exp_approval_steps (bus_id, position);

CREATE TABLE IF NOT EXISTS expenses.exp_claims (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    -- Given when the claim is first submitted; a draft has none.
    number              text,
    title               text NOT NULL DEFAULT '',
    purpose             text NOT NULL DEFAULT '',
    claimant_id         text NOT NULL,
    claimant_name       text NOT NULL DEFAULT '',
    claimant_email      text NOT NULL DEFAULT '',
    project_id          text,
    currency            char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    total               numeric(18, 4) NOT NULL DEFAULT 0,
    paid_total          numeric(18, 4) NOT NULL DEFAULT 0,
    status              text NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'submitted', 'approved', 'returned', 'rejected', 'paid', 'cancelled')),
    -- Where approval stands: the step it waits on and who must decide.
    current_step        integer,
    current_approver_id text,
    submitted_at        timestamptz,
    approved_at         timestamptz,
    decided_at          timestamptz,
    paid_at             timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS exp_claims_number_uq ON expenses.exp_claims (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS exp_claims_bus_status_idx ON expenses.exp_claims (bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS exp_claims_claimant_idx ON expenses.exp_claims (bus_id, claimant_id);
CREATE INDEX IF NOT EXISTS exp_claims_approver_idx ON expenses.exp_claims (bus_id, current_approver_id) WHERE status = 'submitted';

CREATE TABLE IF NOT EXISTS expenses.exp_receipts (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    user_id        text NOT NULL,
    blob_name      text NOT NULL,
    file_name      text NOT NULL DEFAULT '',
    content_type   text NOT NULL,
    size_bytes     bigint NOT NULL CHECK (size_bytes > 0),
    -- The same file claimed twice (by anyone in the business) is flagged.
    sha256         text NOT NULL,
    extracted      jsonb NOT NULL DEFAULT '{}',
    extract_status text NOT NULL DEFAULT 'none' CHECK (extract_status IN ('none', 'pending', 'done', 'failed')),
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exp_receipts_sha_idx ON expenses.exp_receipts (bus_id, sha256);

CREATE TABLE IF NOT EXISTS expenses.exp_expenses (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    -- None: kept by its owner, not yet on a claim.
    claim_id         text REFERENCES expenses.exp_claims (id) ON DELETE SET NULL,
    user_id          text NOT NULL,
    category_id      text REFERENCES expenses.exp_categories (id) ON DELETE RESTRICT,
    kind             text NOT NULL DEFAULT 'receipt' CHECK (kind IN ('receipt', 'mileage', 'per_diem')),
    spent_on         date NOT NULL,
    merchant         text NOT NULL DEFAULT '',
    description      text NOT NULL DEFAULT '',
    -- As spent, and in the claim's currency at the rate of the day.
    amount           numeric(18, 4) NOT NULL CHECK (amount >= 0),
    currency         char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    exchange_rate    numeric(18, 8) NOT NULL DEFAULT 1 CHECK (exchange_rate > 0),
    amount_base      numeric(18, 4) NOT NULL DEFAULT 0,
    tax_amount       numeric(18, 4) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    -- Mileage: the trip; per diem: the days and the place.
    distance         numeric(18, 3),
    distance_unit    text CHECK (distance_unit IS NULL OR distance_unit IN ('km', 'mi')),
    rate             numeric(18, 6),
    origin           text NOT NULL DEFAULT '',
    destination      text NOT NULL DEFAULT '',
    days             numeric(8, 2),
    country          char(2),
    city             text NOT NULL DEFAULT '',
    receipt_id       text REFERENCES expenses.exp_receipts (id) ON DELETE SET NULL,
    billable         boolean NOT NULL DEFAULT false,
    billable_to      text NOT NULL DEFAULT '',
    -- [{code, level: 'warn'|'block', message}] from the policies and the audit.
    flags            jsonb NOT NULL DEFAULT '[]',
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
CREATE INDEX IF NOT EXISTS exp_expenses_claim_idx ON expenses.exp_expenses (claim_id);
CREATE INDEX IF NOT EXISTS exp_expenses_user_idx ON expenses.exp_expenses (bus_id, user_id, spent_on DESC);

CREATE TABLE IF NOT EXISTS expenses.exp_approvals (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    claim_id    text NOT NULL REFERENCES expenses.exp_claims (id) ON DELETE CASCADE,
    step        integer NOT NULL,
    approver_id text NOT NULL,
    decision    text NOT NULL CHECK (decision IN ('approved', 'returned', 'rejected')),
    note        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exp_approvals_claim_idx ON expenses.exp_approvals (claim_id, cdatetime);

CREATE TABLE IF NOT EXISTS expenses.exp_claim_payouts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    claim_id          text NOT NULL REFERENCES expenses.exp_claims (id) ON DELETE RESTRICT,
    amount            numeric(18, 4) NOT NULL CHECK (amount > 0),
    currency          char(3) NOT NULL,
    method            text NOT NULL CHECK (method IN ('gateway', 'manual')),
    status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'processing', 'success', 'failed', 'reversed', 'manual')),
    -- Core Platform's payout for it: app 'app-expenses' and this reference (unique).
    app_reference     text NOT NULL UNIQUE,
    recipient         jsonb NOT NULL DEFAULT '{}',
    manual_reference  text NOT NULL DEFAULT '',
    failure_reason    text NOT NULL DEFAULT '',
    paid_by           text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    completed_at      timestamptz
);
CREATE INDEX IF NOT EXISTS exp_claim_payouts_claim_idx ON expenses.exp_claim_payouts (claim_id);
CREATE INDEX IF NOT EXISTS exp_claim_payouts_open_idx ON expenses.exp_claim_payouts (status) WHERE status IN ('pending', 'processing');

COMMIT;
