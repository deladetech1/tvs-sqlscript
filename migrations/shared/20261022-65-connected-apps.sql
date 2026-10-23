-- Connected apps: a business decides which of its apps send data to which (Core Platform →
-- Connected apps). docs/POSTINGS.md §10 (Connected apps).
--
-- Until now every link between apps was automatic: once a business subscribed to Accounting
-- and set up its books, MyStoreGuard, LoanDrift, Expenses, Invoicing and ZelosHR events posted
-- into the books by themselves. From here a business switches each link:
--
--   OFF       nothing is sent (the default for every business and every link);
--   ONE_TIME  only what happened between range_from and range_to is sent, once;
--   ALWAYS    everything is sent as it happens.
--
-- The RECEIVING app enforces it and fails CLOSED: Accounting's PostingRun reads this table
-- before posting anything and, with no row (or a read that fails), posts nothing. Hiding the
-- switch in the hub is not the protection.
--
-- This file holds:
--   * core_platform.cp_app_connections (one row per business and link, written only by Core
--     Platform's /app-connections endpoints);
--   * the permission app-connection get/update (Core Platform's own, prefix ''): held by Owner,
--     Admin and Core Platform Admin by RULE (tvs-package AuthService), granted to no curated role;
--   * a ONE-TIME backfill so nothing changes for a business already posting: every business whose
--     books are set up on a live Accounting subscription, and every (business, app) that already
--     has posted journals, gets ALWAYS. A marker row makes it run once per database: a business
--     that sets up its books after today starts OFF, as a new business must;
--   * accounting.acc_posting_request_retry, the one thing the hub may do to Accounting's inbox:
--     ask for another attempt. Accounting re-applies every rule (subscription, books, connection,
--     periods) when it tries.
--
-- Guards rather than assumptions about other modules: the accounting objects are touched only
-- where the accounting schema and tables exist (a database without Accounting just has no
-- backfill to do). Idempotent; safe to re-run on every deploy.

BEGIN;

-- ===================================================================== the settings
CREATE TABLE IF NOT EXISTS core_platform.cp_app_connections (
    id             text PRIMARY KEY DEFAULT ('acn_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    link_key       text NOT NULL,          -- e.g. mystoreguard-accounting (Core Platform's catalogue)
    source_app     text NOT NULL,          -- cp_apps.id that sends, e.g. app-mystoreguard
    target_app     text NOT NULL,          -- cp_apps.id that receives, e.g. app-accounting
    mode           text NOT NULL DEFAULT 'OFF',
    range_from     timestamptz,            -- ONE_TIME only: what happened from ...
    range_to       timestamptz,            -- ... up to and including
    run_started_at timestamptz,            -- ONE_TIME: when the run was asked for
    changed_by     text,                   -- cp_users.id, or 'system' for the backfill
    changed_by_name text,
    changed_at     timestamptz NOT NULL DEFAULT now(),
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_cp_app_connections_mode CHECK (mode IN ('OFF', 'ONE_TIME', 'ALWAYS')),
    CONSTRAINT ck_cp_app_connections_range CHECK (
        (mode <> 'ONE_TIME') OR (range_from IS NOT NULL AND range_to IS NOT NULL AND range_from <= range_to))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_app_connections_link
    ON core_platform.cp_app_connections (tenant_id, bus_id, link_key);
-- What a receiving app asks: "may this source send to me for this business?"
CREATE INDEX IF NOT EXISTS ix_cp_app_connections_receiver
    ON core_platform.cp_app_connections (tenant_id, bus_id, target_app, source_app);

COMMENT ON TABLE core_platform.cp_app_connections IS
    'Per business, which app may send data to which (OFF / ONE_TIME range / ALWAYS). The receiving app enforces it and treats no row as OFF. Written only by Core Platform (/app-connections).';

-- ===================================================================== permission
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-app-connection', 'App Connections', 'Which of a business''s apps send data to which (Connected apps)', NULL)
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description;

-- 20260928-09 empties cp_resources and refills its own list on every deploy, so the line is
-- declared again here, after it, every time.
INSERT INTO core_platform.cp_resources (app_prefix, resource_key, resource_type_id, actions, label)
VALUES ('', 'app-connection', 'rt-app-connection', ARRAY['get', 'update'], 'App Connections')
ON CONFLICT (app_prefix, resource_key) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                                                     actions          = EXCLUDED.actions,
                                                     label            = EXCLUDED.label;
-- Not sync_permissions_from_catalogue(): later migrations moved rows (attendance to ZelosHR)
-- without restating cp_resources, so a full sync at this point collides with them. The two
-- rows are written exactly as the catalogue would name them, as the app migrations do.
INSERT INTO core_platform.cp_permissions
       (id, permission_name, resource_type_id, description, app_prefix, resource_key, action, target, scope,
        cdate, ctime, cdatetime)
VALUES ('permission-app-connection-get', 'App Connections Get', 'rt-app-connection',
        'See which apps of a business are connected, and what they sent', '', 'app-connection', 'get', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP),
       ('permission-app-connection-update', 'App Connections Update', 'rt-app-connection',
        'Switch app connections off, on, or for one time range', '', 'app-connection', 'update', '', 'any',
        CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET resource_type_id = EXCLUDED.resource_type_id,
                               app_prefix       = EXCLUDED.app_prefix,
                               resource_key     = EXCLUDED.resource_key,
                               action           = EXCLUDED.action,
                               target           = EXCLUDED.target,
                               scope            = EXCLUDED.scope;

-- ===================================================================== backfill (once)
CREATE TABLE IF NOT EXISTS core_platform.cp_app_connection_backfills (
    key     text PRIMARY KEY,
    ran_at  timestamptz NOT NULL DEFAULT now(),
    rows    integer NOT NULL DEFAULT 0
);

DO $$
DECLARE
    n integer := 0;
    has_books boolean;
    has_inbox boolean;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_connection_backfills WHERE key = 'accounting-links-20261022') THEN
        RAISE NOTICE 'connected apps: the accounting backfill already ran on this database';
        RETURN;
    END IF;

    has_books := to_regclass('accounting.acc_org_settings') IS NOT NULL
             AND to_regclass('core_platform.cp_business_app_tier') IS NOT NULL;
    has_inbox := to_regclass('accounting.acc_posting_inbox') IS NOT NULL;

    -- Built as strings: a database without Accounting's tables must still parse this file.
    IF has_books THEN
        EXECUTE $q$
            INSERT INTO core_platform.cp_app_connections
                   (tenant_id, bus_id, link_key, source_app, target_app, mode, changed_by, changed_by_name)
            SELECT DISTINCT s.tenant_id, s.bus_id, src.app || '-accounting', 'app-' || src.app, 'app-accounting',
                   'ALWAYS', 'system', 'Kept on when Connected apps arrived'
              FROM accounting.acc_org_settings s
              JOIN core_platform.cp_business_app_tier t
                ON t.tenant_id = s.tenant_id AND t.business_id = s.bus_id AND t.app_id = 'app-accounting'
             CROSS JOIN (VALUES ('mystoreguard'), ('loandrift'), ('expenses'), ('invoicing'), ('zeloshr')) AS src(app)
             WHERE s.setup_complete AND s.bus_id IS NOT NULL AND s.bus_id <> ''
            ON CONFLICT (tenant_id, bus_id, link_key) DO NOTHING
        $q$;
        GET DIAGNOSTICS n = ROW_COUNT;
    END IF;

    IF has_inbox THEN
        EXECUTE $q$
            INSERT INTO core_platform.cp_app_connections
                   (tenant_id, bus_id, link_key, source_app, target_app, mode, changed_by, changed_by_name)
            SELECT DISTINCT i.tenant_id, i.bus_id, i.source_app || '-accounting', 'app-' || i.source_app, 'app-accounting',
                   'ALWAYS', 'system', 'Kept on when Connected apps arrived'
              FROM accounting.acc_posting_inbox i
             WHERE i.status = 'POSTED'
               AND i.source_app IN ('mystoreguard', 'loandrift', 'expenses', 'invoicing', 'zeloshr')
            ON CONFLICT (tenant_id, bus_id, link_key) DO NOTHING
        $q$;
    END IF;

    SELECT count(*) INTO n FROM core_platform.cp_app_connections WHERE changed_by = 'system';
    INSERT INTO core_platform.cp_app_connection_backfills (key, rows) VALUES ('accounting-links-20261022', n);
    RAISE NOTICE 'connected apps: % link(s) kept ALWAYS for businesses already posting', n;
END $$;

-- ===================================================================== retry request
-- The hub's drawer offers "Try again" on a failed posting. It only asks: the row goes back to
-- PENDING and Accounting decides, on its next pass, whether it may post (every gate again).
DO $$
BEGIN
    IF to_regnamespace('accounting') IS NULL THEN
        RAISE NOTICE 'connected apps: no accounting schema here, no retry function';
        RETURN;
    END IF;
    EXECUTE $f$
        CREATE OR REPLACE FUNCTION accounting.acc_posting_request_retry(
            p_tenant text, p_bus text, p_source text, p_ids text[])
        RETURNS integer LANGUAGE plpgsql AS $body$
        DECLARE n integer;
        BEGIN
            UPDATE accounting.acc_posting_inbox
               SET status = 'PENDING',
                   reason = 'Asked to try again from Connected apps.',
                   updated_at = now()
             WHERE tenant_id = p_tenant AND bus_id = p_bus AND source_app = p_source
               AND status = 'FAILED'
               AND (p_ids IS NULL OR id = ANY (p_ids));
            GET DIAGNOSTICS n = ROW_COUNT;
            RETURN n;
        END $body$
    $f$;
END $$;

-- ===================================================================== checks
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(id, ', ') INTO bad
      FROM (VALUES ('permission-app-connection-get'), ('permission-app-connection-update')) AS v(id)
     WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                        WHERE p.id = v.id AND p.app_prefix = '' AND p.resource_key = 'app-connection');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'connected apps: permission(s) missing or mis-keyed: %', bad;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_connections
                WHERE mode = 'ONE_TIME' AND (range_from IS NULL OR range_to IS NULL)) THEN
        RAISE EXCEPTION 'connected apps: a ONE_TIME link without its range';
    END IF;
END $$;

COMMIT;
