-- Endpoints re-gated onto the resources that exist for them, and nobody loses access
--
-- Fifty-five of the 502 permissions were enforced by no endpoint anywhere, and in the other
-- direction several endpoints were gated on a resource borrowed from somewhere else. The two
-- are the same defect seen from each end: a permission that names nothing, and a screen whose
-- guard names the wrong thing.
--
-- The clearest case was expenses. Core Platform has an `expense` resource with five
-- permissions, and two roles built on it -- Expense Administrator and Expense Officer, each
-- holding all five. Every expense endpoint checked `settings` instead. So neither role could
-- manage an expense, and anyone who could change a setting could.
--
-- Re-gated here, with the grants that keep it working:
--
--   coreplatform  expenses            settings        -> expense
--   loandrift     approval workflow   settings        -> approval
--   loandrift     penalty settings    penalty         -> penalty-settings
--   loandrift     penalty waivers     penalty         -> penalty-waive
--
-- The penalty waivers gain a real separation the catalogue already described and the code did
-- not: requesting a waiver is penalty-waive|request and approving or rejecting one is
-- penalty-waive|approve. Whoever could do each of those through the penalty permissions keeps
-- being able to.
--
-- Every role that held the old permission is granted the new one, so this changes what the
-- system CALLS an authority and not who has it. The roles named for these resources gain the
-- access their names always promised.
--
-- Still unenforced afterwards, deliberately:
--   ''|currency         reference data, ungated in all three apps earlier today
--   ''|app              part of the six-permission nav block every role holds
--   loandrift|calendar  no endpoint exists; the repayment calendar is computed, not served

BEGIN;

-- Whoever can change settings today can manage expenses today. Keep that true.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT DISTINCT rp.tenant_id, rp.role_id, want.id,
       r.role_name || ' can ' || lower(want.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_role_permissions rp
  JOIN core_platform.cp_roles r ON r.id = rp.role_id AND r.delete_status = 'NOT_DELETED'
  JOIN core_platform.cp_permissions had ON had.id = rp.permission_id
  JOIN core_platform.cp_permissions want
    ON want.app_prefix = had.app_prefix
   AND want.action = had.action
   AND want.delete_status = 'NOT_DELETED' AND want.is_active
   AND want.resource_key = CASE
         WHEN had.app_prefix = ''         AND had.resource_key = 'settings' THEN 'expense'
         WHEN had.app_prefix = 'loandrift' AND had.resource_key = 'settings' THEN 'approval'
         WHEN had.app_prefix = 'loandrift' AND had.resource_key = 'penalty'  THEN 'penalty-settings'
       END
 WHERE rp.delete_status = 'NOT_DELETED'
   AND had.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- Waivers: requesting used penalty|create, approving used penalty|waive.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT DISTINCT rp.tenant_id, rp.role_id, want.id,
       r.role_name || ' can ' || lower(want.permission_name),
       CURRENT_DATE::text, CURRENT_TIME::text, now()
  FROM core_platform.cp_role_permissions rp
  JOIN core_platform.cp_roles r ON r.id = rp.role_id AND r.delete_status = 'NOT_DELETED'
  JOIN core_platform.cp_permissions had ON had.id = rp.permission_id
  JOIN core_platform.cp_permissions want
    ON want.app_prefix = 'loandrift' AND want.resource_key = 'penalty-waive'
   AND want.delete_status = 'NOT_DELETED' AND want.is_active
   AND want.action = CASE had.action WHEN 'create' THEN 'request' WHEN 'waive' THEN 'approve' END
 WHERE rp.delete_status = 'NOT_DELETED'
   AND had.app_prefix = 'loandrift' AND had.resource_key = 'penalty'
   AND had.action IN ('create', 'waive')
   AND had.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE
    expense_roles integer;
    waive_roles   integer;
BEGIN
    -- The roles named for expenses must now be able to reach an expense endpoint, which is
    -- the whole point: before this they held five expense permissions and nothing checked one.
    SELECT count(DISTINCT rp.role_id) INTO expense_roles
      FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE p.app_prefix = '' AND p.resource_key = 'expense'
       AND rp.delete_status = 'NOT_DELETED';

    SELECT count(DISTINCT rp.role_id) INTO waive_roles
      FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE p.app_prefix = 'loandrift' AND p.resource_key = 'penalty-waive'
       AND rp.delete_status = 'NOT_DELETED';

    IF expense_roles = 0 THEN
        RAISE EXCEPTION 'no role holds an expense permission; the re-gated endpoints would be owner-only';
    END IF;
    IF waive_roles = 0 THEN
        RAISE EXCEPTION 'no role holds a penalty-waive permission; waivers would be owner-only';
    END IF;

    RAISE NOTICE 'expense held by % role(s), penalty-waive by % role(s)', expense_roles, waive_roles;
END $$;

COMMIT;
