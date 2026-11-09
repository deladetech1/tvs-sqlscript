-- Manufacturing: the helpers every later Manufacturing file uses (design: tvs-shared-apps-bk
-- docs/mfg/03-database-model.md §1, §3.1, §6; contract docs/mfg/contracts/R1.md §3).
--
--   mfg.mfg_purge_allowed(t, b)      true when business b no longer has Manufacturing
--                                    (cp_business_apps holds no app-mfg row): the only time a
--                                    protected row may be deleted, by the unsubscribe purge
--                                    (core_platform.cp_purge_app_data, 20261028-60/-61)
--   mfg.mfg_refuse_change()          trigger: the table is append-only. UPDATE is refused, and
--                                    DELETE too unless the purge is deleting the business.
--                                    Attached to confirmations, downtime events, genealogy
--                                    links and the order timeline (20261029-43)
--   mfg.mfg_freeze_released()        trigger: a released revision is frozen. With no arguments
--                                    it guards a revisioned header (item revision, BOM, routing,
--                                    work instruction); with (parent table, parent key column)
--                                    it guards that header's child rows (BOM lines, operations,
--                                    steps, ...). A change always means a new revision
--   mfg.mfg_ensure_partitions(t, n)  the monthly partitions of a partitioned mfg table, this
--                                    month and the next n, plus one DEFAULT partition
--   mfg_settings                     one per business: default plant, tolerances, policies
--   mfg_number_series                the next MO- (and later NCR-, ECO-, MWO-) number per business
--   mfg_idempotency_keys             the stored reply of every keyed action, kept 7 days
--   mfg_custom_fields                the custom fields a business defines per entity
--
-- What a frozen row still accepts:
--   * the lifecycle: status released -> superseded | obsolete, superseded -> obsolete, and
--     effective_to, archived_at, version, updated_at, updated_by;
--   * the suite's product or supplier merge (cp_product_merge / cp_party_merge), which re-points
--     product_id, component_id or subcontract_party_id and changes nothing else.
--
-- The enum-like lists of these tables (costing method, custom field type) live in
-- 20261029-46. No grants: default privileges and the IaC app group handle access.
-- Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS mfg;

-- ================================================================= trigger functions
-- The business no longer has Manufacturing, so the unsubscribe purge may delete its rows. With
-- no Core subscription table at all (a database without the CorePlatform module) nothing may be
-- deleted.
CREATE OR REPLACE FUNCTION mfg.mfg_purge_allowed(p_tenant text, p_bus text) RETURNS boolean
LANGUAGE plpgsql STABLE AS $f$
BEGIN
    IF to_regclass('core_platform.cp_business_apps') IS NULL THEN
        RETURN false;
    END IF;
    RETURN NOT EXISTS (SELECT 1 FROM core_platform.cp_business_apps
                        WHERE tenant_id = p_tenant AND bus_id = p_bus AND app_id = 'app-mfg');
END
$f$;

-- The same shape as scm.scm_movements_immutable: a mistake is corrected by a reversing row.
CREATE OR REPLACE FUNCTION mfg.mfg_refuse_change() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF TG_OP = 'DELETE' AND mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION '%.% is append-only: % is not allowed; record a reversing row instead',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;

CREATE OR REPLACE FUNCTION mfg.mfg_freeze_released() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    frozen   constant text[] := ARRAY['released', 'superseded', 'obsolete'];
    -- what the lifecycle may still change on a frozen row
    lifecycle constant text[] := ARRAY['status', 'effective_to', 'archived_at', 'version', 'updated_at', 'updated_by'];
    -- what a product or supplier merge re-points
    refs     constant text[] := ARRAY['product_id', 'component_id', 'subcontract_party_id'];
    o        jsonb;
    n        jsonb;
    pid      text;
    st       text;
