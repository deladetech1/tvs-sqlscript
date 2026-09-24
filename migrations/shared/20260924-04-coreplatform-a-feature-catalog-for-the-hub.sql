-- The hub needed its own feature catalog.
--
-- Core Platform gates paid features with a boolean column on
-- cp_subscription_platform_limits: groups_enabled, then security_dashboard_enabled.
-- That works for two. The security section is about to have a dozen — sessions,
-- IP rules, alerting, webhooks, API keys — and a column each would mean a
-- migration each, the cp_tenant_platform_limits view rewritten each time, and a
-- DTO field each on the way out to the browser.
--
-- MyStoreGuard and LoanDrift already solved this. cp_app_feature_catalog holds a
-- row per feature with a min_tier_rank, and cp_business_app_features resolves it
-- against what the business is entitled to. Adding a feature there is an INSERT,
-- and re-tiering one is an UPDATE — neither needs a deploy.
--
-- Core Platform cannot use that table. Every row in it carries an app_id that
-- must appear in cp_app_subscriptions, and the hub is not a subscribable app —
-- there is no subscription row for it and no tier-config row either. A catalog
-- entry for 'app-coreplatform' would join to nothing and resolve for no tenant,
-- ever. So this is the same idea with the app key removed, resolving instead
-- against the tenant's DERIVED tier: the highest across their entitled app
-- subscriptions, which is what cp_tenant_platform_limits already computes.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. tier_rank on the tenant view.
-- =====================================================================
-- The view resolves the tenant's best entitled subscription but only exposes its
-- NAME. Comparing a name against min_tier_rank would mean a CASE over four
-- strings in every feature query, which is the ordering living in two places —
-- and 20260821-01 put the ordering in tier_rank precisely so it would live in one.
--
-- DROP before CREATE: a view's column set cannot be changed by CREATE OR REPLACE,
-- and this file adds a column to it.
--
-- The dependent view goes first. cp_tenant_platform_features (created further
-- down this same file) selects from cp_tenant_platform_limits, so on every run
-- after the first, dropping the limits view alone fails with "cannot drop view
-- ... because other objects depend on it". Dropping the dependent explicitly is
-- better than DROP ... CASCADE here: CASCADE would also silently remove
-- anything ELSE that came to depend on this view later, and the failure mode of
-- that is a view quietly missing in production rather than a loud error.
DROP VIEW IF EXISTS core_platform.cp_tenant_platform_features;
DROP VIEW IF EXISTS core_platform.cp_tenant_platform_limits;

CREATE VIEW core_platform.cp_tenant_platform_limits AS
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
            -- In trial, or inside the grace window after it ended (20260924-03).
         OR (aps.status = 'TRIALING'
             AND (t.free_trial_ends_at IS NULL
                  OR t.free_trial_ends_at + make_interval(days => 4) > now()))
         OR (aps.status IN ('ACTIVE', 'PAST_DUE')
             AND aps.current_period_end IS NOT NULL
             AND aps.current_period_end + make_interval(days => 4) > now())
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
       -- BASIC's own rank when the tenant has nothing entitled, not 0. A tenant
       -- with no subscriptions still gets everything BASIC includes.
       COALESCE(l.tier_rank, 1)                                         AS tier_rank,
       l.max_organizations,
       l.max_businesses,
       l.max_users,
       l.max_locations,
       COALESCE(l.groups_enabled, false)                                AS groups_enabled,
       COALESCE(l.security_dashboard_enabled, false)                    AS security_dashboard_enabled
FROM core_platform.cp_tenants t
LEFT JOIN best b
       ON b.tenant_id = t.id
LEFT JOIN core_platform.cp_subscriptions s
       ON s.id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic')
LEFT JOIN core_platform.cp_subscription_platform_limits l
       ON l.subscription_id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic');


-- =====================================================================
-- 2. The catalog.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_platform_feature_catalog (
    feature_key   text        PRIMARY KEY,
    title         text        NOT NULL,
    -- Lowest tier that unlocks it. 1=BASIC 2=ADVANCE 3=PREMIUM 4=ENTERPRISE,
    -- matching cp_subscription_platform_limits.tier_rank.
    min_tier_rank integer     NOT NULL CHECK (min_tier_rank BETWEEN 1 AND 4),
    -- false retires a feature from gating without deleting the row: it stops
    -- appearing in the resolved view, so the API and UI treat it as ungated
    -- rather than denied. Copied from cp_app_feature_catalog, where the same
    -- distinction is what makes a feature safe to un-gate in a hurry.
    is_active     boolean     NOT NULL DEFAULT true,
    description   text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_cp_platform_feature_catalog_tier
    ON core_platform.cp_platform_feature_catalog (min_tier_rank);


-- =====================================================================
-- 3. Resolved per tenant.
-- =====================================================================
-- Cumulative through >=, like cp_business_app_features: PREMIUM gets everything
-- ADVANCE gets. A tenant appears once per feature they are entitled to, and not
-- at all for the ones they are not.
CREATE OR REPLACE VIEW core_platform.cp_tenant_platform_features AS
SELECT l.tenant_id,
       l.subscription_name,
       l.tier_rank,
       f.feature_key,
       f.title,
       f.min_tier_rank
FROM core_platform.cp_tenant_platform_limits l
JOIN core_platform.cp_platform_feature_catalog f
  ON f.is_active = true
 AND l.tier_rank >= f.min_tier_rank;


-- =====================================================================
-- 4. What the security section is made of.
-- =====================================================================
-- Deliberately absent: the Overview and the Setup screen. Password policy, MFA,
-- lockout and session length are basic hygiene, and charging for them means the
-- tenants least able to afford a breach are the ones running without a password
-- policy. They stay ungated at every tier, which is also why the section itself
-- is no longer gated as a whole.
INSERT INTO core_platform.cp_platform_feature_catalog
    (feature_key, title, min_tier_rank, description) VALUES

-- ---- ADVANCE: see and stop what is happening now -------------------------
('security.sessions',        'Session Management',        2, 'See every signed-in device and end any of them'),
('security.alerts',          'Security Alerts',           2, 'Email and SMS when something serious happens'),
('security.rate-limit',      'Sign-in Rate Limiting',     2, 'Throttle repeated sign-in attempts by address'),

-- ---- PREMIUM: decide who gets in, and notice when it is wrong ------------
('security.threat-detection','Threat Detection',          3, 'New device, new location and impossible-travel detection'),
('security.ip-rules',        'IP and Country Rules',      3, 'Allow or block sign-in by address range or country'),
('security.breach-check',    'Breached Password Check',   3, 'Refuse passwords known to have appeared in a breach'),
('security.step-up',         'Step-up Authentication',    3, 'Re-authenticate before privileged actions'),
('security.reports',         'Security Reports',          3, 'Sign-in, access review, password hygiene and threat reports'),

-- ---- ENTERPRISE: prove it to somebody else -------------------------------
('security.webhooks',        'Security Webhooks',         4, 'Stream security events to a SIEM or endpoint'),
('security.tamper-evident',  'Tamper-evident Audit Trail',4, 'Hash-chained security events with verification'),
('security.api-keys',        'API Keys',                  4, 'Scoped service-account keys'),
('security.compliance-pack', 'Compliance Evidence Pack',  4, 'Dated bundle of security reports and posture history')

ON CONFLICT (feature_key) DO UPDATE SET
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;
