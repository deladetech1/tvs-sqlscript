-- =====================================================================
-- Unsubscribing keeps the app's data for a grace period, then a timer deletes it.
--
-- Until now unsubscribing deleted MyStoreGuard, LoanDrift and ZelosHR data on the spot
-- (and, for tables without bus_id, every business's rows in the tenant), kept every
-- other app's data for ever, and told everyone "all your data will be permanently
-- deleted". Now, for every app:
--
--   * unsubscribing writes a PENDING row here with purge_after = now + the grace period
--     (7 days; Core's APP_DATA_GRACE_DAYS) and deletes nothing;
--   * subscribing the same business to the same app again CANCELS it -- the data was
--     never touched, so it is simply there again;
--   * after purge_after the Core function app's timer calls cp_purge_app_data(id) in one
--     transaction per row: the business's rows in the app's own schema, plus the rows
--     that depend on them, and nothing else. Any error rolls the whole purge back and the
--     row goes FAILED (retried next run, shown in the bell) -- never half-deleted.
--
-- cp_app_data_owners says what each app's data is: PURGE (its own schema), KEPT
-- (Accounting: the books are the organisation's) or SHARED (QPickStore: it works on
-- MyStoreGuard's data and has none of its own).
--
-- Never touches core_platform (shared records such as cp_parties) or another app's
-- schema: a row in another schema that refuses the delete fails the purge instead.
--
-- Idempotent; re-runs on every deploy. Runs as the migrator, not a superuser.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_app_data_owners (
    app_id       text PRIMARY KEY,
    schema_name  text,
    -- PURGE: its own schema is deleted after the grace period. KEPT: never deleted on
    -- unsubscribe. SHARED: has no data of its own.
    fate         text NOT NULL,
    note         text,
    CONSTRAINT ck_cp_app_data_owners_fate CHECK (fate IN ('PURGE', 'KEPT', 'SHARED'))
);

-- Code-owned: the map is part of the platform, so a re-run brings every database to it.
INSERT INTO core_platform.cp_app_data_owners (app_id, schema_name, fate, note) VALUES
    ('app-mystoreguard', 'mystoreguard', 'PURGE', NULL),
    ('app-loandrift',    'loandrift',    'PURGE', NULL),
    ('app-zeloshr',      'zeloshr',      'PURGE', NULL),
    ('app-crm',          'crm',          'PURGE', NULL),
    ('app-projects',     'projects',     'PURGE', NULL),
    ('app-invoicing',    'invoicing',    'PURGE', NULL),
    ('app-expenses',     'expenses',     'PURGE', NULL),
    ('app-hms',          'hms',          'PURGE', NULL),
    ('app-scm',          'scm',          'PURGE', NULL),
    ('app-sms',          'sms',          'PURGE', NULL),
    ('app-accounting',   'accounting',   'KEPT',  'The books belong to the organisation and are kept until the account is closed.'),
    ('app-qpickstore',   NULL,           'SHARED','QPickStore works on MyStoreGuard''s products, stock and sales and has no data of its own.')
ON CONFLICT (app_id) DO UPDATE
   SET schema_name = EXCLUDED.schema_name, fate = EXCLUDED.fate, note = EXCLUDED.note;

CREATE TABLE IF NOT EXISTS core_platform.cp_app_data_purges (
    id               text PRIMARY KEY DEFAULT ('adp_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id        text NOT NULL,
    business_id      text NOT NULL,
    app_id           text NOT NULL,
    unsubscribed_at  timestamptz NOT NULL DEFAULT now(),
    purge_after      timestamptz NOT NULL,
    -- PENDING: waiting out the grace period. CANCELLED: re-subscribed (data kept).
    -- PURGED: deleted. FAILED: the last attempt rolled back; retried next run.
    status           text NOT NULL DEFAULT 'PENDING',
    attempts         integer NOT NULL DEFAULT 0,
    last_error       text,
    purged_at        timestamptz,
    purged_counts    jsonb,
    cancelled_at     timestamptz,
    requested_by     text,
    reason           text,
    CONSTRAINT ck_cp_app_data_purges_status CHECK (status IN ('PENDING', 'CANCELLED', 'PURGED', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS ix_cp_app_data_purges_due
    ON core_platform.cp_app_data_purges (status, purge_after);
CREATE INDEX IF NOT EXISTS ix_cp_app_data_purges_business
    ON core_platform.cp_app_data_purges (tenant_id, business_id, app_id);
-- One open purge per business and app: a second unsubscribe (after re-subscribing)
-- writes a new row once the first is CANCELLED.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_app_data_purges_open
    ON core_platform.cp_app_data_purges (tenant_id, business_id, app_id)
    WHERE status IN ('PENDING', 'FAILED');

COMMENT ON TABLE core_platform.cp_app_data_purges IS
    'An unsubscribed business-app whose data is kept until purge_after, then deleted by the Core function app (cp_purge_app_data). Re-subscribing cancels it (shared/20261028-60).';

-- ---------------------------------------------------------------- the delete itself
-- Deletes (or, with p_dry_run, counts) the rows of one table that match p_cond, after
-- first doing the same for every table in the SAME schema whose foreign key would
-- otherwise refuse it (NO ACTION / RESTRICT). Cascading and SET NULL keys are left to
-- the database. A dependent in another schema is not followed: if it refuses, the
-- statement fails and so does the purge -- another app's data is never deleted here.
CREATE OR REPLACE FUNCTION core_platform.cp_purge_rel(
    p_rel regclass, p_cond text, p_dry_run boolean, p_depth integer, p_counts jsonb
) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    fk           record;
    child_cond   text;
    n            bigint;
    rel_schema   text;
    key          text;
BEGIN
    IF p_depth > 12 THEN
        RAISE EXCEPTION 'cp_purge_rel: dependency chain deeper than 12 at %', p_rel;
    END IF;
    SELECT n.nspname INTO rel_schema FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.oid = p_rel;

    FOR fk IN
        SELECT c.conrelid AS child,
               cn.nspname AS child_schema,
               (SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
                  FROM unnest(c.conkey) WITH ORDINALITY k(att, ord)
                  JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.att) AS child_cols,
               (SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
                  FROM unnest(c.confkey) WITH ORDINALITY k(att, ord)
                  JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.att) AS parent_cols
          FROM pg_constraint c
          JOIN pg_class cc ON cc.oid = c.conrelid
          JOIN pg_namespace cn ON cn.oid = cc.relnamespace
         WHERE c.contype = 'f' AND c.confrelid = p_rel
           AND c.confdeltype IN ('a', 'r')
           AND c.conrelid <> p_rel
    LOOP
        CONTINUE WHEN fk.child_schema <> rel_schema;
        child_cond := format('(%s) IN (SELECT %s FROM %s WHERE %s)', fk.child_cols, fk.parent_cols, p_rel, p_cond);
        p_counts := core_platform.cp_purge_rel(fk.child::regclass, child_cond, p_dry_run, p_depth + 1, p_counts);
    END LOOP;

    IF p_dry_run THEN
        EXECUTE format('SELECT count(*) FROM %s WHERE %s', p_rel, p_cond) INTO n;
    ELSE
        EXECUTE format('DELETE FROM %s WHERE %s', p_rel, p_cond);
        GET DIAGNOSTICS n = ROW_COUNT;
    END IF;
    IF n > 0 THEN
        key := p_rel::text;
        p_counts := jsonb_set(p_counts, ARRAY[key], to_jsonb(COALESCE((p_counts ->> key)::bigint, 0) + n));
    END IF;
    RETURN p_counts;
END $$;

-- One business's data for one app, in the caller's transaction. Returns
-- {"status": "...", "counts": {"schema.table": n, ...}}. status:
--   DELETED / WOULD_DELETE (dry run), KEPT / SHARED (nothing to delete),
--   RESUBSCRIBED (the business has the app again: nothing deleted; caller cancels),
--   NO_SCHEMA (this database has no such schema: nothing to delete).
-- Raises on any database error so the caller's transaction rolls back whole.
CREATE OR REPLACE FUNCTION core_platform.cp_purge_app_data(p_purge_id text, p_dry_run boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    p        core_platform.cp_app_data_purges%ROWTYPE;
    o        core_platform.cp_app_data_owners%ROWTYPE;
    t        record;
    counts   jsonb := '{}'::jsonb;
    bus_col  text;
BEGIN
    SELECT * INTO p FROM core_platform.cp_app_data_purges WHERE id = p_purge_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'cp_purge_app_data: no purge %', p_purge_id;
    END IF;
    IF p.status NOT IN ('PENDING', 'FAILED') THEN
        RAISE EXCEPTION 'cp_purge_app_data: purge % is %', p_purge_id, p.status;
    END IF;

    -- Belt and braces: re-subscribing cancels the purge, but if that ever missed, the
    -- business having the app again wins over deleting its data.
    IF EXISTS (SELECT 1 FROM core_platform.cp_business_apps
                WHERE tenant_id = p.tenant_id AND bus_id = p.business_id AND app_id = p.app_id) THEN
        RETURN jsonb_build_object('status', 'RESUBSCRIBED', 'counts', counts);
    END IF;

    SELECT * INTO o FROM core_platform.cp_app_data_owners WHERE app_id = p.app_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'cp_purge_app_data: % is not in cp_app_data_owners', p.app_id;
    END IF;
    IF o.fate <> 'PURGE' THEN
        RETURN jsonb_build_object('status', o.fate, 'counts', counts);
    END IF;
    IF o.schema_name IS NULL OR NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = o.schema_name) THEN
        RETURN jsonb_build_object('status', 'NO_SCHEMA', 'counts', counts);
    END IF;

    -- Every table of the schema that says which business a row belongs to. Only by
    -- business: a table with tenant_id but no business column is reached through its
    -- foreign key to a purged row, never by tenant (which would take every business's).
    FOR t IN
        SELECT c.oid::regclass AS rel,
               bool_or(a.attname = 'bus_id') AS has_bus_id,
               bool_or(a.attname = 'business_id') AS has_business_id
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
         WHERE n.nspname = o.schema_name AND c.relkind IN ('r', 'p')
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

    RETURN jsonb_build_object('status', CASE WHEN p_dry_run THEN 'WOULD_DELETE' ELSE 'DELETED' END, 'counts', counts);
END $$;

COMMENT ON FUNCTION core_platform.cp_purge_app_data(text, boolean) IS
    'Deletes (or with p_dry_run counts) one business''s rows of one app''s schema for a cp_app_data_purges row, in the caller''s transaction; raises on any error (shared/20261028-60).';

DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_data_purges') IS NULL
       OR to_regclass('core_platform.cp_app_data_owners') IS NULL
       OR to_regprocedure('core_platform.cp_purge_app_data(text,boolean)') IS NULL THEN
        RAISE EXCEPTION '20261028-60: purge register or function missing after the migration';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_app_data_owners WHERE fate = 'PURGE' AND schema_name IS NULL) THEN
        RAISE EXCEPTION '20261028-60: an app to purge has no schema';
    END IF;
END $$;

COMMIT;
