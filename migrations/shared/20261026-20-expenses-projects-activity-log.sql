-- Activities in Expenses and Projects: the plan feature behind each app's new Activities page.
--
-- Every TroveSuite app now opens with Dashboard and then Activities -- everything that
-- happened in the app, newest first, read from the audit trail it already keeps
-- (expenses.exp_audit_logs, projects.prj_audit_logs). The CRM sells its feed as
-- crm.audit-trail and Invoicing as invoicing.activity-log, both PREMIUM (20261022-75);
-- Expenses and Projects follow them. The API gates GET /<app>/v1/activity on these keys
-- (tvs-shared-apps-bk internal/apps/<app>/plan.go) and the menus show a padlock below PREMIUM.
--
-- The permission already exists: expenses|logs|get (20261019-26) and projects|logs|get
-- (20261016-01), the same "logs" concept the CRM and Invoicing gate their feeds on.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('expenses.activity-log', 'app-expenses', 'Activity Log', 3, 'Every change across Expenses, who made it and when'),
('projects.activity-log', 'app-projects', 'Activity Log', 3, 'Every change across Projects, who made it and when')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

DO $$
BEGIN
    IF (SELECT count(*) FROM core_platform.cp_app_feature_catalog
         WHERE feature_key IN ('expenses.activity-log', 'projects.activity-log')
           AND min_tier_rank = 3 AND is_active) <> 2 THEN
        RAISE EXCEPTION 'the Expenses and Projects activity logs must be active PREMIUM features';
    END IF;
END $$;

COMMIT;
