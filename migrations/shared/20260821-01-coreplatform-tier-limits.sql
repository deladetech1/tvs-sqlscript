-- 20260821-01-coreplatform-tier-limits.sql
-- Subscription tiers gate core-platform capacity (orgs, businesses, users, locations, groups).
--
-- Core platform is the hub, not a subscribable app — there is no cp_app_subscriptions row
-- for it. A tenant's effective platform tier is therefore DERIVED: the highest tier across
-- its active per-(business, app) subscriptions. Paying PREMIUM for one app must not leave
-- the hub crippled because another app sits on BASIC. A tenant with no subscriptions at all
-- (fresh signup, or fully unsubscribed) resolves to BASIC, which still allows the 1 org +
-- 1 business + 1 location it needs to reach the App Store and subscribe in the first place.
--
-- Caps are a CEILING ON CREATION, not a retroactive delete: a tenant that downgrades keeps
-- everything it already has and is simply refused the next create. Nothing here removes data.
--
-- Limits live in a table, not in code, so changing the offer needs no deploy.
-- NULL = unlimited, matching cp_app_tier_configs.max_login_users.
--
-- Idempotent; safe to re-run on every deploy.

SET search_path TO core_platform;

-- =====================================================================================
-- 1. Per-tier core-platform capacity. One row per tier in cp_subscriptions.
--    NULL on a max_* column means unlimited. groups_enabled=false switches the Groups
--    module off entirely for the tier (BASIC) — existing groups stay readable, but no
--    new group can be created and no user can be added to one.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_subscription_platform_limits (
    subscription_id   text        PRIMARY KEY
        REFERENCES core_platform.cp_subscriptions (id) ON DELETE CASCADE,
    max_organizations integer     CHECK (max_organizations IS NULL OR max_organizations > 0),
    max_businesses    integer     CHECK (max_businesses    IS NULL OR max_businesses    > 0),
    max_users         integer     CHECK (max_users         IS NULL OR max_users         > 0),
    max_locations     integer     CHECK (max_locations     IS NULL OR max_locations     > 0),
    groups_enabled    boolean     NOT NULL DEFAULT true,
    description       text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);

INSERT INTO core_platform.cp_subscription_platform_limits
    (subscription_id, max_organizations, max_businesses, max_users, max_locations, groups_enabled, description) VALUES
('shared-subscription-basic',      1,    1,    5,    2, false, 'Basic: 1 organization, 1 business, 5 users, 2 locations, no groups'),
('shared-subscription-advance',    1,    3,   10,    5, true,  'Advance: 1 organization, 3 businesses, 10 users, 5 locations, groups included'),
('shared-subscription-premium',    NULL, NULL, NULL, NULL, true, 'Premium: unlimited core-platform capacity'),
('shared-subscription-enterprise', NULL, NULL, NULL, NULL, true, 'Enterprise: unlimited core-platform capacity')
ON CONFLICT (subscription_id) DO UPDATE SET
    max_organizations = EXCLUDED.max_organizations,
    max_businesses    = EXCLUDED.max_businesses,
    max_users         = EXCLUDED.max_users,
    max_locations     = EXCLUDED.max_locations,
    groups_enabled    = EXCLUDED.groups_enabled,
    description       = EXCLUDED.description;

-- Roles & Permissions and Settings are deliberately absent: every tier gets all of both.
-- Adding a cap there later means adding a column here, not new enforcement plumbing.

-- =====================================================================================
-- 2. Tier ranking, as data. BASIC < ADVANCE < PREMIUM < ENTERPRISE. It lives on this
--    table rather than on cp_subscriptions because cp_subscriptions is EF-owned — a
--    hand-added column there would be dropped by the next scaffolded migration.
--    The Python side mirrors this in _TIER_HIERARCHY.
-- =====================================================================================
ALTER TABLE core_platform.cp_subscription_platform_limits
    ADD COLUMN IF NOT EXISTS tier_rank integer NOT NULL DEFAULT 0;

UPDATE core_platform.cp_subscription_platform_limits SET tier_rank = v.rank
  FROM (VALUES ('shared-subscription-basic',      1),
               ('shared-subscription-advance',    2),
               ('shared-subscription-premium',    3),
               ('shared-subscription-enterprise', 4)) AS v(id, rank)
 WHERE cp_subscription_platform_limits.subscription_id = v.id
   AND cp_subscription_platform_limits.tier_rank IS DISTINCT FROM v.rank;

