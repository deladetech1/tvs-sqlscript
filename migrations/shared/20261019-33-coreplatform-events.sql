-- =====================================================================
-- Events: what happened, written once, read by any app that cares
-- ---------------------------------------------------------------------
-- Apps told each other things by hand, one pair at a time: a queue from Invoicing to
-- MyStoreGuard, a view here, a sync job there. From now on, something that happened to the
-- business's shared records is written once, as an event, in the same transaction as the
-- change; an app that wants to know reads the events after the last one it saw.
--
--   core_platform.cp_events         one row per thing that happened: party.created,
--                                   party.updated, party.merged, party.deleted, and the same
--                                   for products; who it happened to (subject_id), and a JSON
--                                   payload of what changed
--   core_platform.cp_event_cursors  each reader's place: the last event it handled
--
-- Reading safely. Ids are handed out when a row is inserted but a row is visible only when
-- its transaction commits, so a reader going by "id greater than the last" could pass over an
-- event committed late with a smaller id. Events are read only up to the oldest transaction
-- still running (txid < pg_snapshot_xmin): everything before that point is final.
-- core_platform.cp_events_after(reader, limit) does exactly that.
--
-- Events are kept 90 days (purged with the activity logs: tenant_id + cdatetime).
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_events (
    id          bigserial PRIMARY KEY,
    tenant_id   text NOT NULL,
    bus_id      text,
    source_app  text NOT NULL DEFAULT '',
    kind        text NOT NULL CHECK (kind ~ '^[a-z_]+\.[a-z_]+$'),
    subject_id  text NOT NULL,
    payload     jsonb NOT NULL DEFAULT '{}',
    txid        xid8 NOT NULL DEFAULT pg_current_xact_id(),
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cp_events_kind_idx ON core_platform.cp_events (kind, id);
CREATE INDEX IF NOT EXISTS cp_events_subject_idx ON core_platform.cp_events (subject_id);
CREATE INDEX IF NOT EXISTS cp_events_cdatetime_idx ON core_platform.cp_events (cdatetime);

CREATE TABLE IF NOT EXISTS core_platform.cp_event_cursors (
    reader     text PRIMARY KEY,
    last_id    bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- publish: an event, in the caller's transaction.
CREATE OR REPLACE FUNCTION core_platform.cp_event_publish(p_tenant text, p_bus text, p_source text, p_kind text, p_subject text, p_payload jsonb DEFAULT '{}')
RETURNS bigint LANGUAGE sql AS $f$
    INSERT INTO core_platform.cp_events (tenant_id, bus_id, source_app, kind, subject_id, payload)
    VALUES (p_tenant, p_bus, coalesce(p_source, ''), p_kind, p_subject, coalesce(p_payload, '{}'))
    RETURNING id
$f$;

-- after: the next events for a reader (of some kinds, or all), oldest first, only those that are
-- final. The reader moves its cursor with cp_event_ack once it has handled them.
CREATE OR REPLACE FUNCTION core_platform.cp_events_after(p_reader text, p_limit integer DEFAULT 500, p_kinds text[] DEFAULT NULL)
RETURNS SETOF core_platform.cp_events LANGUAGE sql STABLE AS $f$
    SELECT e.* FROM core_platform.cp_events e
     WHERE e.id > coalesce((SELECT last_id FROM core_platform.cp_event_cursors WHERE reader = p_reader), 0)
       AND e.txid < pg_snapshot_xmin(pg_current_snapshot())
       AND (p_kinds IS NULL OR e.kind = ANY (p_kinds))
     ORDER BY e.id
     LIMIT greatest(1, least(coalesce(p_limit, 500), 5000))
$f$;

-- ack: the reader has handled everything up to p_last_id (never moves backwards).
CREATE OR REPLACE FUNCTION core_platform.cp_event_ack(p_reader text, p_last_id bigint)
RETURNS void LANGUAGE sql AS $f$
    INSERT INTO core_platform.cp_event_cursors (reader, last_id) VALUES (p_reader, p_last_id)
    ON CONFLICT (reader) DO UPDATE SET last_id = greatest(core_platform.cp_event_cursors.last_id, EXCLUDED.last_id), updated_at = now()
$f$;

-- ===================================================================== the shared records' events
CREATE OR REPLACE FUNCTION core_platform.cp_parties_event() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE k text; changed jsonb := '{}';
BEGIN
    IF TG_OP = 'INSERT' THEN
        k := 'party.created';
        changed := jsonb_build_object('name', NEW.name, 'is_customer', NEW.is_customer, 'is_supplier', NEW.is_supplier);
    ELSIF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        -- A merge says so itself (party.merged, from cp_party_merge); this is a deletion.
        IF current_setting('cp.merging', true) = NEW.id THEN
            RETURN NEW;
        END IF;
        k := 'party.deleted';
    ELSE
        SELECT coalesce(jsonb_object_agg(n.key, n.value), '{}') INTO changed
          FROM jsonb_each(to_jsonb(NEW)) n JOIN jsonb_each(to_jsonb(OLD)) o ON o.key = n.key
         WHERE n.value IS DISTINCT FROM o.value AND n.key NOT IN ('updated_at', 'updated_by');
        IF changed = '{}' THEN
            RETURN NEW;
        END IF;
        k := 'party.updated';
    END IF;
    PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, NEW.source_app, k, NEW.id, changed);
    RETURN NEW;
END
$f$;

CREATE OR REPLACE FUNCTION core_platform.cp_products_event() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE k text; changed jsonb := '{}'; r core_platform.cp_products;
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF current_setting('cp.merging', true) IS DISTINCT FROM OLD.id THEN
            PERFORM core_platform.cp_event_publish(OLD.tenant_id, OLD.bus_id, OLD.source_app, 'product.deleted', OLD.id, jsonb_build_object('name', OLD.name));
        END IF;
        RETURN OLD;
    END IF;
    IF TG_OP = 'INSERT' THEN
        k := 'product.created';
        changed := jsonb_build_object('name', NEW.name, 'sku', NEW.sku, 'parent_id', NEW.parent_id, 'variant', NEW.variant);
    ELSE
        SELECT coalesce(jsonb_object_agg(n.key, n.value), '{}') INTO changed
          FROM jsonb_each(to_jsonb(NEW)) n JOIN jsonb_each(to_jsonb(OLD)) o ON o.key = n.key
         WHERE n.value IS DISTINCT FROM o.value AND n.key NOT IN ('updated_at', 'updated_by');
        IF changed = '{}' THEN
            RETURN NEW;
        END IF;
        k := 'product.updated';
    END IF;
    PERFORM core_platform.cp_event_publish(NEW.tenant_id, NEW.bus_id, NEW.source_app, k, NEW.id, changed);
    RETURN NEW;
END
$f$;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_parties') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS cp_parties_event ON core_platform.cp_parties;
        CREATE TRIGGER cp_parties_event AFTER INSERT OR UPDATE ON core_platform.cp_parties
            FOR EACH ROW EXECUTE FUNCTION core_platform.cp_parties_event();
        ALTER TABLE core_platform.cp_parties ENABLE ALWAYS TRIGGER cp_parties_event;
    END IF;
    IF to_regclass('core_platform.cp_products') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS cp_products_event ON core_platform.cp_products;
        CREATE TRIGGER cp_products_event AFTER INSERT OR UPDATE OR DELETE ON core_platform.cp_products
            FOR EACH ROW EXECUTE FUNCTION core_platform.cp_products_event();
        ALTER TABLE core_platform.cp_products ENABLE ALWAYS TRIGGER cp_products_event;
    END IF;
END $$;

COMMIT;
