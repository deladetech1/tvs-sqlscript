-- Somewhere for suspicious things to land.
--
-- The login security work of 20260924-01 produces events — an account locked, a
-- sign-in refused, a password expired — and there is nowhere to see them. A
-- lockout is visible only if an admin happens to open that one user's detail
-- page. A burst of failed sign-ins is visible only to somebody who thinks to
-- filter the sign-in history by an action they would have to know exists.
-- Nothing in the suite answers "is anything wrong right now".
--
-- Meanwhile MyStoreGuard and LoanDrift each produce their own risk signals — a
-- return caught by the fraud-velocity rule, a waived penalty, a manual
-- credit-score override, stock that has gone negative — and every one of them
-- dies inside the app that noticed it.
--
-- cp_security_events is where all of it goes.
--
--
-- One central table, not a table per app
--
-- There are two live precedents in this schema and they disagree. Sign-in
-- history went the mirror route: CorePlatform has cp_login_audit_logs and
-- MyStoreGuard got its own msg_login_audit_logs in 20260824-01. cp_sms_messages
-- went the other way — one table, an app_id column, and each app writing its
-- own rows into it.
--
-- A security dashboard has to show one list across every app, so the mirror
-- route would mean a UNION over a set of tables that grows every time an app is
-- added, and a triage status that cannot be stored in the same place twice.
-- This follows cp_sms_messages: app_id discriminator, nullable org/bus, a jsonb
-- payload for whatever the event needs to carry, and each app writing directly.
-- The grants come for free — ALTER DEFAULT PRIVILEGES already gives the
-- tvs_app_<env> group DML on anything tvs_migrator creates here.
--
--
-- Why there is no EF migration alongside this
--
-- Every table of this kind is shared-SQL only: cp_sms_messages, every
-- *_audit_logs table, cp_subscription_platform_limits, cp_activity_log_sources.
-- EF owns the entity tables; the append-only trails and the platform's own
-- bookkeeping live here. This follows them.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. The events.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_security_events (
    id                text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text        NOT NULL,
    -- Nullable: a failed sign-in belongs to a tenant, not to a business. App
    -- events usually carry both.
    org_id            text,
    bus_id            text,

    -- app-coreplatform | app-mystoreguard | app-loandrift. Which app noticed,
    -- so a tenant running three of them can still tell them apart.
    app_id            text        NOT NULL,

    -- Broad grouping for the dashboard's filters (AUTHENTICATION,
    -- ACCESS_CONTROL, FINANCIAL, INVENTORY, DATA_INTEGRITY, CONFIGURATION).
    category          text        NOT NULL,
    -- The specific thing that happened: account_locked, login_denied_schedule,
    -- return_fraud_flagged, penalty_waived, … Free text rather than a CHECK,
    -- because the apps that write it deploy independently of this schema and a
    -- constraint here would turn a new event type into a failed insert in an
    -- app that has nothing to do with the constraint.
    event_type        text        NOT NULL,
    severity          text        NOT NULL DEFAULT 'WARNING',

    title             text        NOT NULL,
    description       text,

    -- Who did it, and who it was done to. Often the same person (somebody
    -- failing their own sign-in); often not (an admin waiving a penalty).
    actor_user_id     text,
    actor_name        text,
    subject_user_id   text,
    subject_name      text,

    -- Promoted out of metadata into columns of their own because the dashboard
    -- filters and groups by them — "five failures from one address" is the
    -- question, and it cannot be asked of a jsonb key without a functional index.
    ip_address        text,
    user_agent        text,

    metadata          jsonb,

    -- When the thing happened, as distinct from when the row was written. An
    -- app that batches its detection (a nightly negative-stock sweep) reports
    -- an occurred_at well before its cdatetime.
    occurred_at       timestamptz NOT NULL DEFAULT now(),

    -- ---- Triage ------------------------------------------------------
    -- A dashboard nobody can clear becomes a dashboard everybody ignores. The
    -- question an admin actually has is not "what happened" but "has anyone
    -- looked at this yet".
    status            text        NOT NULL DEFAULT 'OPEN',
    status_note       text,
    status_changed_by text,
    status_changed_at timestamptz,

    cdate             text,
    ctime             text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_cp_security_events_severity
        CHECK (severity IN ('CRITICAL', 'WARNING', 'INFO')),
    CONSTRAINT ck_cp_security_events_status
        CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED'))
);

-- No foreign key to cp_users or cp_tenants, on purpose and for the same reason
-- cp_login_audit_logs has none: the record of what somebody did must outlive
-- the row that says who they were. Deleting a user must not delete the evidence.

-- The feed, newest first — the dashboard's default query.
CREATE INDEX IF NOT EXISTS idx_cp_security_events_scope
    ON core_platform.cp_security_events (tenant_id, cdatetime DESC);
-- "What is still open, worst first" — the query behind the counter tiles.
CREATE INDEX IF NOT EXISTS idx_cp_security_events_triage
    ON core_platform.cp_security_events (tenant_id, status, severity);
-- Per-app filtering and the by-app chart.
CREATE INDEX IF NOT EXISTS idx_cp_security_events_app
    ON core_platform.cp_security_events (tenant_id, app_id, cdatetime DESC);
-- Everything that has ever happened to one person, for the drill-down the
-- users list links into.
CREATE INDEX IF NOT EXISTS idx_cp_security_events_subject
    ON core_platform.cp_security_events (tenant_id, subject_user_id, cdatetime DESC);


