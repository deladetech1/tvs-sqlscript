-- Expenses lite: one record and one flow for expenses inside apps (MyStoreGuard, LoanDrift,
-- HMS, CloudHams). Standard: apps-setup/EXPENSES-LITE-STANDARD.md (tvs-skills).
--
--   * cp_expenses_history.status widens to the lite flow: SUBMITTED (awaiting the one
--     approval), APPROVED (unpaid), PAID, REJECTED, VOIDED; PENDING stays allowed and is read
--     as SUBMITTED. Existing rows are NOT changed here: each app moves its own (and its
--     accounting trigger) in its own migration, so a status change never fires a posting by
--     surprise.
--   * New fields: paid_from (cash | bank | mobile_money | card | petty_cash | other), payee
--     (free text when there is no supplier), and who/when for submitted, approved (exists),
--     rejected (+ reason), paid (+ payment reference) and voided (+ reason).
--   * cp_expense_settings: approval on/off per business (bus_id NULL = the organisation's
--     default). Off unless a business turns it on.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS paid_from         text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS payee             text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS submitted_by      text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS submitted_at      timestamptz;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS rejected_by       text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS rejected_at       timestamptz;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS rejection_reason  text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS paid_by           text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS paid_at           timestamptz;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS payment_reference text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS voided_by         text;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS voided_at         timestamptz;
ALTER TABLE core_platform.cp_expenses_history ADD COLUMN IF NOT EXISTS void_reason       text;

ALTER TABLE core_platform.cp_expenses_history DROP CONSTRAINT IF EXISTS cp_expenses_history_status_check;
ALTER TABLE core_platform.cp_expenses_history ADD CONSTRAINT cp_expenses_history_status_check
    CHECK (status IN ('SUBMITTED', 'PENDING', 'APPROVED', 'PAID', 'REJECTED', 'VOIDED'));

ALTER TABLE core_platform.cp_expenses_history DROP CONSTRAINT IF EXISTS cp_expenses_history_paid_from_check;
ALTER TABLE core_platform.cp_expenses_history ADD CONSTRAINT cp_expenses_history_paid_from_check
    CHECK (paid_from IS NULL OR paid_from IN ('cash', 'bank', 'mobile_money', 'card', 'petty_cash', 'other'));

CREATE TABLE IF NOT EXISTS core_platform.cp_expense_settings (
    tenant_id         text        NOT NULL,
    id                text        NOT NULL,
    bus_id            text,
    approval_required boolean     NOT NULL DEFAULT false,
    updated_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_expense_settings_scope
    ON core_platform.cp_expense_settings (tenant_id, coalesce(bus_id, ''));

COMMIT;
