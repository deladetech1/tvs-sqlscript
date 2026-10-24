-- HMS: a security deposit paid online, and bar stock kept by the bottle but sold by the measure.
--
--   hms_payment_attempts.subject_type  adds 'deposit' (a security deposit received online).
--   hms_stock_items.content_size,
--   hms_stock_items.content_unit       what one stock unit holds: a 750 ml bottle of gin, a 20 l keg.
--                                      Stock is still counted in bottles; a recipe that takes a
--                                      30 ml tot takes 30/750 of a bottle, and the stock screens
--                                      can say "4 bottles and 12 tots".
--
-- Every shared file re-runs on each deploy: a constraint this file widens is guarded where it
-- was first created, and this file is the one that owns it now.

BEGIN;

ALTER TABLE hms.hms_payment_attempts DROP CONSTRAINT IF EXISTS hms_payment_attempts_subject_check;
ALTER TABLE hms.hms_payment_attempts ADD CONSTRAINT hms_payment_attempts_subject_check
    CHECK (subject_type IN ('lease', 'folio', 'reservation', 'order', 'voucher', 'invoice', 'activity_booking', 'deposit'));

ALTER TABLE hms.hms_stock_items ADD COLUMN IF NOT EXISTS content_size numeric(14,3);
ALTER TABLE hms.hms_stock_items ADD COLUMN IF NOT EXISTS content_unit text;
ALTER TABLE hms.hms_stock_items DROP CONSTRAINT IF EXISTS hms_stock_items_content_check;
ALTER TABLE hms.hms_stock_items ADD CONSTRAINT hms_stock_items_content_check
    CHECK ((content_size IS NULL AND content_unit IS NULL) OR (content_size > 0 AND content_unit IN ('ml', 'cl', 'l', 'g', 'kg', 'pcs')));

COMMIT;