-- =====================================================================
-- 2. Retention: joining the purge without being named for it.
-- =====================================================================
-- cp_discover_activity_log_sources() finds tables matching '%_audit_logs'.
-- This is not one — it is not an audit trail of an entity, it has a severity
-- and a triage state — so discovery would never see it and it would grow
-- without limit. It would not even be reported by
-- cp_nonconforming_activity_log_tables(), which matches '%audit%' or
-- '%_activity_logs'. It would simply be invisible to the whole retention
-- feature.
--
-- Renaming it to fit the convention would be the wrong fix: it would inherit
-- the tenant's ordinary log retention, and a tenant that keeps thirty days of
-- activity logs has not thereby decided to destroy their security evidence
-- after thirty days.
--
-- So it is registered by hand. The purge loop takes its worklist from
-- cp_activity_log_sources and never re-checks the name, and it deletes where
--     cdatetime < LEAST(tenant_cutoff, now() - min_retention_days)
-- LEAST picks the earlier instant, so min_retention_days is a floor on age:
-- whatever the tenant sets, a security event younger than a year is never
-- purged.
INSERT INTO core_platform.cp_activity_log_sources
    (schema_name, table_name, app_id, has_org_id, has_bus_id, min_retention_days)
VALUES
    ('core_platform', 'cp_security_events', 'app-coreplatform', true, true, 365)
ON CONFLICT (schema_name, table_name) DO UPDATE SET
    app_id             = EXCLUDED.app_id,
    has_org_id         = EXCLUDED.has_org_id,
    has_bus_id         = EXCLUDED.has_bus_id,
    min_retention_days = EXCLUDED.min_retention_days;


-- =====================================================================
-- 3. The dashboard is a premium feature.
-- =====================================================================
-- A boolean on cp_subscription_platform_limits, exactly like groups_enabled,
-- rather than a row in cp_app_feature_catalog.
--
-- The catalog cannot express this. Its rows are keyed on an app_id that must
-- appear in cp_app_subscriptions, and Core Platform is not a subscribable app —
-- there is no cp_app_subscriptions row for it and no tier-config row either. A
-- catalog entry for it would join to nothing and resolve for no tenant, ever.
--
-- The tier that decides this is the DERIVED one from cp_tenant_platform_limits:
-- the highest tier across the tenant's entitled app subscriptions. Paying
-- PREMIUM for one app buys the security dashboard for the hub, which is the
-- same rule already applied to hub capacity.
ALTER TABLE core_platform.cp_subscription_platform_limits
    ADD COLUMN IF NOT EXISTS security_dashboard_enabled boolean NOT NULL DEFAULT false;

UPDATE core_platform.cp_subscription_platform_limits
   SET security_dashboard_enabled = true
 WHERE subscription_id IN ('shared-subscription-premium',
                           'shared-subscription-enterprise')
   AND security_dashboard_enabled IS DISTINCT FROM true;

-- Explicit rather than relying on the DEFAULT, so re-running this file after
-- somebody has hand-edited a row puts it back.
UPDATE core_platform.cp_subscription_platform_limits
   SET security_dashboard_enabled = false
 WHERE subscription_id IN ('shared-subscription-basic',
                           'shared-subscription-advance')
   AND security_dashboard_enabled IS DISTINCT FROM false;


-- The view has to be recreated to carry the new column. CREATE OR REPLACE
-- cannot add a column to an existing view, so it is dropped first — nothing
-- depends on it but application code, which reads it by name at request time.
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
       COALESCE(l.groups_enabled, false)                                AS groups_enabled,
       -- COALESCE to false: a tenant whose subscription has no limits row at
       -- all does not get a paid feature by accident.
       COALESCE(l.security_dashboard_enabled, false)                    AS security_dashboard_enabled
FROM core_platform.cp_tenants t
LEFT JOIN best b
       ON b.tenant_id = t.id
LEFT JOIN core_platform.cp_subscriptions s
       ON s.id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic')
LEFT JOIN core_platform.cp_subscription_platform_limits l
       ON l.subscription_id = COALESCE(b.shared_subscription_id, 'shared-subscription-basic');


-- =====================================================================
-- 4. Who may see it.
-- =====================================================================
-- parent_resource_id NULL: this is a core-platform resource type, not one
-- hanging off a subscribed app. App seeds re-parent the types they own, and a
-- non-NULL parent here would put it in their reach.
INSERT INTO core_platform.cp_resource_types
    (id, resource_type_name, description, parent_resource_id)
VALUES
    ('rt-security', 'Security', 'Security dashboard, events and posture', NULL)
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;

-- Un-prefixed permission ids, deliberately. 04_others.sql grants Core Platform
-- Admin by selecting over the permission namespace rather than by resource
-- type, and it identifies core-platform permissions as the ones with no app
-- prefix. Naming these permission-security-* rather than permission-cp-security-*
-- is what makes an existing admin pick them up without editing that seed.
INSERT INTO core_platform.cp_permissions
    (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
VALUES
    ('permission-security-get', 'Security Get', 'rt-security',
     'Can view the security dashboard, its events and posture',
     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
    -- Triage only. Deliberately not a -delete: somebody who can erase a
    -- security event is not somebody the events can be trusted about, which is
    -- the same reasoning 04_others.sql gives for withholding activity-log
    -- deletion from administrators.
    ('permission-security-update', 'Security Update', 'rt-security',
     'Can acknowledge and resolve security events',
     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;
