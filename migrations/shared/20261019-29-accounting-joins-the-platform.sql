-- Accounting joins the platform: the books (TapantaBooks, tapantabooks.dev.trovesuite.com).
--
-- Served by its own .NET API (deladetech1/tvs-accounting-bk, Container App accounting-admin);
-- frontend tvs-accounting-ft. Its cp_apps row (beta, active) and tier prices live in the
-- CorePlatform seed (04_others.sql), which owns every app row; its schema, permissions and
-- roles are its own module's (src/Trovesuite.Database.Accounting); its address and label
-- are 20261019-28. This file holds the rest:
--
--   * its cp_app_schemas row, so the platform knows the accounting schema;
--   * acc_audit_events.cdatetime, generated from occurred_at, because registering the schema
--     puts the trail under the retention conformance check (tenant_id + cdatetime);
--   * the trail registered by hand and PARKED (is_enabled = false): never purged. A
--     financial audit trail is evidence, like cp_security_events (20260924-02), and the
--     tier defaults (14-60 days) would destroy it. Its name is not *_audit_logs, so
--     discovery never catalogues it on its own.
--
-- Unsubscribing a business never deletes Accounting's data (tvs-coreplatform-bk
-- APPS_KEPT_ON_UNSUBSCRIBE): the books belong to the business (20261019-36).
--
-- Idempotent; safe to re-run.

BEGIN;

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description)
VALUES ('app-accounting', 'accounting', 'Accounting audit trail')
ON CONFLICT (app_id) DO UPDATE SET schema_name = EXCLUDED.schema_name, description = EXCLUDED.description;

-- Shared files run after the modules' EF migrations; guarded for a database deployed without
-- the Accounting module.
DO $$
BEGIN
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL THEN
        ALTER TABLE accounting.acc_audit_events
            ADD COLUMN IF NOT EXISTS cdatetime timestamptz GENERATED ALWAYS AS (occurred_at) STORED;
        CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_cdatetime
            ON accounting.acc_audit_events (tenant_id, cdatetime DESC);

        INSERT INTO core_platform.cp_activity_log_sources
            (schema_name, table_name, app_id, is_enabled, has_org_id, has_bus_id)
        VALUES ('accounting', 'acc_audit_events', 'app-accounting', false, true, false)
        ON CONFLICT (schema_name, table_name) DO UPDATE SET
            app_id     = EXCLUDED.app_id,
            is_enabled = EXCLUDED.is_enabled,
            has_org_id = EXCLUDED.has_org_id,
            has_bus_id = EXCLUDED.has_bus_id;
    END IF;
END $$;

-- ===================================================================== invariants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_activity_log_sources
                WHERE schema_name = 'accounting' AND is_enabled) THEN
        RAISE EXCEPTION 'an Accounting audit table is enabled for purging; the books'' trail is kept';
    END IF;
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL
       AND EXISTS (SELECT 1 FROM core_platform.cp_nonconforming_activity_log_tables() n
                    WHERE n.schema_name = 'accounting') THEN
        RAISE EXCEPTION 'an Accounting audit table fails the retention conformance check';
    END IF;
END $$;

COMMIT;
