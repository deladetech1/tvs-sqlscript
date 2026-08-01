-- 20260801-01-retention-addon-billing.sql
-- Charge for activity-log retention beyond what a plan includes.
--
-- Model: each plan includes free days (cp_subscription_retention_defaults.default_days).
-- Anything beyond that is sold in blocks of 30 days, priced as a PERCENTAGE of what that
-- business already pays for that app — so a GHS 70 shop and a GHS 3000 enterprise are
-- charged proportionally, and there is one number to maintain instead of a price per
-- (app x tier). Billed monthly per location, matching how cp_billings_logs already works.
--
-- Non-payment must not silently destroy audit history: cp_activity_log_retention keeps
-- honouring the paid window until the tenant is past the grace period, so the purge does
-- not shrink anyone's logs the moment a card fails.
--
-- Idempotent; safe to re-run on every deploy.

SET search_path TO core_platform;

-- =====================================================================================
-- 1. Pricing. app_id '*' is the default for every app; insert a row for a specific
--    app_id to override it. percent_of_price is applied to cp_app_tier_configs.price,
--    i.e. the per-location monthly price of that business-app's current tier.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_retention_addon_pricing (
    app_id           text          PRIMARY KEY,
    block_days       integer       NOT NULL DEFAULT 30  CHECK (block_days > 0),
    percent_of_price numeric(7,4)  NOT NULL DEFAULT 10  CHECK (percent_of_price >= 0),
    is_active        boolean       NOT NULL DEFAULT true,
    description      text,
    cdatetime        timestamptz   NOT NULL DEFAULT now()
);

INSERT INTO core_platform.cp_retention_addon_pricing (app_id, block_days, percent_of_price, description) VALUES
('*', 30, 10, 'Default: each extra 30 days of log retention costs 10% of the app''s monthly price, per location')
ON CONFLICT (app_id) DO NOTHING;

-- =====================================================================================
-- 2. Caps become a safety ceiling rather than the product limit — once retention is sold
--    by the block, a 30-day cap on BASIC leaves almost nothing to buy. Defaults (the free
--    allowance) are unchanged; only the ceiling moves. Enterprise stays uncapped.
-- =====================================================================================
UPDATE core_platform.cp_subscription_retention_defaults
   SET max_days = 365
 WHERE subscription_id IN ('shared-subscription-basic',
                           'shared-subscription-advance',
                           'shared-subscription-premium')
   AND (max_days IS NULL OR max_days < 365);

-- =====================================================================================
-- 3. Grace. A failed payment must not shrink retention on the spot. This records, per
--    business-app, whether the tenant is currently past due beyond the grace window.
--    Mirrors the billing job's own definition: PENDING rows older than the grace period.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_retention_addon_grace AS
SELECT b.tenant_id,
       b.business_id AS bus_id,
       b.app_id,
       min(b.cdatetime)                                             AS oldest_unpaid_at,
       (min(b.cdatetime) < now() - interval '4 days')               AS past_grace
FROM core_platform.cp_billings_logs b
WHERE b.paid_status = 'PENDING'
  AND b.delete_status = 'NOT_DELETED'
GROUP BY b.tenant_id, b.business_id, b.app_id;

-- =====================================================================================
-- 4. What each business-app owes for retention this month, and what the purge should
--    treat as the live window. One row per business-app; the per-location multiplication
--    happens in the billing job, which already emits one row per location.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_retention_addon_charges AS
SELECT r.tenant_id,
       r.org_id,
       r.bus_id,
       r.app_id,
       r.default_days,
       r.effective_days,
       p.block_days,
       p.percent_of_price,
       atc.price                                                        AS app_price,
       -- Round part-blocks UP: asking for 44 days on a 14-day plan buys one 30-day block.
       GREATEST(0, CEIL((r.effective_days - r.default_days)::numeric / p.block_days))::int
                                                                        AS billable_blocks,
       ROUND(
           GREATEST(0, CEIL((r.effective_days - r.default_days)::numeric / p.block_days))
           * COALESCE(atc.price, 0) * p.percent_of_price / 100.0
       , 2)                                                             AS addon_price_per_location
