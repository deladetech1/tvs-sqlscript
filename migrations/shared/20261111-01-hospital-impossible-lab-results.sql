-- CloudHams QA of 11 Nov 2026: lab results below zero for tests that cannot go below zero (an
-- ALT of -40 U/L) were saved before the API refused them. Each such result is taken back to the
-- lab to enter again: the number is cleared and kept in the comment, the order goes back to
-- "collected" (its sample is still on record), and it leaves the patient's released results.
-- A test whose own range goes below zero (base excess) is left alone. Idempotent; safe to re-run.

BEGIN;

WITH bad AS (
    SELECT lr.order_id, lr.value_num
      FROM hospital.hospital_lab_results lr
      JOIN hospital.hospital_orders o ON o.id = lr.order_id
      JOIN hospital.hospital_lab_tests t ON t.id = o.item_id
     WHERE lr.value_num < 0 AND (t.ref_low IS NULL OR t.ref_low >= 0) AND o.status IN ('resulted', 'released')
), fixed AS (
    UPDATE hospital.hospital_lab_results lr
       SET comment = concat_ws(' ', 'Entered as ' || bad.value_num::text || ', which is not possible for this test: enter it again.', lr.comment),
           value_num = NULL, flag = NULL, entered_by = NULL, entered_at = NULL, validated_by = NULL, validated_at = NULL
      FROM bad WHERE lr.order_id = bad.order_id
    RETURNING lr.order_id
)
UPDATE hospital.hospital_orders o SET status = 'collected', updated_at = now() FROM fixed WHERE o.id = fixed.order_id;

COMMIT;
