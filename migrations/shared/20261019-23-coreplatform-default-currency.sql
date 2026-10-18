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
-- so it is the platform default: GHS, Ghana Cedi, GH₵, 2 decimals, the same
-- row signup writes.
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
    SELECT 'cur-default-' || t.id, t.id, 'Ghana Cedi', 'GHS', 'GH₵', 'Ghana', 2,
           ',', '.', 'before', 'en-GH',
           'pesewas', true, 1, 'manual',
           'Default currency', true, 'NOT_DELETED',
           -- cdate/ctime in Helper.current_date_time's display form, in UTC
           -- ("Sunday 18th October, 2026", "02:03 PM").
           to_char(now() AT TIME ZONE 'UTC', 'FMDay FMDDth FMMonth, YYYY'),
           to_char(now() AT TIME ZONE 'UTC', 'HH12:MI AM'), now(), NULL
    FROM core_platform.cp_tenants t
    WHERE coalesce(t.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
      AND NOT EXISTS (
          SELECT 1 FROM core_platform.cp_currencies c
          WHERE c.tenant_id = t.id AND c.delete_status = 'NOT_DELETED')
    ON CONFLICT DO NOTHING;
END $$;

COMMIT;
