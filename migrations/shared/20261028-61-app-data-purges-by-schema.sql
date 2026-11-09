-- =====================================================================
-- Kept data is purged per SCHEMA, not per app (follows 20261028-60).
--
-- MyStoreGuard and QPickStore share one set of data: the mystoreguard schema. Keyed by
-- app, unsubscribing MyStoreGuard while the business kept QPickStore scheduled a purge
-- that would have deleted the shop's products, stock and online sales 7 days later.
--
-- The rule now: a business's data in schema S may be purged only when the business
-- holds NO app whose data lives in S.
--
--   * cp_app_data_owners: QPickStore points at schema 'mystoreguard' (fate SHARED: it
--     uses another app's data). Any future app sharing a schema does the same.
--   * cp_app_data_purges gains schema_name; a purge is of (business, schema). One open
--     purge per business and schema.
--   * cp_purge_app_data refuses (RESUBSCRIBED, nothing deleted) while the business holds
--     ANY app whose data lives in that schema.
--
-- The backend schedules a purge only when the LAST app using S leaves, and subscribing
-- to any app using S cancels it. Idempotent; re-runs every deploy; migrator not superuser.
-- =====================================================================
BEGIN;

UPDATE core_platform.cp_app_data_owners
   SET schema_name = 'mystoreguard',
       note = 'QPickStore uses MyStoreGuard''s products, stock and sales; they are kept while the business has either app.'
 WHERE app_id = 'app-qpickstore'
   AND (schema_name IS DISTINCT FROM 'mystoreguard' OR note NOT LIKE 'QPickStore uses MyStoreGuard%');

ALTER TABLE core_platform.cp_app_data_purges ADD COLUMN IF NOT EXISTS schema_name text;

UPDATE core_platform.cp_app_data_purges p
   SET schema_name = o.schema_name
  FROM core_platform.cp_app_data_owners o
 WHERE o.app_id = p.app_id AND p.schema_name IS NULL AND o.schema_name IS NOT NULL;

-- Open purges were unique per app; a schema is the unit now.
DROP INDEX IF EXISTS core_platform.ux_cp_app_data_purges_open;
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_app_data_purges_open_schema
    ON core_platform.cp_app_data_purges (tenant_id, business_id, schema_name)
    WHERE status IN ('PENDING', 'FAILED');

COMMENT ON COLUMN core_platform.cp_app_data_purges.schema_name IS
    'The schema whose rows for this business are purged. app_id is the app whose unsubscribe left the data unused (shared/20261028-61).';

CREATE OR REPLACE FUNCTION core_platform.cp_purge_app_data(p_purge_id text, p_dry_run boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    p        core_platform.cp_app_data_purges%ROWTYPE;
    schema_  text;
    t        record;
    counts   jsonb := '{}'::jsonb;
    bus_col  text;
    holder   text;
BEGIN
    SELECT * INTO p FROM core_platform.cp_app_data_purges WHERE id = p_purge_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'cp_purge_app_data: no purge %', p_purge_id;
    END IF;
    IF p.status NOT IN ('PENDING', 'FAILED') THEN
        RAISE EXCEPTION 'cp_purge_app_data: purge % is %', p_purge_id, p.status;
    END IF;

    schema_ := COALESCE(p.schema_name,
                        (SELECT schema_name FROM core_platform.cp_app_data_owners WHERE app_id = p.app_id));
    IF schema_ IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM core_platform.cp_app_data_owners WHERE app_id = p.app_id) THEN
            RAISE EXCEPTION 'cp_purge_app_data: % is not in cp_app_data_owners', p.app_id;
        END IF;
        RETURN jsonb_build_object('status', 'SHARED', 'counts', counts);
    END IF;

    -- The business still has an app whose data lives here (the app itself again, or
    -- another sharing the schema, e.g. QPickStore and MyStoreGuard): nothing is deleted.
    SELECT ba.app_id INTO holder
      FROM core_platform.cp_business_apps ba
      JOIN core_platform.cp_app_data_owners o ON o.app_id = ba.app_id
     WHERE ba.tenant_id = p.tenant_id AND ba.bus_id = p.business_id AND o.schema_name = schema_
     LIMIT 1;
    IF holder IS NOT NULL THEN
        RETURN jsonb_build_object('status', 'RESUBSCRIBED', 'held_by', holder, 'counts', counts);
    END IF;

    -- Data some app keeps for good (Accounting) is never purged.
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_data_owners WHERE schema_name = schema_ AND fate = 'KEPT') THEN
        RETURN jsonb_build_object('status', 'KEPT', 'counts', counts);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = schema_) THEN
        RETURN jsonb_build_object('status', 'NO_SCHEMA', 'counts', counts);
    END IF;

    FOR t IN
        SELECT c.oid::regclass AS rel,
               bool_or(a.attname = 'bus_id') AS has_bus_id
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
         WHERE n.nspname = schema_ AND c.relkind IN ('r', 'p')
         GROUP BY c.oid
        HAVING bool_or(a.attname = 'tenant_id')
           AND (bool_or(a.attname = 'bus_id') OR bool_or(a.attname = 'business_id'))
         ORDER BY c.oid::regclass::text
    LOOP
        bus_col := CASE WHEN t.has_bus_id THEN 'bus_id' ELSE 'business_id' END;
        counts := core_platform.cp_purge_rel(
            t.rel,
            format('tenant_id = %L AND %I = %L', p.tenant_id, bus_col, p.business_id),
            p_dry_run, 0, counts);
    END LOOP;

    RETURN jsonb_build_object('status', CASE WHEN p_dry_run THEN 'WOULD_DELETE' ELSE 'DELETED' END,
                              'schema', schema_, 'counts', counts);
END $$;

DO $$
BEGIN
    IF (SELECT schema_name FROM core_platform.cp_app_data_owners WHERE app_id = 'app-qpickstore') IS DISTINCT FROM 'mystoreguard' THEN
        RAISE EXCEPTION '20261028-61: QPickStore must point at the mystoreguard schema';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'core_platform' AND table_name = 'cp_app_data_purges' AND column_name = 'schema_name') THEN
        RAISE EXCEPTION '20261028-61: cp_app_data_purges.schema_name missing';
    END IF;
END $$;

COMMIT;
