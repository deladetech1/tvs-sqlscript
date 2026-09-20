-- Suspending twenty people is one decision, not twenty.
--
-- cp_login_settings has always had a group_id column beside user_id, and both
-- places that read it — the login flow and AuthService.authorize, which runs on
-- every request — have always matched on `user_id = ? OR group_id = ANY(?)`.
-- Nothing ever wrote a group row, so the branch was dead code. An admin who
-- wanted to lock out a department, or require MFA of everyone handling money,
-- had to walk the member list and hope they finished.
--
-- Two things were missing, and only one of them is SQL.
--
-- The one that is not: those queries ended `ORDER BY user_id NULLS LAST LIMIT 1`
-- — one row wins, and the user's own row always beats the group's. Since every
-- user granted login access gets a user row, a group row would have been read
-- for nobody. That is fixed in LoginSettingsResolver (tvs-package), where the
-- two security switches now take the most restrictive value across the user and
-- all their groups, while the schedule still comes from the user's own row.
--
-- The one that is: the right to do it. Suspending a group and requiring MFA of
-- a group are not the same right as renaming one, so they do not come free with
-- Group Update — they are their own permissions, inserted here so the
-- resource-type trigger hands them to the roles that already hold the rest of
-- the rt-group set. An owner who wants to withhold them takes them away.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. One settings row per group.
-- =====================================================================
-- The resolver reads "the group's row", singular. Nothing stopped a second one
-- existing, and two rows disagreeing about whether a group is suspended is not
-- a question anybody should have to answer at login time. Partial, so it
-- constrains group rows only and leaves the per-user rows alone.
--
-- The EF migration AddGroupLoginSettingsUniqueIndex creates this too, and EF runs
-- before this folder, so on a normal deploy the statement below finds it already
-- there. It is repeated here for anyone applying the shared SQL on its own.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_login_settings_group_tenant
    ON core_platform.cp_login_settings (group_id, tenant_id)
    WHERE group_id IS NOT NULL AND delete_status = 'NOT_DELETED';


-- =====================================================================
-- 2. The two rights.
-- =====================================================================
INSERT INTO core_platform.cp_permissions
    (id, permission_name, description, resource_type_id,
     delete_status, is_active, cdate, ctime, cdatetime)
VALUES
    ('permission-group-login-settings-get',
     'Group Login Settings Get',
     'Can see whether a group is suspended and whether it requires multi-factor '
     'authentication of its members',
     'rt-group',
     'NOT_DELETED', true,
     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

    ('permission-group-login-settings-update',
     'Group Login Settings Update',
     'Can suspend a whole group at once, and require multi-factor authentication '
     'of every member. Held apart from Group Update because it locks people out '
     'rather than changing what is written about the group',
     'rt-group',
     'NOT_DELETED', true,
     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;
