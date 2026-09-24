-- Grace was keeping you writing but not keeping you on your plan.
--
-- 20260821-01 built cp_tenant_platform_limits to mirror check_subscription_active()
-- in auth.py "minus the grace period", and said so in its own header: "grace keeps
-- you writing, it does not keep you on PREMIUM." That was deliberate. It is being
-- reversed, on purpose, and this file is the new decision.
--
-- What it looked like in practice
--
-- A LoanDrift client on PREMIUM, paying by Mobile Money, on time, twice. Their
-- billing period ends at 18:27. At 18:27 they drop to BASIC — Groups disappears,
-- the platform caps tighten — and their bill for the next period is not raised
-- until 01:00 the following morning. They are downgraded roughly seven hours
-- BEFORE the system asks them for any money, for a payment method the platform
-- fully supports.
--
-- Meanwhile check_subscription_active still lets them write for four more days,
-- and send_card_grace_reminders emails them to say they are in grace. So the
-- platform simultaneously told them they were fine and took their features away.
--
-- Splitting grace across the two checks makes no sense from the client's side.
-- Either a late payment is tolerated for four days or it is not. Now it is, for
-- both: the same window, the same rule, both halves in agreement.
--
-- What this does NOT change
--
-- The bill. A lapsed period still raises a PENDING billing row, that row is still
-- owed, and renewal still requires it to be paid. Nobody gets four free days —
-- they get four days to pay for days they are still being charged for. The only
-- thing that moves is when the features switch off, and it moves to exactly where
-- the write-block already was.
--
-- The grace window itself
--
-- Four days, matching SUBSCRIPTION_GRACE_DAYS in both app/src/configs/settings.py
-- and func/shared/settings.py. It is written as a literal here because a view
-- cannot read an environment variable. THE THREE MUST CHANGE TOGETHER: if the env
-- var moves and this does not, the tier and the write-block go back to disagreeing,
-- which is the bug this file exists to close.
--
-- Trials get the same treatment, for the same reason — check_subscription_active
-- already grants trials the grace window, and the view did not.
--
-- Idempotent; safe to re-run on every deploy. DROP before CREATE, per the note in
-- 20260821-01: a later file may add a column and CREATE OR REPLACE cannot.


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
            -- In trial, or inside the grace window after it ended.
         OR (aps.status = 'TRIALING'
             AND (t.free_trial_ends_at IS NULL
                  OR t.free_trial_ends_at + make_interval(days => 4) > now()))
            -- Paid period still running, or inside the grace window after it
            -- ended. PAST_DUE sits here with ACTIVE deliberately: it means "we
            -- know this is unpaid", not "this is cut off", and the period end
            -- plus grace is what decides either way.
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
