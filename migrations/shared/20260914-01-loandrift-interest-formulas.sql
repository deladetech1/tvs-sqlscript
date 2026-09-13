-- Formulas are business-scoped, including overrides of shared system types.
-- Existing loan agreements are not rewritten by a settings update.
CREATE TABLE IF NOT EXISTS loandrift.ld_interest_formulas (
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    interest_type_id text NOT NULL,
    formula text NOT NULL CHECK (length(formula) BETWEEN 1 AND 500),
    updated_by text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, org_id, bus_id, interest_type_id)
);
ALTER TABLE loandrift.ld_loan_calculations ADD COLUMN IF NOT EXISTS interest_formula text;
ALTER TABLE loandrift.ld_interest_formulas ADD COLUMN IF NOT EXISTS repayment_method text NOT NULL DEFAULT 'EQUAL_PAYMENT' CHECK (repayment_method IN ('EQUAL_PAYMENT','EQUAL_PRINCIPAL'));
ALTER TABLE loandrift.ld_loan_calculations ADD COLUMN IF NOT EXISTS repayment_method text;
ALTER TABLE loandrift.ld_loan_calculations ADD COLUMN IF NOT EXISTS scheduled_payments jsonb;
DO $$
DECLARE definition text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='loandrift' AND table_name='ld_loan_details_view' AND column_name='interest_formula') THEN
    SELECT rtrim(pg_get_viewdef('loandrift.ld_loan_details_view'::regclass, true), E';\n ') INTO definition;
    EXECUTE format('CREATE OR REPLACE VIEW loandrift.ld_loan_details_view AS SELECT old.*, calc.interest_formula, calc.repayment_method, calc.scheduled_payments FROM (%s) old LEFT JOIN loandrift.ld_loan_calculations calc ON calc.loan_id=old.id AND calc.tenant_id=old.tenant_id AND calc.org_id=old.org_id AND calc.bus_id=old.bus_id AND calc.loc_id=old.loc_id', definition);
  END IF;
END $$;
