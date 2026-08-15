-- Diagnose an empty Settings > Log Retention page.
-- Run against the target database. Each step narrows the cause; the first step
-- that returns nothing (or 'MISSING') is the answer.
--
-- Usage: replace :tenant with the tenant id you are logged in as.
--   psql "$DATABASE_URL" -v tenant="'ten-xxxx'" -f diagnose-activity-log-retention.sql

\set tenant :tenant

-- 1. Has the migration run at all? Any MISSING here means the deploy hasn't
--    applied 20260731-01-activity-log-retention.sql yet — nothing else matters.
SELECT 'cp_app_schemas'                         AS object,
       COALESCE(to_regclass('core_platform.cp_app_schemas')::text, 'MISSING') AS state
UNION ALL SELECT 'cp_subscription_retention_defaults',
       COALESCE(to_regclass('core_platform.cp_subscription_retention_defaults')::text, 'MISSING')
UNION ALL SELECT 'cp_activity_log_retention_settings',
       COALESCE(to_regclass('core_platform.cp_activity_log_retention_settings')::text, 'MISSING')
UNION ALL SELECT 'cp_activity_log_retention (view)',
       COALESCE(to_regclass('core_platform.cp_activity_log_retention')::text, 'MISSING')
UNION ALL SELECT 'cp_activity_log_sources',
       COALESCE(to_regclass('core_platform.cp_activity_log_sources')::text, 'MISSING');

-- 2. Does the tenant have app subscriptions at all?
--    Empty here = the page is telling the truth; the subscription is the problem.
SELECT sub.id, sub.app_id, sub.business_id, sub.shared_subscription_id,
       sub.status, sub.is_enterprise
FROM core_platform.cp_app_subscriptions sub
WHERE sub.tenant_id = :tenant;

-- 3. THE USUAL CULPRIT: the view joins subscriptions to businesses on BOTH
--    id and tenant_id. A subscription whose business row carries a different
--    tenant_id (common after a tenant move) silently drops out here.
SELECT sub.id AS subscription_id, sub.app_id, sub.business_id,
       b.id   AS matched_business,
       b.tenant_id AS business_tenant,
       b.org_id,
       CASE
           WHEN b.id IS NULL THEN 'NO BUSINESS ROW FOR (business_id, tenant_id)'
           WHEN b.org_id IS NULL THEN 'business has NULL org_id'
           ELSE 'ok'
       END AS verdict
FROM core_platform.cp_app_subscriptions sub
LEFT JOIN core_platform.cp_businesses b
       ON b.id = sub.business_id AND b.tenant_id = sub.tenant_id
WHERE sub.tenant_id = :tenant;

-- 3b. If step 3 says NO BUSINESS ROW, this shows whether the business exists
--     under a *different* tenant — i.e. the join key, not the data, is wrong.
SELECT sub.business_id, b.tenant_id AS business_actually_under_tenant
FROM core_platform.cp_app_subscriptions sub
JOIN core_platform.cp_businesses b ON b.id = sub.business_id
WHERE sub.tenant_id = :tenant
  AND b.tenant_id <> sub.tenant_id;

-- 4. Is the subscription's tier present in the retention defaults? A tier with no
--    row still resolves (the view falls back to 14) but is worth knowing about.
SELECT DISTINCT sub.shared_subscription_id,
       COALESCE(d.default_days::text, 'NO DEFAULTS ROW') AS default_days,
       COALESCE(d.max_days::text, 'uncapped')            AS max_days
FROM core_platform.cp_app_subscriptions sub
LEFT JOIN core_platform.cp_subscription_retention_defaults d
       ON d.subscription_id = CASE WHEN sub.is_enterprise
                                   THEN 'shared-subscription-enterprise'
                                   ELSE sub.shared_subscription_id END
WHERE sub.tenant_id = :tenant;

-- 5. What the API actually returns. If steps 2-3 are clean and this is empty,
--    the fault is in the view, not the data.
SELECT tenant_id, org_id, bus_id, app_id, default_days, max_days,
       custom_days, effective_days, is_custom
FROM core_platform.cp_activity_log_retention
WHERE tenant_id = :tenant
ORDER BY app_id;

-- 6. Which audit tables were discovered. Empty means cp_app_schemas has no row
--    matching the schemas actually present in this database.
SELECT schema_name, table_name, app_id, is_enabled
FROM core_platform.cp_activity_log_sources
ORDER BY schema_name, table_name;

-- 7. Audit tables that exist but can NOT be purged (missing tenant_id/cdatetime).
SELECT * FROM core_platform.cp_nonconforming_activity_log_tables();