-- =====================================================================================
-- 3. Effective platform tier + limits per tenant. Every tenant appears exactly once,
--    including tenants with zero subscriptions (they fall back to BASIC).
--
--    A subscription only counts toward the tier while it actually entitles the tenant:
--    enterprise deals always, trials until the trial window closes, paid tiers until the
--    period ends. Lapsed rows drop out and the tenant falls back to whatever is still
--    valid — BASIC if nothing is. This mirrors check_subscription_active() in auth.py,
--    minus the grace period: grace keeps you writing, it does not keep you on PREMIUM.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_tenant_platform_limits AS
WITH entitled AS (
    SELECT aps.tenant_id,
           aps.shared_subscription_id,
           COALESCE(pl.tier_rank, 0) AS tier_rank
    FROM core_platform.cp_app_subscriptions aps
    JOIN core_platform.cp_subscriptions s
      ON s.id = aps.shared_subscription_id
     AND s.delete_status = 'NOT_DELETED'
     AND s.is_active = true
    LEFT JOIN core_platform.cp_subscription_platform_limits pl
      ON pl.subscription_id = aps.shared_subscription_id
    LEFT JOIN core_platform.cp_tenants t
      ON t.id = aps.tenant_id
    WHERE aps.delete_status = 'NOT_DELETED'
      AND aps.is_active = true
      AND (
            aps.is_enterprise = true
         OR (aps.status = 'TRIALING'
             AND (t.free_trial_ends_at IS NULL OR t.free_trial_ends_at > now()))
         OR (aps.status IN ('ACTIVE', 'PAST_DUE')
             AND aps.current_period_end IS NOT NULL
             AND aps.current_period_end > now())
      )
),
best AS (
    SELECT DISTINCT ON (tenant_id) tenant_id, shared_subscription_id
    FROM entitled
    ORDER BY tenant_id, tier_rank DESC, shared_subscription_id
)
SELECT t.id                                                             AS tenant_id,
       COALESCE(b.shared_subscription_id, 'shared-subscription-basic')  AS subscription_id,
       COALESCE(upper(s.subscription_name), 'BASIC')                    AS subscription_name,
       l.max_organizations,
       l.max_businesses,
       l.max_users,
       l.max_locations,
       COALESCE(l.groups_enabled, false)                                AS groups_enabled
FROM core_platform.cp_tenants t
LEFT JOIN best b
       ON b.tenant_id = t.id
LEFT JOIN core_platform.cp_subscriptions s
       ON s.id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic')
LEFT JOIN core_platform.cp_subscription_platform_limits l
       ON l.subscription_id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic');

-- =====================================================================================
-- 4. Current core-platform usage per tenant, counted the same way the API enforces it.
--    Soft-deleted rows do not count (deleting frees the quota); is_active is ignored,
--    because deactivating a record does not release the slot — deleting it does.
--    System groups are excluded: they are platform plumbing, not tenant-created groups.
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_tenant_platform_usage AS
SELECT t.id AS tenant_id,
       (SELECT count(*) FROM core_platform.cp_organizations o
         WHERE o.tenant_id = t.id AND o.delete_status = 'NOT_DELETED')          AS organizations_used,
       (SELECT count(*) FROM core_platform.cp_businesses b
         WHERE b.tenant_id = t.id AND b.delete_status = 'NOT_DELETED')          AS businesses_used,
       (SELECT count(*) FROM core_platform.cp_users u
         WHERE u.tenant_id = t.id AND u.delete_status = 'NOT_DELETED')          AS users_used,
       (SELECT count(*) FROM core_platform.cp_locations l
         WHERE l.tenant_id = t.id AND l.delete_status = 'NOT_DELETED')          AS locations_used,
       (SELECT count(*) FROM core_platform.cp_groups g
         WHERE g.tenant_id = t.id AND g.delete_status = 'NOT_DELETED'
           AND (g.is_system = false OR g.is_system IS NULL))                    AS groups_used
FROM core_platform.cp_tenants t;
