-- Office retires the three R0 apps it replaces: app-docs, app-sheets and app-slides.
--
-- The owner's decision (2026-11-10): one suite, one subscription, one domain (app-office,
-- 20261110-01/-02). The R0 apps (20261109-01..06) reached dev only: master is prod and never ran
-- them, and their cloud units were never applied. So on prod, and on any fresh database, every
-- statement below finds nothing and does nothing. On a database that ran R0 (saas-dev, local
-- templates) it removes every trace of them:
--
--   * user and subscription rows that point at the apps (assignments of their roles, business-app
--     locations, subscriptions and their history, business apps, bundle entries, unlock grants,
--     the user's last place and view preferences);
--   * the registry: grants (the roles' own and anyone else's grant of their permissions), roles,
--     permissions and overrides, resource types, features, tier prices (meter prices cascade),
--     cp_app_schemas, cp_app_data_owners, the activity-log retention rows, pending purges;
--   * the website and API route rows, and the labels "sheets" and "slides" this pair inserted;
--   * the cp_apps rows (the seed no longer creates them); if something we do not delete still
--     points at one (a billing record, say), the row is kept, inactive and deprecated, and the
--     deploy goes on;
--   * then the schemas docs, sheets and slides, CASCADE.
--
-- Guard: the schemas are dropped only when their *_documents tables are empty. Unused beta data
-- only; a file someone stored is never dropped silently. If one holds rows, this file RAISES
-- before it changes anything, and a person decides (move the files to office, or empty them).
--
-- The label "docs": 20261005-08 holds it as "documentation"; 20261109-01 gave it to the Docs app.
-- That reservation is restored here; the row is never deleted (the word stays held).
--
-- Runs after the R0 files, which are no-ops now (their bodies were replaced: nothing re-creates
-- what this file removes). The seed and 20260929-11 still name the R0 prefixes, so that on the
-- deploy that retires them (seed first, shared files after) their grants do not read as leaks.
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R1-suite.md §3. Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= the guard
DO $$
DECLARE
    t text;
    n bigint;
BEGIN
    FOREACH t IN ARRAY ARRAY['docs.dc_documents', 'sheets.sh_documents', 'slides.sl_documents'] LOOP
        IF to_regclass(t) IS NOT NULL THEN
            EXECUTE format('SELECT count(*) FROM %s', t) INTO n;
            IF n > 0 THEN
                RAISE EXCEPTION 'office: % holds % file(s); the R0 app is not retired while it holds files. Move them to office.of_documents or empty it, then deploy again', t, n
                    USING ERRCODE = 'restrict_violation';
            END IF;
        END IF;
    END LOOP;
END $$;

-- What is retired, named once. Temporary: gone at COMMIT.
CREATE TEMP TABLE IF NOT EXISTS r0_apps (app_id text PRIMARY KEY, key text NOT NULL) ON COMMIT DROP;
INSERT INTO r0_apps VALUES ('app-docs', 'docs'), ('app-sheets', 'sheets'), ('app-slides', 'slides')
ON CONFLICT DO NOTHING;

CREATE TEMP TABLE IF NOT EXISTS r0_roles ON COMMIT DROP AS
SELECT r.id FROM core_platform.cp_roles r
 WHERE r.id IN ('role-subscribed-app-docs-admin',   'role-docs-editor',   'role-docs-viewer',
                'role-subscribed-app-sheets-admin', 'role-sheets-editor', 'role-sheets-viewer',
                'role-subscribed-app-slides-admin', 'role-slides-editor', 'role-slides-viewer');

CREATE TEMP TABLE IF NOT EXISTS r0_permissions ON COMMIT DROP AS
SELECT p.id FROM core_platform.cp_permissions p
 WHERE p.id ~ '^permission-(docs|sheets|slides)-(documents|folders|library)-[a-z]+$';

CREATE TEMP TABLE IF NOT EXISTS r0_resource_types ON COMMIT DROP AS
SELECT t.id FROM core_platform.cp_resource_types t
 WHERE t.id IN ('rt-subscribed-app-docs',   'rt-docs-documents',   'rt-docs-folders',   'rt-docs-library',
                'rt-subscribed-app-sheets', 'rt-sheets-documents', 'rt-sheets-folders', 'rt-sheets-library',
                'rt-subscribed-app-slides', 'rt-slides-documents', 'rt-slides-folders', 'rt-slides-library');

-- ================================================== who held the apps, and their places
-- Each table only if this database has it; a table without app_id is skipped.
DO $$
DECLARE
    t text;
    n bigint;
BEGIN
    DELETE FROM core_platform.cp_assign_roles WHERE role_id IN (SELECT id FROM r0_roles);
    FOREACH t IN ARRAY ARRAY[
        'core_platform.cp_business_app_locations',      -- before cp_business_apps (RESTRICT)
        'core_platform.cp_app_subscriptions',
        'core_platform.cp_app_subscription_histories',
        'core_platform.cp_app_subscription_period_audit_logs',
        'core_platform.cp_business_apps',
        'core_platform.cp_bundle_apps',
        'core_platform.cp_app_unlock_grants',
        'core_platform.cp_user_last_places',
        'core_platform.cp_user_view_preferences',
        'core_platform.cp_app_data_purges',
        'core_platform.cp_activity_log_retention_settings',
        'core_platform.cp_activity_log_sources',
        'core_platform.cp_app_data_owners',
        'core_platform.cp_app_schemas',
        'core_platform.cp_app_feature_catalog',
        'core_platform.cp_app_tier_configs'             -- cp_app_tier_meter_prices cascade
    ] LOOP
        IF to_regclass(t) IS NOT NULL AND EXISTS (
               SELECT 1 FROM information_schema.columns
                WHERE table_schema || '.' || table_name = t AND column_name = 'app_id') THEN
            EXECUTE format('DELETE FROM %s WHERE app_id IN (SELECT app_id FROM r0_apps)', t);
            GET DIAGNOSTICS n = ROW_COUNT;
            IF n > 0 THEN
                RAISE NOTICE 'office: removed % row(s) of the R0 apps from %', n, t;
            END IF;
        END IF;
    END LOOP;
END $$;

-- ============================================================ grants, roles, permissions
DELETE FROM core_platform.cp_role_permissions
 WHERE role_id IN (SELECT id FROM r0_roles)
    OR permission_id IN (SELECT id FROM r0_permissions);

DELETE FROM core_platform.cp_roles WHERE id IN (SELECT id FROM r0_roles);

DELETE FROM core_platform.cp_permission_overrides
 WHERE resource_type_id IN (SELECT id FROM r0_resource_types);

DELETE FROM core_platform.cp_permissions WHERE id IN (SELECT id FROM r0_permissions);

-- Resource types: anything else that names one goes first (activity-log rows, shared resource ids,
-- resources), then the children, then the parents.
DELETE FROM core_platform.cp_activity_logs     WHERE resource_type    IN (SELECT id FROM r0_resource_types);
DELETE FROM core_platform.cp_shared_resource_ids WHERE resource_type_id IN (SELECT id FROM r0_resource_types);
DELETE FROM core_platform.cp_resources         WHERE resource_type_id IN (SELECT id FROM r0_resource_types);
DELETE FROM core_platform.cp_resource_types
 WHERE id IN (SELECT id FROM r0_resource_types) AND parent_resource_id IS NOT NULL;
DELETE FROM core_platform.cp_resource_types
 WHERE id IN (SELECT id FROM r0_resource_types);

-- ========================================================================= the apps
-- Removed outright when nothing we keep still points at them; otherwise kept, switched off.
DO $$
DECLARE
    a text;
BEGIN
    FOR a IN SELECT app_id FROM r0_apps LOOP
        BEGIN
            DELETE FROM core_platform.cp_apps WHERE id = a;
        EXCEPTION WHEN foreign_key_violation THEN
            UPDATE core_platform.cp_apps SET is_active = false, status = 'deprecated'
             WHERE id = a AND (is_active OR status IS DISTINCT FROM 'deprecated');
            RAISE NOTICE 'office: % is still referenced (%); kept inactive and deprecated', a, SQLERRM;
        END;
    END LOOP;
END $$;

-- ================================================================== routes and labels
DELETE FROM control_plane.ctl_tenant_routes
 WHERE host IN ('docs.dev.trovesuite.com',   'api.docs.dev.trovesuite.com',
                'sheets.dev.trovesuite.com', 'api.sheets.dev.trovesuite.com',
                'slides.dev.trovesuite.com', 'api.slides.dev.trovesuite.com')
   AND tenant_id IS NULL
   AND created_by IN ('migration 20261109-01', 'migration 20261109-03', 'migration 20261109-05');

-- "sheets" and "slides" were new words for R0 (nothing held them before): their rows go.
DELETE FROM control_plane.ctl_reserved_labels
 WHERE (label, created_by) IN (('sheets', 'migration:20261109-03'), ('slides', 'migration:20261109-05'));

-- "docs" goes back to what 20261005-08 held it for. Only the reason R0 wrote is put back, so a
-- reason someone sets later by hand is left alone.
UPDATE control_plane.ctl_reserved_labels
   SET reason = 'documentation'
 WHERE label = 'docs'
   AND reason = 'a product: docs.dev.trovesuite.com, Docs';

-- ======================================================================== the schemas
-- Empty by the guard above (their audit trails and empty tables go with them). A schema is dropped
-- only when every table in it carries its R0 prefix (dc_, sh_, sl_): a schema of the same name that
-- R0 did not make is refused, never dropped.
DO $$
DECLARE
    s   record;
    odd text;
BEGIN
    FOR s IN SELECT * FROM (VALUES ('docs', 'dc_'), ('sheets', 'sh_'), ('slides', 'sl_')) AS v(nsp, prefix)
              WHERE EXISTS (SELECT 1 FROM pg_namespace n WHERE n.nspname = v.nsp)
    LOOP
        SELECT string_agg(c.relname, ', ') INTO odd
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = s.nsp AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
           AND left(c.relname, length(s.prefix)) <> s.prefix;
        IF odd IS NOT NULL THEN
            RAISE EXCEPTION 'office: schema % holds tables R0 did not make (%); not dropped', s.nsp, odd;
        END IF;
        EXECUTE format('DROP SCHEMA %I CASCADE', s.nsp);
        RAISE NOTICE 'office: dropped the R0 schema %', s.nsp;
    END LOOP;
END $$;

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_apps WHERE id IN ('app-docs', 'app-sheets', 'app-slides') AND is_active) THEN
        RAISE EXCEPTION 'an R0 office app (app-docs, app-sheets, app-slides) is still active';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_permissions
                WHERE id ~ '^permission-(docs|sheets|slides)-(documents|folders|library)-') THEN
        RAISE EXCEPTION 'an R0 office permission is still registered';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_roles
                WHERE id ~ '^role-(docs|sheets|slides)-' OR id ~ '^role-subscribed-app-(docs|sheets|slides)-') THEN
        RAISE EXCEPTION 'an R0 office role is still registered';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('docs', 'sheets', 'slides')) THEN
        RAISE EXCEPTION 'an R0 office schema still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels
                WHERE label = 'docs' AND reason = 'a product: docs.dev.trovesuite.com, Docs') THEN
        RAISE EXCEPTION 'the reserved label "docs" still names the retired Docs app';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_apps WHERE id = 'app-office') THEN
        RAISE EXCEPTION 'app-office is missing: the R0 apps are retired only in favour of Office';
    END IF;
END $$;

COMMIT;
