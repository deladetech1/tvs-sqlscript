-- 20260707-01-estimate-line-taxes.sql
-- Per-line tax + optional per-line discount on the estimator.
--   * Tax moved from a single template-level modifiers.tax_percent to a per-line
--     selection from the system taxes (mystoreguard.msg_taxes), supporting
--     stacking (VAT + levies) and inclusive/exclusive.
--   * Discount can be TOTAL (template modifiers.discount_percent) or PER_LINE,
--     controlled by modifiers.discount_scope; per-line discount is frozen here.
--
-- Idempotent (ADD COLUMN IF NOT EXISTS). Safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_estimate_items
    ADD COLUMN IF NOT EXISTS discount_amount numeric(18,2) NOT NULL DEFAULT 0;

ALTER TABLE mystoreguard.msg_estimate_items
    ADD COLUMN IF NOT EXISTS taxes_applied jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE mystoreguard.msg_estimate_items
    ADD COLUMN IF NOT EXISTS tax_amount numeric(18,2) NOT NULL DEFAULT 0;
