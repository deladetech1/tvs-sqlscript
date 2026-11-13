-- HMS: pay online wherever money is taken, counted right in every currency.
--
-- Online payments already ran from bills, leases, orders, invoices, vouchers, deposits,
-- activities, appointments and memberships. Now also:
--
--   * tickets sold at the desk or the door, held until paid online (they were refused at the desk);
--   * passes (spa, gym, class packs): subject 'pass', made once paid, from details kept here;
--   * minor_places: the decimal places amount_minor was counted in. The desk counted x100 while
--     the guest pages used the currency's own places, and both were read back x100, so a
--     zero-decimal currency (XOF, UGX) was out by a hundred. NULL: written before, x100;
--   * to_record / resolved: a payment the gateway took that could not be recorded (the bill paid
--     at the desk meanwhile, a pass withdrawn) is kept with the reason in note, for the desk to
--     record again or resolve -- never dropped.
--
-- This file owns the subject and status checks from now on. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS minor_places smallint;
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS details jsonb;
ALTER TABLE hms.hms_payment_attempts ADD COLUMN IF NOT EXISTS note text;

ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_subject_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_subject_check
    CHECK (subject_type IN ('lease', 'folio', 'reservation', 'order', 'voucher', 'invoice', 'activity_booking', 'deposit',
                            'ticket_sale', 'appointment', 'member', 'pass'));
ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_status_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_status_check
    CHECK (status IN ('pending', 'paid', 'failed', 'to_record', 'resolved'));
ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_places_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_places_check CHECK (minor_places IS NULL OR minor_places BETWEEN 0 AND 4);

COMMIT;
