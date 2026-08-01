-- 20260731-01-activity-log-retention.sql
-- Activity-log retention for the whole suite.
--
-- Audit logs live in one table per entity per app (47 of them at the time of writing,
-- and growing). Rather than maintain a list of those tables in code, this migration
-- DISCOVERS them from the catalog by convention: any table in a registered app schema
-- named '%_audit_logs' that carries tenant_id + cdatetime is picked up automatically the
-- day it is created. Adding a whole new app means adding ONE row to cp_app_schemas.
--
-- Retention is resolved per business-app (matching cp_app_subscriptions, so a tenant can
-- be PREMIUM on one app and BASIC on another): an explicit setting if one exists, else the
-- subscription tier's default, clamped to the tier's maximum and to a hard global floor.
--
-- Idempotent; safe to re-run on every deploy.

SET search_path TO core_platform;

-- =====================================================================================
-- 1. app_id -> schema map. The only thing to add when a new app joins the suite.
--    Deliberately NO FK to cp_apps: 'app-coreplatform' is a sentinel for the platform's
--    own audit tables, which are not a subscribable app.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_app_schemas (
    app_id       text        PRIMARY KEY,
    schema_name  text        NOT NULL UNIQUE,
    description  text,
    is_active    boolean     NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

INSERT INTO core_platform.cp_app_schemas (app_id, schema_name, description) VALUES
('app-coreplatform', 'core_platform', 'Platform-level audit logs (users, roles, orgs, locations, policies)'),
('app-mystoreguard', 'mystoreguard',  'MyStoreGuard audit logs'),
('app-loandrift',    'loandrift',     'LoanDrift audit logs'),
('app-zeloshr',      'zeloshr',       'ZelosHR audit logs')
ON CONFLICT (app_id) DO UPDATE SET
    schema_name = EXCLUDED.schema_name,
    description = EXCLUDED.description;

-- =====================================================================================
-- 2. Per-tier retention policy. Data, not code, so changing the offer needs no deploy.
--    max_days NULL = uncapped (Enterprise).
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_subscription_retention_defaults (
    subscription_id text        PRIMARY KEY,
    default_days    integer     NOT NULL CHECK (default_days > 0),
    max_days        integer     CHECK (max_days IS NULL OR max_days >= default_days),
    cdatetime       timestamptz NOT NULL DEFAULT now()
);

INSERT INTO core_platform.cp_subscription_retention_defaults (subscription_id, default_days, max_days) VALUES
('shared-subscription-basic',      14,   30),
('shared-subscription-advance',    30,   90),
('shared-subscription-premium',    60,  365),
('shared-subscription-enterprise', 60, NULL)
ON CONFLICT (subscription_id) DO UPDATE SET
    default_days = EXCLUDED.default_days,
    max_days     = EXCLUDED.max_days;

-- =====================================================================================
-- 3. Catalog of audit-log tables. Auto-populated by cp_discover_activity_log_sources();
--    rows exist to be OVERRIDDEN (disable a table, or hold it longer), never to be
--    hand-maintained as the source of truth.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_activity_log_sources (
    schema_name        text        NOT NULL,
    table_name         text        NOT NULL,
    app_id             text        NOT NULL,
    -- false parks a table permanently (never purged) without deleting the catalog row
    is_enabled         boolean     NOT NULL DEFAULT true,
    -- legal hold: never purge rows younger than this, whatever the tenant's setting says
    min_retention_days integer,
    has_org_id         boolean     NOT NULL DEFAULT true,
    has_bus_id         boolean     NOT NULL DEFAULT true,
    discovered_at      timestamptz NOT NULL DEFAULT now(),
    last_purged_at     timestamptz,
    last_deleted_rows  bigint      NOT NULL DEFAULT 0,
    PRIMARY KEY (schema_name, table_name)
);

-- =====================================================================================
-- 4. The setting itself: one row per (tenant, org, business, app). Absent = tier default.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_activity_log_retention_settings (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    org_id         text        NOT NULL,
    bus_id         text        NOT NULL,
    app_id         text        NOT NULL,
    retention_days integer     NOT NULL CHECK (retention_days >= 7),
    updated_by     text,
    cdate          text,
    ctime          text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    udatetime      timestamptz,
    UNIQUE (tenant_id, org_id, bus_id, app_id)
);

CREATE INDEX IF NOT EXISTS idx_cp_activity_log_retention_settings_scope
    ON core_platform.cp_activity_log_retention_settings (tenant_id, org_id, bus_id);

-- =====================================================================================
-- 5. Purge run log. Deleting audit logs is itself an auditable act.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_activity_log_purge_runs (
    id               text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    started_at       timestamptz NOT NULL DEFAULT now(),
    finished_at      timestamptz,
    trigger_source   text,
    dry_run          boolean     NOT NULL DEFAULT false,
    tables_processed integer     NOT NULL DEFAULT 0,
    rows_deleted     bigint      NOT NULL DEFAULT 0,
    status           text        NOT NULL DEFAULT 'RUNNING',
    error            text,
    details          jsonb
);

CREATE INDEX IF NOT EXISTS idx_cp_activity_log_purge_runs_started
    ON core_platform.cp_activity_log_purge_runs (started_at DESC);

-- =====================================================================================
-- 5b. Changing a retention window is itself an audited settings change. Standard audit
--     shape, so this table is picked up by the very retention it configures.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_activity_log_retention_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- retention setting id
    entity_name            text,                               -- 'Activity Log Retention'

    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,

    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_activity_log_retention_audit_logs_scope
    ON core_platform.cp_activity_log_retention_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_activity_log_retention_audit_logs_entity
    ON core_platform.cp_activity_log_retention_audit_logs (tenant_id, entity_id, cdatetime DESC);

-- =====================================================================================
-- 6. Discovery. Convention: <schema>.*_audit_logs with tenant_id + cdatetime.
--    Returns the number of NEW tables catalogued.
-- =====================================================================================
CREATE OR REPLACE FUNCTION core_platform.cp_discover_activity_log_sources()
RETURNS integer AS $$
DECLARE
    v_new integer := 0;
BEGIN
    WITH candidate AS (
        SELECT c.table_schema                                                     AS schema_name,
               c.table_name                                                       AS table_name,
               s.app_id                                                           AS app_id,
               bool_or(c.column_name = 'tenant_id')                               AS has_tenant,
               bool_or(c.column_name = 'cdatetime')                               AS has_cdatetime,
               bool_or(c.column_name = 'org_id')                                  AS has_org,
               bool_or(c.column_name = 'bus_id')                                  AS has_bus
        FROM information_schema.columns c
        JOIN core_platform.cp_app_schemas s
          ON s.schema_name = c.table_schema AND s.is_active
        WHERE c.table_name LIKE '%\_audit\_logs'
        GROUP BY c.table_schema, c.table_name, s.app_id
    ),
    inserted AS (
        INSERT INTO core_platform.cp_activity_log_sources
            (schema_name, table_name, app_id, has_org_id, has_bus_id)
        SELECT schema_name, table_name, app_id, has_org, has_bus
        FROM candidate
        WHERE has_tenant AND has_cdatetime
        ON CONFLICT (schema_name, table_name) DO UPDATE SET
            app_id     = EXCLUDED.app_id,
            has_org_id = EXCLUDED.has_org_id,
            has_bus_id = EXCLUDED.has_bus_id
        RETURNING xmax = 0 AS is_new
    )
    SELECT count(*) FILTER (WHERE is_new) INTO v_new FROM inserted;

    RETURN v_new;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- 7. Conformance check. Anything that LOOKS like an audit table but can't be purged.
--    Call this from CI / log it on every run: silent non-coverage is the only way this
--    design fails, so it must be loud.
-- =====================================================================================
CREATE OR REPLACE FUNCTION core_platform.cp_nonconforming_activity_log_tables()
RETURNS TABLE (schema_name text, table_name text, missing text) AS $$
    SELECT c.table_schema::text,
           c.table_name::text,
           array_to_string(
               ARRAY(SELECT col FROM unnest(ARRAY['tenant_id', 'cdatetime']) AS col
                     WHERE col NOT IN (SELECT c2.column_name::text
                                       FROM information_schema.columns c2
                                       WHERE c2.table_schema = c.table_schema
                                         AND c2.table_name = c.table_name)),
               ', ')
    FROM information_schema.columns c
    JOIN core_platform.cp_app_schemas s
      ON s.schema_name = c.table_schema AND s.is_active
    -- Real tables only: the retention feature's own views would otherwise match, and a
    -- check that cries wolf is a check nobody reads.
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
     AND t.table_type = 'BASE TABLE'
    WHERE (c.table_name LIKE '%audit%' OR c.table_name LIKE '%\_activity\_logs')
    GROUP BY c.table_schema, c.table_name
    HAVING NOT (bool_or(c.column_name = 'tenant_id') AND bool_or(c.column_name = 'cdatetime'));
$$ LANGUAGE sql;

-- =====================================================================================
-- 8. Effective retention per (tenant, org, business, app), and the cutoff it implies.
--    setting -> tier default, clamped to the tier max and the global floor.
--    'app-coreplatform' has no subscription of its own, so platform logs inherit the most
--    generous window across that scope's subscribed apps (never delete a tenant's platform
--    trail earlier than their best app entitles them to).
-- =====================================================================================
CREATE OR REPLACE VIEW core_platform.cp_activity_log_retention AS
WITH scope AS (
    SELECT sub.tenant_id,
           b.org_id,
           sub.business_id AS bus_id,
           sub.app_id,
           sub.shared_subscription_id,
           sub.is_enterprise
    FROM core_platform.cp_app_subscriptions sub
    JOIN core_platform.cp_businesses b
      ON b.id = sub.business_id AND b.tenant_id = sub.tenant_id
),
resolved AS (
    SELECT sc.tenant_id,
           sc.org_id,
           sc.bus_id,
           sc.app_id,
           d.default_days,
           d.max_days,
           st.retention_days AS custom_days
    FROM scope sc
    LEFT JOIN core_platform.cp_subscription_retention_defaults d
           ON d.subscription_id = CASE WHEN sc.is_enterprise
                                       THEN 'shared-subscription-enterprise'
                                       ELSE sc.shared_subscription_id END
    LEFT JOIN core_platform.cp_activity_log_retention_settings st
           ON st.tenant_id = sc.tenant_id
          AND st.org_id    = sc.org_id
          AND st.bus_id    = sc.bus_id
          AND st.app_id    = sc.app_id
),
per_app AS (
    SELECT tenant_id,
           org_id,
           bus_id,
           app_id,
           default_days,
           max_days,
           custom_days,
           -- floor of 7 days protects against a misconfigured 0; the tier max caps upgrades
           GREATEST(
               7,
               LEAST(
                   COALESCE(custom_days, default_days, 14),
                   COALESCE(max_days, 2147483647)
               )
           ) AS effective_days
    FROM resolved
)
SELECT tenant_id, org_id, bus_id, app_id,
       default_days, max_days, custom_days, effective_days,
       (custom_days IS NOT NULL) AS is_custom
