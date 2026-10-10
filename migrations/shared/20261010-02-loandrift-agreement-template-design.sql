-- LoanDrift agreement templates carry a design as well as wording: accent colour,
-- letterhead style and typeface, printed on every document. NULL means the
-- LoanDrift Standard design. Idempotent.
ALTER TABLE loandrift.ld_agreement_templates ADD COLUMN IF NOT EXISTS style jsonb;
