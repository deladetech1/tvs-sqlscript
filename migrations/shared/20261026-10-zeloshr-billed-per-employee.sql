-- =====================================================================
-- ZelosHR is billed per employee, with a monthly minimum
-- ---------------------------------------------------------------------
-- The owner decided (2026-10-26) that ZelosHR is charged per employee per
-- month: USD 2 / 4 / 6 per employee on Basic / Advance / Premium (rate 12
-- as before), Enterprise stays a quote, and every plan is billed for at
-- least 10 employees a month. Nobody uses ZelosHR yet, so no live bill
-- changes.
--
-- cp_apps.billing_unit = 'EMPLOYEE' for app-zeloshr is set in
-- shared/20261022-70, which owns that column and its CHECK. This file adds:
--
-- 1. cp_app_tier_configs.min_units: "billed for at least this many units a
--    month". NULL = no minimum. Only an EMPLOYEE app reads it today.
--
-- 2. core_platform.fn_zeloshr_billable_employees(tenant, org, from, to):
--    the ONE counting rule. The backend bills
--        max(min_units, employees) x COALESCE(price_override, tier price)
--    per ZelosHR subscription and month, and when several businesses of one
--    organisation hold ZelosHR the org's employees count only on the oldest
--    subscription (that rule lives in the backend, billing_unit.employee_units).
--
-- 3. The price decision, applied ONCE per database the way 20261023-30
--    applies a decision (decision_key '2026-10-26-zeloshr-per-employee',
--    history rows in cp_price_list_changes, source MIGRATION). After that
--    the console owns the prices AND the minimum: a re-run never overwrites
--    a later console edit.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

-- ------------------------------------------------------- 1. the minimum
ALTER TABLE core_platform.cp_app_tier_configs
    ADD COLUMN IF NOT EXISTS min_units integer NULL;

ALTER TABLE core_platform.cp_app_tier_configs
    DROP CONSTRAINT IF EXISTS ck_cp_app_tier_configs_min_units;
ALTER TABLE core_platform.cp_app_tier_configs
    ADD CONSTRAINT ck_cp_app_tier_configs_min_units CHECK (min_units IS NULL OR min_units > 0);

COMMENT ON COLUMN core_platform.cp_app_tier_configs.min_units IS
    'Billed for at least this many units a month (an EMPLOYEE app: employees). NULL = no minimum. Owned by the Deladetech console after shared/20261026-10 first set it.';

-- The price list history records a change of the minimum too.
ALTER TABLE core_platform.cp_price_list_changes
    ADD COLUMN IF NOT EXISTS old_min_units integer;
ALTER TABLE core_platform.cp_price_list_changes
    ADD COLUMN IF NOT EXISTS new_min_units integer;

-- -------------------------------------------- 2. who counts as an employee
-- plpgsql with dynamic SQL, so it creates (and answers 0) on a database
-- that has no zeloshr schema, and works whichever of the history tables
-- exist yet.
--
-- An employee of (tenant, org) is billable for [p_from, p_to] when the row
-- is live (not deleted, not a draft, not pre-hire), they started on or
-- before p_to, and they are either still employed or left on or after
-- p_from. Their leaving date is the latest effective_date of a status
-- change INTO a departed status, else the latest last_working_day of an
-- offboarding case that was not cancelled; with no date at all they are
-- taken to have left before p_from (not counted).
CREATE OR REPLACE FUNCTION core_platform.fn_zeloshr_billable_employees(
    p_tenant_id text, p_org_id text, p_from date, p_to date)
RETURNS integer
LANGUAGE plpgsql STABLE AS $fn$
DECLARE
    departed_on text;
    n integer;
