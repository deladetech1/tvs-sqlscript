-- Accounting's customers and suppliers take their currency from Core Platform, never a guessed 'GHS'.
--
-- The rule (owner): the only currencies an app offers are the tenant's own, set up in Core
-- Platform (Settings > General > Currencies; core_platform.cp_currencies), and the base currency
-- is Core's default. No hard-coded GHS/USD fallback in code or SQL.
--
-- accounting.acc_customers / acc_suppliers (views over cp_parties, 20261019-37) answered a party's
-- currency as: its Accounting setting, else its Core party currency, else the books' base, else
-- 'GHS'. The last step is now the tenant's default currency in Core Platform (the one marked
-- default, else its only live one), and '' when Core has none: Accounting reads the column as a
-- non-null string, and an empty code is refused when it is used, never booked.
--
-- 20261019-37 re-runs before this file on every deploy and puts its view back; this file then
-- replaces it again, so the later definition is the live one. CREATE OR REPLACE VIEW with the
-- same columns in the same order (only one expression changes), so grants and the INSTEAD OF
-- triggers on the views stay. Skipped, like 20261019-37, where the parties have not moved.
-- Idempotent. Nothing is rewritten: no rows are touched.

BEGIN;

DO $mig$
DECLARE
    k text;
BEGIN
    FOREACH k IN ARRAY ARRAY['customer', 'supplier'] LOOP
        IF to_regclass(format('accounting.acc_%ss_legacy', k)) IS NULL
           OR to_regclass(format('accounting.acc_%s_settings', k)) IS NULL
           OR to_regclass(format('accounting.acc_%ss', k)) IS NULL THEN
            CONTINUE;  -- not moved (no Accounting, or books not yet per business)
        END IF;
        EXECUTE format($v$
        CREATE OR REPLACE VIEW accounting.acc_%1$ss AS
        SELECT p.id, p.tenant_id, p.org_id, p.bus_id, coalesce(st.code, '') AS code, p.name, p.email, p.phone, p.city,
               nullif(p.tax_number, '') AS tin, coalesce(st.payment_terms_days, p.payment_terms_days, 30) AS payment_terms_days,
               coalesce(st.credit_limit, 0)::numeric(18,2) AS credit_limit,
               CASE WHEN p.archived_at IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END AS status,
               st.external_reference, coalesce(st.source, 'MANUAL') AS source,
               coalesce(nullif(btrim(st.currency), ''), nullif(btrim(p.currency::text), ''), nullif(btrim(os.base_currency), ''),
                        (SELECT CASE WHEN bool_or(c.is_default) THEN max(upper(btrim(c.code))) FILTER (WHERE c.is_default)
                                     WHEN count(*) = 1 THEN max(upper(btrim(c.code))) END
                           FROM core_platform.cp_currencies c
                          WHERE c.tenant_id = p.tenant_id AND c.delete_status = 'NOT_DELETED' AND coalesce(c.is_active, true)),
                        '') AS currency,
               coalesce(st.custom_fields_json, '{}'::jsonb) AS custom_fields_json,
               p.cdatetime AS created_at, p.updated_at, p.created_by AS created_by_id, p.updated_by AS updated_by_id,
               p.source_app
          FROM core_platform.cp_parties p
          LEFT JOIN accounting.acc_%1$s_settings st ON st.party_id = p.id
          LEFT JOIN accounting.acc_org_settings os ON os.tenant_id = p.tenant_id AND os.org_id = p.org_id AND os.bus_id = p.bus_id
         WHERE p.is_%1$s AND p.deleted_at IS NULL
        $v$, k);
    END LOOP;
END
$mig$;

-- Self-check: neither view names a fixed currency any more.
DO $chk$
DECLARE
    k text;
BEGIN
    FOREACH k IN ARRAY ARRAY['customers', 'suppliers'] LOOP
        IF to_regclass('accounting.acc_' || k) IS NOT NULL
           AND pg_get_viewdef(('accounting.acc_' || k)::regclass) LIKE '%''GHS''%' THEN
            RAISE EXCEPTION '20261108-50: accounting.acc_% still falls back to GHS', k;
        END IF;
    END LOOP;
END
$chk$;

COMMIT;
