-- 20260717-02-affiliate-fixed-amount-commission-rate-zero.sql
-- FIXED_AMOUNT affiliates carry their payout in fixed_commission_amount, so
-- commission_rate (a 0-100 percentage) must be 0. Historically the create/update
-- paths did not enforce this, so some rows stored the payout in commission_rate
-- (e.g. 200) with fixed_commission_amount left empty. The UI reads the payout
-- from fixed_commission_amount, so those affiliates showed a blank amount.
--
-- This migration MOVES the payout into the correct column before zeroing
-- commission_rate (never discards it), and backfills any row whose value was
-- already zeroed from the create audit log. Idempotent; safe to re-run.

-- 1) Move a still-present payout out of commission_rate (covers envs where the
--    earlier destructive version of this file has not yet run).
UPDATE mystoreguard.msg_affiliates
SET    fixed_commission_amount = commission_rate
WHERE  commission_type = 'FIXED_AMOUNT'
  AND  (fixed_commission_amount IS NULL OR fixed_commission_amount = 0)
  AND  commission_rate > 0;

-- 2) Recover rows whose commission_rate was already zeroed: pull the most recent
--    non-zero commission_rate the record was ever created/updated with from its
--    audit log, and restore it into fixed_commission_amount.
UPDATE mystoreguard.msg_affiliates a
SET    fixed_commission_amount = sub.rate
FROM (
    SELECT DISTINCT ON (entity_id)
           entity_id,
           (new_data->>'commission_rate')::numeric AS rate
    FROM   mystoreguard.msg_affiliate_audit_logs
    WHERE  new_data->>'commission_rate' IS NOT NULL
      AND  (new_data->>'commission_rate')::numeric > 0
    ORDER  BY entity_id, cdatetime DESC
) sub
WHERE  a.id = sub.entity_id
  AND  a.commission_type = 'FIXED_AMOUNT'
  AND  (a.fixed_commission_amount IS NULL OR a.fixed_commission_amount = 0);

-- 3) Now that the payout is safely in fixed_commission_amount, zero the stray
--    percentage so it never violates the 0-100 read bound.
UPDATE mystoreguard.msg_affiliates
SET    commission_rate = 0
WHERE  commission_type = 'FIXED_AMOUNT'
  AND  commission_rate <> 0;
