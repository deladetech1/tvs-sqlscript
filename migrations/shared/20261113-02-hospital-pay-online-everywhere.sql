-- CloudHams: pay online wherever money is taken.
--
-- A visit's bill could be paid online (the cashier's checkout, or the patient's own page). Now a
-- deposit is taken online too, and an invoice to a payer or company is paid online from the
-- invoice, through the organisation's gateway in Core Platform.
--
--   invoice_id    the invoice paid (no patient: the customer pays)
--   kind          payment or deposit (a visit's)
--   minor_places  the decimal places amount_minor was counted in (NULL: written before, x100)
--   description   what it is for, as the gateway was told
--   note          why a paid payment could not be recorded (status to_record), or how it was resolved
--
-- A payment the gateway took that cannot be recorded (the invoice paid by bank meanwhile) is kept
-- as to_record with the reason, never dropped. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE hospital.hospital_online_payments ALTER COLUMN patient_id DROP NOT NULL;
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS invoice_id text REFERENCES hospital.hospital_invoices(id) ON DELETE CASCADE;
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'payment';
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS minor_places smallint;
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE hospital.hospital_online_payments ADD COLUMN IF NOT EXISTS invoice_payment_id text;

SELECT hospital.widen_check('hospital.hospital_online_payments', 'hospital_online_payments_status_check', $q$'to_record'$q$,
    $q$CHECK (status IN ('pending', 'paid', 'failed', 'to_record', 'resolved'))$q$);
SELECT hospital.widen_check('hospital.hospital_online_payments', 'hospital_online_payments_kind_check', $q$'deposit'$q$,
    $q$CHECK (kind IN ('payment', 'deposit') AND (patient_id IS NOT NULL OR invoice_id IS NOT NULL) AND (minor_places IS NULL OR minor_places BETWEEN 0 AND 4))$q$);

COMMIT;