BEGIN
    IF TG_OP <> 'INSERT' THEN o := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN n := to_jsonb(NEW); END IF;

    IF TG_NARGS = 0 THEN
        -- ------------------------------------------------ a revisioned header
        IF TG_OP = 'INSERT' OR NOT (o ->> 'status') = ANY (frozen) THEN
            RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
        END IF;
        IF TG_OP = 'DELETE' THEN
            IF mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
                RETURN OLD;
            END IF;
            RAISE EXCEPTION '%.% %: a % revision cannot be deleted', TG_TABLE_SCHEMA, TG_TABLE_NAME, o ->> 'id', o ->> 'status'
                USING ERRCODE = 'integrity_constraint_violation';
        END IF;
        IF (n - refs) = (o - refs) THEN
            RETURN NEW;                                        -- a product or supplier merge
        END IF;
        IF (n - lifecycle) = (o - lifecycle)
           AND ((n ->> 'status') = (o ->> 'status')
                OR ((o ->> 'status') = 'released' AND (n ->> 'status') IN ('superseded', 'obsolete'))
                OR ((o ->> 'status') = 'superseded' AND (n ->> 'status') = 'obsolete')) THEN
            RETURN NEW;                                        -- the lifecycle
        END IF;
        RAISE EXCEPTION '%.% %: a % revision is frozen; make a new revision instead',
            TG_TABLE_SCHEMA, TG_TABLE_NAME, o ->> 'id', o ->> 'status'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;

    -- ---------------------------------------------------- a child row of a header
    -- TG_ARGV[0] is the header table, TG_ARGV[1] the column here that holds its id.
    FOREACH pid IN ARRAY ARRAY[o ->> TG_ARGV[1], n ->> TG_ARGV[1]] LOOP
        CONTINUE WHEN pid IS NULL;
        EXECUTE format('SELECT status FROM %s WHERE id = $1', TG_ARGV[0]) INTO st USING pid;
        CONTINUE WHEN st IS NULL OR NOT st = ANY (frozen);
        IF TG_OP = 'UPDATE' AND (n - refs) = (o - refs) THEN
            RETURN NEW;                                        -- a product or supplier merge
        END IF;
        IF TG_OP = 'DELETE' AND mfg.mfg_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION '%.%: % of a % revision is not allowed; make a new revision instead',
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, st
            USING ERRCODE = 'integrity_constraint_violation';
    END LOOP;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$f$;

-- Monthly partitions in UTC, named <table>_yYYYYmMM, plus <table>_default so a write with a
-- surprising date (a tablet with a wrong clock) never fails; the upkeep job alerts when the
-- default partition holds rows. If the default already holds rows of a month being added, that
-- month is skipped with a WARNING (its rows stay in the default) rather than failing the deploy.
CREATE OR REPLACE FUNCTION mfg.mfg_ensure_partitions(p_table text, p_months_ahead integer DEFAULT 3)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    parent regclass := to_regclass('mfg.' || p_table);
    m      date;
    part   text;
    i      integer;
BEGIN
    IF parent IS NULL OR (SELECT relkind FROM pg_class WHERE oid = parent) <> 'p' THEN
        RAISE EXCEPTION 'mfg_ensure_partitions: mfg.% is not a partitioned table', p_table;
    END IF;
    IF (SELECT partdefid FROM pg_partitioned_table WHERE partrelid = parent) = 0 THEN
        EXECUTE format('CREATE TABLE IF NOT EXISTS mfg.%I PARTITION OF mfg.%I DEFAULT', p_table || '_default', p_table);
    END IF;
    FOR i IN 0 .. greatest(p_months_ahead, 1) LOOP
        m := (date_trunc('month', now() AT TIME ZONE 'UTC') + make_interval(months => i))::date;
        part := format('%s_y%sm%s', p_table, to_char(m, 'YYYY'), to_char(m, 'MM'));
        CONTINUE WHEN to_regclass('mfg.' || part) IS NOT NULL;
        BEGIN
            EXECUTE format('CREATE TABLE mfg.%I PARTITION OF mfg.%I FOR VALUES FROM (%L) TO (%L)',
                           part, p_table,
                           to_char(m, 'YYYY-MM-DD') || ' 00:00:00+00',
                           to_char((m + interval '1 month')::date, 'YYYY-MM-DD') || ' 00:00:00+00');
        EXCEPTION WHEN check_violation THEN
            RAISE WARNING 'mfg_ensure_partitions: mfg.%_default holds rows of %; partition % not made', p_table, to_char(m, 'YYYY-MM'), part;
        END;
    END LOOP;
END
$f$;