FROM per_app
UNION ALL
-- Platform-level logs: the most generous window the scope is entitled to, unless
-- explicitly overridden with app_id = 'app-coreplatform'.
SELECT p.tenant_id, p.org_id, p.bus_id, 'app-coreplatform'::text,
       max(p.default_days), max(p.max_days), max(cp.retention_days),
       GREATEST(7, COALESCE(max(cp.retention_days), max(p.effective_days), 14)),
       (max(cp.retention_days) IS NOT NULL)
FROM per_app p
LEFT JOIN core_platform.cp_activity_log_retention_settings cp
       ON cp.tenant_id = p.tenant_id
      AND cp.org_id    = p.org_id
      AND cp.bus_id    = p.bus_id
      AND cp.app_id    = 'app-coreplatform'
GROUP BY p.tenant_id, p.org_id, p.bus_id;

CREATE OR REPLACE VIEW core_platform.cp_activity_log_cutoffs AS
SELECT tenant_id, org_id, bus_id, app_id, effective_days,
       now() - make_interval(days => effective_days) AS cutoff_at
FROM core_platform.cp_activity_log_retention;

-- =====================================================================================
-- 9. The purge. One dynamic statement per catalogued table, joined to the cutoff view so
--    it rides the existing idx_<table>_scope (tenant_id, org_id, bus_id, cdatetime DESC).
--    Batched by ctid and bounded by a wall-clock budget, so a run can never hold long
--    locks or overrun its schedule. Whatever it does not finish, the next run picks up.
-- =====================================================================================
CREATE OR REPLACE FUNCTION core_platform.cp_purge_expired_activity_logs(
    p_batch_size  integer DEFAULT 5000,
    p_max_seconds integer DEFAULT 240,
    p_dry_run     boolean DEFAULT false,
    p_source      text    DEFAULT 'manual'
)
RETURNS TABLE (tables_processed integer, rows_deleted bigint, run_id text) AS $$
DECLARE
    r              record;
    v_run_id       text;
    v_deadline     timestamptz := clock_timestamp() + make_interval(secs => p_max_seconds);
    v_total        bigint := 0;
    v_tables       integer := 0;
    v_batch        bigint;
    v_table_total  bigint;
    v_sql          text;
    v_join         text;
    v_cutoffs      text;
    v_details      jsonb := '[]'::jsonb;
