-- 20260829-08-mystoreguard-installment-credit-premium.sql
-- Move installment sales, installment policy and credit sales to Premium.
--
-- All three sat at rank 2 (ADVANCE) and are meant to be Premium (rank 3).
-- They belong together: selling on installment needs a policy to price it,
-- and credit sales are the same act with a single deferred payment — a tier
-- that has one and not the others can half-do the job, which is worse than
-- not offering it.
--
-- Only the catalogue changes. The gates read min_tier_rank at request time
-- (see feature_gate.require_feature), so nothing in the application needs
-- deploying alongside this, and there is no cached copy to invalidate.
--
-- WHAT IT MEANS FOR A BUSINESS ALREADY ON RANK 2
--
-- It loses access to these screens, including to plans it already created and
-- money it is still owed. That is the intended behaviour of this gate — it
-- refuses reads as well as writes — but it is worth being deliberate about,
-- because unlike a feature that was never bought, a downgrade can strand a
-- real debt behind a paywall.
--
-- Checked before writing this: on dev the single ADVANCE business holds no
-- plans, no policies and no credit sales, so nobody is cut off. Run the same
-- check before applying anywhere else — the query is in the comment below.
--
--   SELECT t.subscription_name, t.tier_rank,
--     (SELECT COUNT(*) FROM mystoreguard.msg_installment_plans p
--        WHERE p.bus_id = t.business_id AND p.tenant_id = t.tenant_id) AS plans,
--     (SELECT COUNT(*) FROM mystoreguard.msg_installment_policies ip
--        WHERE ip.bus_id = t.business_id AND ip.tenant_id = t.tenant_id) AS policies,
--     (SELECT COUNT(*) FROM mystoreguard.msg_sales s
--        WHERE s.bus_id = t.business_id AND s.tenant_id = t.tenant_id
--          AND s.sale_mode = 'CREDIT') AS credit_sales
--   FROM core_platform.cp_business_app_tier t
--   WHERE t.app_id = 'app-mystoreguard' AND t.tier_rank < 3;
--
-- Guarantors, credit scores and collections need no entry of their own: they
-- are gated on sales.installment and follow it.
--
-- Safe to re-run — it sets a value rather than adjusting one.

BEGIN;

UPDATE core_platform.cp_app_feature_catalog
SET min_tier_rank = 3
WHERE app_id = 'app-mystoreguard'
  AND feature_key IN (
      'sales.installment',            -- Installment Sales
      'settings.installment-policy',  -- Installment Policy
      'sales.credit'                  -- Credit Sales
  )
  -- Only rows that are actually moving, so a re-run writes nothing.
  AND min_tier_rank IS DISTINCT FROM 3;

COMMIT;
