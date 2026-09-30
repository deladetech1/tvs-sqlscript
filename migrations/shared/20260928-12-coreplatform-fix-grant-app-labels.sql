-- =====================================================================================
-- Record which app each role grant was actually made against.
--
-- cp_assign_roles.resource_type is a label rather than a gate: permissions come from
-- cp_role_permissions by role_id, and the only code that reads this column is the frontends'
-- owner check, which looks for role-owner paired with rt-all.
--
-- The assign screens sent one request for the whole selection and labelled every role in it
-- with whichever app was picked first, so granting MyStoreGuard and LoanDrift roles together
-- filed both under LoanDrift. On saas-dev that left:
--
--     role-subscribed-app-msg-admin   labelled rt-subscribed-app-loandrift
--     role-zeloshr-employee-admin     labelled rt-user
--     role-msg-expenses-admin         labelled NULL
--
-- coreplatform-ft now splits the selection and sends one call per app, so nothing new is
-- written this way. This corrects what the old behaviour already wrote.
--
-- The scope is deliberately narrow: only roles whose id names an app, and only where the
-- label disagrees with that app. Two things are left alone on purpose:
--
--   * Core Platform's own roles. The existing rows say rt-organization while the assign
--     screens send rt-system-role. Both are in use, and choosing between them is a decision
--     about what the label means, not a repair of a grant that named the wrong app.
--   * Custom roles (rid_*). They belong to no app -- their permissions may well span several
--     -- so no value here would be more truthful than the one already stored.
--
-- Matching is on the role id, which is namespaced by app and never moves. Resource types
-- would be the wrong test: rt-expenses and rt-file are Core Platform types that MyStoreGuard
-- and LoanDrift re-parent under themselves when their seeds run.
--
-- Safe to rerun: it only writes rows whose label already disagrees, so a second run updates
-- nothing.
-- =====================================================================================

DO $$
DECLARE
    v_updated integer;
BEGIN
    IF to_regclass('core_platform.cp_assign_roles') IS NULL
       OR to_regclass('core_platform.cp_roles') IS NULL THEN
        RAISE NOTICE 'cp_assign_roles/cp_roles not present; nothing to do';
        RETURN;
    END IF;

    WITH app_of_role AS (
        SELECT
            id AS role_id,
            CASE
                WHEN id LIKE 'role-msg-%'
                  OR id LIKE 'role-subscribed-app-msg%'
                    THEN 'rt-subscribed-app-msg'
                WHEN id LIKE 'role-loandrift-%'
                  OR id LIKE 'role-subscribed-app-loandrift%'
                    THEN 'rt-subscribed-app-loandrift'
                WHEN id LIKE 'role-zeloshr-%'
                  OR id LIKE 'role-subscribed-app-zeloshr%'
                    THEN 'rt-subscribed-app-zeloshr'
            END AS expected
        FROM core_platform.cp_roles
    )
    UPDATE core_platform.cp_assign_roles ar
       SET resource_type = a.expected
      FROM app_of_role a
     WHERE ar.role_id = a.role_id
       AND a.expected IS NOT NULL
       AND ar.delete_status = 'NOT_DELETED'
       AND ar.resource_type IS DISTINCT FROM a.expected;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE 'cp_assign_roles: % grant label(s) corrected', v_updated;
END $$;