BEGIN
    INSERT INTO core_platform.cp_activity_log_purge_runs (trigger_source, dry_run)
    VALUES (p_source, p_dry_run)
    RETURNING id INTO v_run_id;

    -- Pick up any audit table added since the last run before deciding what to purge.
    PERFORM core_platform.cp_discover_activity_log_sources();

    FOR r IN
        SELECT s.schema_name, s.table_name, s.app_id, s.has_org_id, s.has_bus_id,
               COALESCE(s.min_retention_days, 0) AS min_days
        FROM core_platform.cp_activity_log_sources s
        WHERE s.is_enabled
          AND to_regclass(format('%I.%I', s.schema_name, s.table_name)) IS NOT NULL
        ORDER BY s.last_purged_at NULLS FIRST, s.schema_name, s.table_name
    LOOP
        EXIT WHEN clock_timestamp() >= v_deadline;

        -- Tables scoped to org+business join the cutoff exactly. A table without those
        -- columns takes the most generous cutoff for the tenant (MIN, since a longer
        -- retention means an EARLIER cutoff) so it can never over-delete.
        IF r.has_org_id AND r.has_bus_id THEN
            v_cutoffs := format(
                'SELECT tenant_id, org_id, bus_id, cutoff_at FROM core_platform.cp_activity_log_cutoffs WHERE app_id = %L',
                r.app_id);
            v_join := 'a.tenant_id = c.tenant_id AND a.org_id = c.org_id AND a.bus_id = c.bus_id';
        ELSE
            v_cutoffs := format(
                'SELECT tenant_id, min(cutoff_at) AS cutoff_at FROM core_platform.cp_activity_log_cutoffs WHERE app_id = %L GROUP BY tenant_id',
                r.app_id);
            v_join := 'a.tenant_id = c.tenant_id';
        END IF;

        v_table_total := 0;

        LOOP
            EXIT WHEN clock_timestamp() >= v_deadline;

            IF p_dry_run THEN
                v_sql := format(
                    'SELECT count(*) FROM (SELECT a.ctid FROM %I.%I a JOIN (%s) c ON %s
                       WHERE a.cdatetime < LEAST(c.cutoff_at, now() - make_interval(days => %s))
                       LIMIT %s) t',
                    r.schema_name, r.table_name, v_cutoffs, v_join, r.min_days, p_batch_size);
                EXECUTE v_sql INTO v_batch;
                v_table_total := v_batch;
                EXIT;  -- dry run reports one batch, never loops
            END IF;

            v_sql := format(
                'WITH victim AS (
                     SELECT a.ctid AS cid
                     FROM %I.%I a
                     JOIN (%s) c ON %s
                     WHERE a.cdatetime < LEAST(c.cutoff_at, now() - make_interval(days => %s))
                     LIMIT %s
                 )
                 DELETE FROM %I.%I t WHERE t.ctid IN (SELECT cid FROM victim)',
                r.schema_name, r.table_name, v_cutoffs, v_join, r.min_days, p_batch_size,
                r.schema_name, r.table_name);

            EXECUTE v_sql;
            GET DIAGNOSTICS v_batch = ROW_COUNT;
            v_table_total := v_table_total + v_batch;

            EXIT WHEN v_batch < p_batch_size;
        END LOOP;

        v_tables := v_tables + 1;
        v_total  := v_total + v_table_total;

        IF NOT p_dry_run THEN
            UPDATE core_platform.cp_activity_log_sources
               SET last_purged_at    = now(),
                   last_deleted_rows = v_table_total
             WHERE schema_name = r.schema_name AND table_name = r.table_name;
        END IF;

        IF v_table_total > 0 THEN
            v_details := v_details || jsonb_build_object(
                'table', r.schema_name || '.' || r.table_name,
                'rows',  v_table_total);
        END IF;
    END LOOP;

    UPDATE core_platform.cp_activity_log_purge_runs
       SET finished_at      = now(),
           tables_processed = v_tables,
           rows_deleted     = v_total,
           status           = 'SUCCESS',
           details          = v_details
     WHERE id = v_run_id;

    tables_processed := v_tables;
    rows_deleted     := v_total;
    run_id           := v_run_id;
    RETURN NEXT;

EXCEPTION WHEN OTHERS THEN
    UPDATE core_platform.cp_activity_log_purge_runs
       SET finished_at = now(), status = 'FAILED', error = SQLERRM,
           tables_processed = v_tables, rows_deleted = v_total
     WHERE id = v_run_id;
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Seed the catalog on first deploy so the tables are visible before the first run.
SELECT core_platform.cp_discover_activity_log_sources();
