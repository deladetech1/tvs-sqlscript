-- 20260717-02-affiliate-fixed-amount-commission-rate-zero.sql
-- FIXED_AMOUNT affiliates carry their payout in fixed_commission_amount, so
-- commission_rate (a 0-100 percentage) must be 0. Historically the create/update
-- paths did not enforce this, so some rows stored a non-zero commission_rate
-- (e.g. 200), which then failed the 0-100 read validation. Normalize them to 0.
-- Idempotent; safe to re-run on every deploy.

UPDATE mystoreguard.msg_affiliates
SET    commission_rate = 0
WHERE  commission_type = 'FIXED_AMOUNT'
  AND  commission_rate <> 0;