BEGIN
    IF to_regclass('zeloshr.zhr_employees') IS NULL
       OR p_tenant_id IS NULL OR p_org_id IS NULL OR p_from IS NULL OR p_to IS NULL THEN
        RETURN 0;
    END IF;

    departed_on := 'COALESCE('
        || CASE WHEN to_regclass('zeloshr.zhr_employee_status_changes') IS NOT NULL THEN
               '(SELECT max(sc.effective_date) FROM zeloshr.zhr_employee_status_changes sc'
            || ' WHERE sc.employee_id = e.id AND sc.tenant_id = e.tenant_id'
            || ' AND lower(sc.to_status) IN (''resigned'', ''terminated'', ''retired'', ''inactive''))'
           ELSE 'NULL::date' END
        || ', '
        || CASE WHEN to_regclass('zeloshr.zhr_offboarding_cases') IS NOT NULL THEN
               '(SELECT max(oc.last_working_day) FROM zeloshr.zhr_offboarding_cases oc'
            || ' WHERE oc.employee_id = e.id AND oc.tenant_id = e.tenant_id'
            || ' AND lower(COALESCE(oc.state, '''')) <> ''cancelled'')'
           ELSE 'NULL::date' END
        || ')';

    EXECUTE format($q$
        SELECT count(DISTINCT e.id)::integer
          FROM zeloshr.zhr_employees e
         WHERE e.tenant_id = $1
           AND e.org_id = $2
           AND NOT e.is_deleted
           AND NOT COALESCE(e.is_draft, false)
           AND lower(COALESCE(e.lifecycle_state, '')) <> 'pre-hire'
           AND COALESCE(e.employment_start_date, e.start_date, e.created_at::date) <= $4
           AND (lower(COALESCE(e.employment_status, ''))
                    NOT IN ('resigned', 'terminated', 'retired', 'inactive')
                OR %s >= $3)
    $q$, departed_on)
    INTO n
    USING p_tenant_id, p_org_id, p_from, p_to;

    RETURN COALESCE(n, 0);
END
$fn$;

COMMENT ON FUNCTION core_platform.fn_zeloshr_billable_employees(text, text, date, date) IS
    'How many ZelosHR employees of (tenant, org) are billable for the period [from, to]: live, not draft, not pre-hire, started by "to", and employed or left on/after "from". The one counting rule behind per-employee billing (shared/20261026-10).';

-- Granted like the other core_platform functions: callable by every role
-- (the default), and SECURITY INVOKER, so it reads only what the caller
-- may read. Stated so a database whose defaults differ still has it.
GRANT EXECUTE ON FUNCTION core_platform.fn_zeloshr_billable_employees(text, text, date, date) TO PUBLIC;

-- --------------------------------- 3. the 2026-10-26 decision, once
DO $$
DECLARE
    applied int := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_price_list_changes
                WHERE decision_key = '2026-10-26-zeloshr-per-employee') THEN
        RAISE NOTICE '20261026-10: the 2026-10-26 ZelosHR prices were applied here already; the console owns them now';
        RETURN;
    END IF;

    -- price NULL = leave the price as it is (Enterprise is a quote).
    CREATE TEMP TABLE _zhr_prices (id text PRIMARY KEY, price numeric, min_units integer)
        ON COMMIT DROP;
    INSERT INTO _zhr_prices VALUES
        ('tier-cfg-zhr-basic',      2.00, 10),
        ('tier-cfg-zhr-advance',    4.00, 10),
        ('tier-cfg-zhr-premium',    6.00, 10),
        ('tier-cfg-zhr-enterprise', NULL, 10);

    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, app_id, subscription_id, old_price, new_price, old_rate, new_rate,
         old_max_login_users, new_max_login_users, old_min_units, new_min_units,
         reason, changed_by, source, decision_key)
    SELECT 'APP_TIER', c.id, c.app_id, c.subscription_id,
           c.price, COALESCE(v.price, c.price), c.rate, c.rate,
           c.max_login_users, c.max_login_users, c.min_units, v.min_units,
           'Owner decision 2026-10-26: ZelosHR priced per employee per month, minimum 10 employees',
           'migration:20261026-10', 'MIGRATION', '2026-10-26-zeloshr-per-employee'
      FROM core_platform.cp_app_tier_configs c
      JOIN _zhr_prices v ON v.id = c.id;

    UPDATE core_platform.cp_app_tier_configs c
       SET price = COALESCE(v.price, c.price), min_units = v.min_units
      FROM _zhr_prices v
     WHERE v.id = c.id
       AND (c.price, c.min_units) IS DISTINCT FROM (COALESCE(v.price, c.price), v.min_units);
    GET DIAGNOSTICS applied = ROW_COUNT;

    RAISE NOTICE '20261026-10: recorded the 2026-10-26 ZelosHR prices (% tier row(s) changed here)', applied;
END $$;

-- ----------------------------------------------------------- invariants
DO $$
BEGIN
    -- The function answers on any database: 0 for an org with no staff.
    IF core_platform.fn_zeloshr_billable_employees('-', '-', current_date, current_date) <> 0 THEN
        RAISE EXCEPTION 'fn_zeloshr_billable_employees counted employees of a tenant that does not exist';
    END IF;

    -- (No assertion over the tier rows: the console owns them after the
    -- decision, and a row seeded after it is legitimately untouched.)
END $$;

COMMIT;
