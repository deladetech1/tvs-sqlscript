-- CloudHams (app-hospital), part 9: paying expenses through Core Platform.
--
-- An approved expense is paid through the business's payout gateway in Core Platform (to a
-- mobile-money number or a bank account), or recorded as paid by hand with its reference, which
-- Core Platform keeps too. Each attempt is kept here; (expense, attempt) is the reference Core
-- Platform knows it by, so a retried request never pays twice.
--
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS hospital.hospital_expense_payouts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    facility_id       text NOT NULL REFERENCES hospital.hospital_facilities(id),
    entry_id          text NOT NULL REFERENCES hospital.hospital_entries(id),
    amount            numeric(14, 2) NOT NULL CHECK (amount > 0),
    currency          text NOT NULL,
    method            text NOT NULL,
    status            text NOT NULL,
    app_reference     text NOT NULL,
    recipient         jsonb,
    manual_reference  text,
    failure_reason    text,
    paid_by           text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    completed_at      timestamptz
);
SELECT hospital.widen_check('hospital.hospital_expense_payouts', 'hospital_expense_payouts_method_check', $q$'manual'$q$,
    $q$CHECK (method IN ('gateway', 'manual'))$q$);
SELECT hospital.widen_check('hospital.hospital_expense_payouts', 'hospital_expense_payouts_status_check', $q$'manual'$q$,
    $q$CHECK (status IN ('pending', 'processing', 'success', 'failed', 'reversed', 'manual'))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_expense_payouts_ref_uq ON hospital.hospital_expense_payouts (app_reference);
CREATE INDEX IF NOT EXISTS hospital_expense_payouts_entry_idx ON hospital.hospital_expense_payouts (entry_id, cdatetime);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_expense_payouts_open_uq ON hospital.hospital_expense_payouts (entry_id) WHERE status IN ('pending', 'processing');

COMMIT;
