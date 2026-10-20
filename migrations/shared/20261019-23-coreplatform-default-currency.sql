-- =====================================================================
-- Core Platform: every tenant starts with one default currency
-- ---------------------------------------------------------------------
-- Tenants were created with no currencies at all, and apps such as Invoicing
-- now only let a business use the currencies set up in Core Platform -- so a
-- new tenant had nothing to offer. Signup now inserts one (lp_service.signup
-- -> settings_service.seed_default_currency); this gives the same row to every
-- tenant that already exists without one.
--
-- WHICH CURRENCY. The business's country if one were known -- but neither
-- signup nor cp_businesses / cp_organizations / cp_tenants records a country,
-- so it is the platform default: USD, US Dollar, $, 2 decimals, the same row
-- signup writes. (The first version of this file used GHS; a row it made that
-- nothing has used yet is switched to USD below.)
--
-- RE-RUNS EVERY DEPLOY, so it must be a no-op the second time and must never
-- put a currency back that a tenant has dealt with:
--   * only a tenant with NO NOT_DELETED currency is touched -- one that has
--     added, renamed or re-defaulted any currency is left alone;
--   * the id is deterministic ('cur-default-' || tenant_id) and the insert is
--     ON CONFLICT DO NOTHING, so the PK and the (tenant_id, code) unique index
--     both stop a duplicate -- including a tenant whose GHS row is soft-deleted.
--
-- created_by is NULL: there is no user to attribute a system row to, and the
-- column's foreign key to cp_users allows it.
--
-- Idempotent; safe to re-run.
-- =====================================================================
BEGIN;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_currencies') IS NULL
       OR to_regclass('core_platform.cp_tenants') IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO core_platform.cp_currencies
        (id, tenant_id, name, code, symbol, country, decimal_places,
         thousand_separator, decimal_separator, currency_position, locale,
         minor_unit_name, is_default, exchange_rate, exchange_rate_source,
         description, is_active, delete_status, cdate, ctime, cdatetime, created_by)
    SELECT 'cur-default-' || t.id, t.id, 'US Dollar', 'USD', '$', 'United States', 2,
           ',', '.', 'before', 'en-US',
           'cents', true, 1, 'manual',
           'Default currency', true, 'NOT_DELETED',
           -- cdate/ctime in Helper.current_date_time's display form, in UTC
           -- ("Sunday 18th October, 2026", "02:03 PM").
           to_char(now() AT TIME ZONE 'UTC', 'FMDay FMDDth FMMonth, YYYY'),
           to_char(now() AT TIME ZONE 'UTC', 'HH12:MI AM'), now(), NULL
    FROM core_platform.cp_tenants t
    WHERE coalesce(t.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
      -- The platform's own tenant (system roles live there) is not a business.
      AND t.id <> 'system-tenant-id'
      AND NOT EXISTS (
          SELECT 1 FROM core_platform.cp_currencies c
          WHERE c.tenant_id = t.id AND c.delete_status = 'NOT_DELETED')
    ON CONFLICT DO NOTHING;

    -- The first version gave GHS. A row it made is switched to USD while nothing
    -- uses it: no MyStoreGuard delivery names it, no Invoicing record bills in
    -- GHS, and the tenant has no USD of its own. Once switched (or once used) it
    -- is left alone, so a re-run never rewrites a currency someone relies on.
    UPDATE core_platform.cp_currencies c
       SET name = 'US Dollar', code = 'USD', symbol = '$', country = 'United States',
           locale = 'en-US', minor_unit_name = 'cents'
     WHERE c.id = 'cur-default-' || c.tenant_id AND c.code = 'GHS'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_currencies o WHERE o.tenant_id = c.tenant_id AND o.code = 'USD')
       AND (to_regclass('mystoreguard.msg_purchase_batches') IS NULL
            OR NOT EXISTS (SELECT 1 FROM mystoreguard.msg_purchase_batches b WHERE b.tenant_id = c.tenant_id AND b.currency_id = c.id))
       AND (to_regclass('invoicing.inv_settings') IS NULL
            OR (NOT EXISTS (SELECT 1 FROM invoicing.inv_settings x WHERE x.tenant_id = c.tenant_id AND x.base_currency = 'GHS')
                AND NOT EXISTS (SELECT 1 FROM invoicing.inv_customers x WHERE x.tenant_id = c.tenant_id AND x.currency = 'GHS')
                AND NOT EXISTS (SELECT 1 FROM invoicing.inv_items x WHERE x.tenant_id = c.tenant_id AND x.currency = 'GHS')
                AND NOT EXISTS (SELECT 1 FROM invoicing.inv_invoices x WHERE x.tenant_id = c.tenant_id AND x.currency = 'GHS')));

    -- An earlier version of this file gave the platform's own tenant one.
    DELETE FROM core_platform.cp_currencies WHERE id = 'cur-default-system-tenant-id' AND tenant_id = 'system-tenant-id';
END $$;

COMMIT;