FROM core_platform.cp_activity_log_retention r
JOIN core_platform.cp_app_subscriptions sub
  ON sub.tenant_id = r.tenant_id
 AND sub.business_id = r.bus_id
 AND sub.app_id = r.app_id
 AND sub.delete_status = 'NOT_DELETED'
 AND sub.is_active
JOIN core_platform.cp_app_tier_configs atc
  ON atc.app_id = sub.app_id
 AND atc.subscription_id = CASE WHEN sub.is_enterprise
                                THEN 'shared-subscription-enterprise'
                                ELSE sub.shared_subscription_id END
 AND atc.delete_status = 'NOT_DELETED'
LEFT JOIN core_platform.cp_retention_addon_pricing p
  ON p.app_id = CASE WHEN EXISTS (SELECT 1 FROM core_platform.cp_retention_addon_pricing x
                                   WHERE x.app_id = r.app_id AND x.is_active)
                     THEN r.app_id ELSE '*' END
 AND p.is_active
-- Enterprise is billed off-platform; never emit an add-on line for it.
WHERE NOT sub.is_enterprise
  AND r.effective_days > r.default_days;


-- =====================================================================================
-- 6. What has actually been PAID FOR this month. Lowering retention must not delete logs
--    the customer already paid to keep, so the purge never goes below the largest window
--    settled in the current billing month. The month string matches the format the
--    billing job writes ('Aug 2026').
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_retention_paid_floor AS
SELECT b.tenant_id,
       b.business_id           AS bus_id,
       b.app_id,
       max(b.retention_days)   AS paid_days
FROM core_platform.cp_billings_logs b
WHERE b.line_type = 'RETENTION_ADDON'
  AND b.paid_status = 'PAID'
  AND b.delete_status = 'NOT_DELETED'
  AND b.retention_days IS NOT NULL
  AND b.month = to_char(now(), 'Mon YYYY')
GROUP BY b.tenant_id, b.business_id, b.app_id;

-- =====================================================================================
-- 5. Enforcement. The SETTING keeps whatever the customer chose; what the purge acts on
--    is redefined here so a failed payment cannot destroy audit history on the spot.
--    While a business-app is within grace, the paid window still applies. Only once it is
--    past grace does the cutoff fall back to the plan's free allowance.
--
--    Same columns, same order as the original definition — this replaces it in place.
--    Core Platform has no subscription and therefore no add-on, so it never shrinks here
--    (its NULL bus_id simply finds no grace row).
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_activity_log_cutoffs AS
WITH resolved AS (
    SELECT r.tenant_id,
           r.org_id,
           r.bus_id,
           r.app_id,
           CASE
               -- Past grace on an unpaid bill: fall back to the plan's free allowance.
               WHEN COALESCE(g.past_grace, false)
                   THEN LEAST(r.effective_days, COALESCE(r.default_days, r.effective_days))
               -- Otherwise honour the setting, but never below what has already been paid
               -- for this month — pressing "reset" must not destroy purchased history.
               ELSE GREATEST(r.effective_days, COALESCE(pf.paid_days, 0))
           END AS effective_days
    FROM core_platform.cp_activity_log_retention r
    LEFT JOIN core_platform.cp_retention_addon_grace g
           ON g.tenant_id = r.tenant_id
          AND g.bus_id    = r.bus_id
          AND g.app_id    = r.app_id
    LEFT JOIN core_platform.cp_retention_paid_floor pf
           ON pf.tenant_id = r.tenant_id
          AND pf.bus_id    = r.bus_id
          AND pf.app_id    = r.app_id
)
SELECT tenant_id, org_id, bus_id, app_id, effective_days,
       now() - make_interval(days => effective_days) AS cutoff_at
FROM resolved;
