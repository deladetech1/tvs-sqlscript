-- Core Platform: one expense pattern for every app -- categories, and a fuller expense record.
--
-- Until now each app had its own idea of an expense: MyStoreGuard and LoanDrift wrote to
-- cp_expenses_history with `source` standing in for a category, HMS kept its own categories,
-- and nothing carried tax, a supplier or an approval. Core now owns:
--
--   * cp_expense_categories -- the organisation's expense categories, for every business or one
--     (bus_id NULL = all its businesses): name, an optional Core tax rate (cp_tax_rates) for the
--     reclaimable tax on it, an optional accounting code, whether a receipt is required, and
--     an icon. Settings > Expenses > Categories. Defaults are created the first time Core is
--     asked for them (core-platform), not here, so a tenant that never uses expenses gets none.
--   * cp_expenses_history (the expense record every app writes) gains: category_id,
--     spent_on, tax_rate_id, tax_amount, supplier_id (cp_parties), receipt_file_id, status
--     (approval: APPROVED by default, so every existing and every app's row stays as it was),
--     approved_by / approved_at, reference. All nullable or defaulted -- nothing an app writes
--     today breaks.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_expense_categories (
    tenant_id        text        NOT NULL,
    id               text        NOT NULL,
    bus_id           text,
    name             text        NOT NULL,
    description      text,
    icon             text,
    tax_rate_id      text,
    account_code     text,
    receipt_required boolean     NOT NULL DEFAULT false,
    is_active        boolean     NOT NULL DEFAULT true,
    position         integer     NOT NULL DEFAULT 0,
    created_by       text,
    updated_by       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_expense_categories_name
    ON core_platform.cp_expense_categories (tenant_id, coalesce(bus_id, ''), lower(name));
CREATE INDEX IF NOT EXISTS ix_cp_expense_categories_bus
    ON core_platform.cp_expense_categories (tenant_id, bus_id);

ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS category_id     text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS spent_on        date;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS tax_rate_id     text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS tax_amount      numeric(18, 4);
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS supplier_id     text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS receipt_file_id text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS reference       text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS status          text NOT NULL DEFAULT 'APPROVED';
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS approved_by     text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS approved_at     timestamptz;

ALTER TABLE core_platform.cp_expenses_history DROP CONSTRAINT IF EXISTS cp_expenses_history_status_check;
ALTER TABLE core_platform.cp_expenses_history ADD CONSTRAINT cp_expenses_history_status_check
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'));

CREATE INDEX IF NOT EXISTS ix_cp_expenses_history_category
    ON core_platform.cp_expenses_history (tenant_id, category_id);

COMMIT;