-- ========================================================================= settings
CREATE TABLE IF NOT EXISTS mfg.mfg_settings (
    id                          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                   text NOT NULL,
    org_id                      text,
    bus_id                      text NOT NULL UNIQUE,
    default_plant_id            text,
    costing_method              text NOT NULL DEFAULT 'standard',   -- standard | actual; valuation stays the ledger's
    backflush_default           boolean NOT NULL DEFAULT false,
    allow_over_production_pct   numeric(6,2) NOT NULL DEFAULT 0,    -- the API's over_delivery_pct
    under_delivery_pct          numeric(6,2) NOT NULL DEFAULT 0,
    require_lot_on_issue        boolean NOT NULL DEFAULT false,
    confirmation_window_hours   integer NOT NULL DEFAULT 24,        -- older offline reports are flagged late
    block_release_on_shortage   boolean NOT NULL DEFAULT false,
    status_labels               jsonb NOT NULL DEFAULT '{}',        -- a label per fixed status (02 §11)
    version                     integer NOT NULL DEFAULT 1,
    cdatetime                   timestamptz NOT NULL DEFAULT now(),
    created_by                  text,
    updated_at                  timestamptz NOT NULL DEFAULT now(),
    updated_by                  text
);
ALTER TABLE mfg.mfg_settings DROP CONSTRAINT IF EXISTS mfg_settings_pct_check;
ALTER TABLE mfg.mfg_settings ADD CONSTRAINT mfg_settings_pct_check
    CHECK (allow_over_production_pct BETWEEN 0 AND 1000 AND under_delivery_pct BETWEEN 0 AND 100
           AND confirmation_window_hours >= 0);

CREATE TABLE IF NOT EXISTS mfg.mfg_number_series (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    kind         text NOT NULL,                 -- production_order (R1); ncr, eco, maintenance_order later
    prefix       text NOT NULL,
    next_value   bigint NOT NULL DEFAULT 1,
    padding      integer NOT NULL DEFAULT 5,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    PRIMARY KEY (bus_id, kind)
);
ALTER TABLE mfg.mfg_number_series DROP CONSTRAINT IF EXISTS mfg_number_series_values_check;
ALTER TABLE mfg.mfg_number_series ADD CONSTRAINT mfg_number_series_values_check
    CHECK (next_value > 0 AND padding BETWEEN 0 AND 12);
COMMENT ON TABLE mfg.mfg_number_series IS
    'Document numbering per business and kind. Default: production_order MO-, padding 5. Taken with SELECT ... FOR UPDATE.';

-- A repeated key with the same request_hash gets the stored response; a different hash is refused.
-- Purged after 7 days by the upkeep job.
CREATE TABLE IF NOT EXISTS mfg.mfg_idempotency_keys (
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    key           text NOT NULL,                -- the client's UUID (Idempotency-Key, or the offline action id)
    route         text NOT NULL,
    request_hash  text NOT NULL,
    status_code   integer NOT NULL,
    response      jsonb NOT NULL,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, key)
);
CREATE INDEX IF NOT EXISTS mfg_idempotency_keys_age_idx ON mfg.mfg_idempotency_keys (cdatetime);

CREATE TABLE IF NOT EXISTS mfg.mfg_custom_fields (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    entity         text NOT NULL,              -- production_order, item, work_center, ...
    key            text NOT NULL,
    label          text NOT NULL,
    type           text NOT NULL,
    validation     jsonb NOT NULL DEFAULT '{}',
    required       boolean NOT NULL DEFAULT false,
    visible_roles  text[] NOT NULL DEFAULT '{}',
    position       integer NOT NULL DEFAULT 0,
    archived_at    timestamptz,
    version        integer NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    updated_by     text,
    UNIQUE (bus_id, entity, key)
);
ALTER TABLE mfg.mfg_custom_fields DROP CONSTRAINT IF EXISTS mfg_custom_fields_key_check;
ALTER TABLE mfg.mfg_custom_fields ADD CONSTRAINT mfg_custom_fields_key_check CHECK (key ~ '^[a-z][a-z0-9_]{0,62}$');

-- ===================================================================== invariants
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['mfg_purge_allowed', 'mfg_refuse_change', 'mfg_freeze_released', 'mfg_ensure_partitions'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
                        WHERE s.nspname = 'mfg' AND p.proname = f) THEN
            RAISE EXCEPTION 'mfg.% is missing', f;
        END IF;
    END LOOP;
END $$;

COMMIT;
