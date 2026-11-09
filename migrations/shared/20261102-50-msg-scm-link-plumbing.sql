-- MyStoreGuard <-> Supply Chain (SCM), phase 2: the plumbing (apps-setup/msg-scm-integration-plan.md §3-4).
--
-- Two links in Core Platform's Connected apps catalogue (app_connections_catalogue.py), per
-- business, OFF by default (no row in cp_app_connections is OFF, and this file writes none):
--
--   scm-mystoreguard   SCM supplies MyStoreGuard branches (shipments, POs delivered to a branch)
--   mystoreguard-scm   MyStoreGuard asks SCM to restock and sends stock back to a warehouse
--
-- Documents cross as EVENTS, never as writes into the other app's tables:
--
--   outbox   core_platform.cp_events (20261019-33), published in the sender's transaction.
--            Every payload is an envelope: {"v": 1, "link": "<link key>", "idempotency_key":
--            "<sender's key>", "data": {...}}.
--   catalogue core_platform.cp_event_schemas (this file): each kind and version, the link it
--            travels on, who sends and who receives, and its JSON schema. Receivers refuse a kind
--            or version that is not here (DEAD, "unknown event") and data missing a required key.
--   inbox    one per receiving app, processed once: scm.scm_link_inbox and
--            mystoreguard.msg_link_inbox, unique on (tenant_id, source_app, idempotency_key), so an
--            event sent twice is taken in once. A reader copies its kinds from cp_events into its
--            inbox and moves its cp_event_cursors place in the same transaction; a worker then
--            handles each row: DONE, RETRY (attempts, next_attempt_at: backoff), DEAD (gave up, or
--            unusable) or REFUSED (the link is off or a subscription is missing: the receiver
--            checks, and fails closed). DEAD and REFUSED are the dead letters: Core Platform ->
--            Connected apps lists them and can send them back (<schema>.<inbox>_retry, which only
--            makes the row PENDING again: the receiver applies every rule again).
--   mapping  scm.scm_branch_supply: which SCM warehouse supplies which MyStoreGuard place (a Core
--            location and its side, STORE or WAREHOUSE). One supplier per place.
--
-- Event kinds are noun_verb under the sender's prefix (cp_events.kind allows one dot). Phase 2
-- defines them and handles only the ping/pong pair (a round trip proving the plumbing); phases 3
-- and 4 give the others their behaviour.
--
-- Idempotent; safe to re-run. This file owns the catalogue rows (later-migration-wins: a newer
-- file that changes a schema adds a version rather than editing this one).

BEGIN;

-- ===================================================================== event catalogue
CREATE TABLE IF NOT EXISTS core_platform.cp_event_schemas (
    kind         text NOT NULL CHECK (kind ~ '^[a-z_]+\.[a-z_]+$'),
    version      integer NOT NULL CHECK (version >= 1),
    link_key     text NOT NULL,
    source_app   text NOT NULL,
    target_app   text NOT NULL,
    phase        smallint NOT NULL DEFAULT 2,
    description  text NOT NULL DEFAULT '',
    schema       jsonb NOT NULL,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, version)
);

-- The envelope every link event shares; each kind's "data" is merged in below.
WITH envelope AS (
    SELECT jsonb_build_object(
        '$schema', 'https://json-schema.org/draft/2020-12/schema',
        'type', 'object',
        'required', jsonb_build_array('v', 'link', 'idempotency_key', 'data'),
        'properties', jsonb_build_object(
            'v', jsonb_build_object('type', 'integer', 'minimum', 1),
            'link', jsonb_build_object('type', 'string'),
            'idempotency_key', jsonb_build_object('type', 'string', 'minLength', 1, 'maxLength', 200),
            'sent_at', jsonb_build_object('type', 'string', 'format', 'date-time'),
            'sent_by', jsonb_build_object('type', 'string'))) AS e
), kinds (kind, version, link_key, source_app, target_app, phase, description, data) AS (
    SELECT * FROM (VALUES
    ('scm.link_ping', 1, 'scm-mystoreguard', 'app-scm', 'app-mystoreguard', 2,
     'A test message from SCM; MyStoreGuard answers msg.link_pong. Proves the link end to end.',
     '{"type":"object","required":["ping_id"],"properties":{"ping_id":{"type":"string"},"note":{"type":"string"}}}'::jsonb),
    ('msg.link_pong', 1, 'scm-mystoreguard', 'app-mystoreguard', 'app-scm', 2,
     'MyStoreGuard''s answer to scm.link_ping.',
     '{"type":"object","required":["ping_id","ping_event_id"],"properties":{"ping_id":{"type":"string"},"ping_event_id":{"type":"integer"},"received_at":{"type":"string","format":"date-time"}}}'::jsonb),
    ('msg.link_ping', 1, 'mystoreguard-scm', 'app-mystoreguard', 'app-scm', 2,
     'A test message from MyStoreGuard; SCM answers scm.link_pong.',
     '{"type":"object","required":["ping_id"],"properties":{"ping_id":{"type":"string"},"note":{"type":"string"}}}'::jsonb),
    ('scm.link_pong', 1, 'mystoreguard-scm', 'app-scm', 'app-mystoreguard', 2,
     'SCM''s answer to msg.link_ping.',
     '{"type":"object","required":["ping_id","ping_event_id"],"properties":{"ping_id":{"type":"string"},"ping_event_id":{"type":"integer"},"received_at":{"type":"string","format":"date-time"}}}'::jsonb),
    ('scm.branch_shipment_sent', 1, 'scm-mystoreguard', 'app-scm', 'app-mystoreguard', 3,
     'SCM dispatched stock from a warehouse to a MyStoreGuard branch: MyStoreGuard opens an incoming delivery for a person to confirm.',
     '{"type":"object","required":["shipment_id","number","warehouse_id","loc_id","side","currency","lines"],"properties":{
        "shipment_id":{"type":"string"},"number":{"type":"string"},"warehouse_id":{"type":"string"},
        "loc_id":{"type":"string"},"side":{"enum":["STORE","WAREHOUSE"]},"dispatched_at":{"type":"string","format":"date-time"},
        "expected_at":{"type":"string","format":"date"},"currency":{"type":"string","minLength":3,"maxLength":3},
        "lines":{"type":"array","minItems":1,"items":{"type":"object","required":["line_id","product_id","qty","unit_cost"],"properties":{
          "line_id":{"type":"string"},"product_id":{"type":"string"},"kind":{"type":"string"},"qty":{"type":"integer","minimum":1},
          "unit_cost":{"type":"string"},"suggested_price":{"type":"string"},"lot_number":{"type":"string"},
          "expiry_date":{"type":"string","format":"date"},
          "serials":{"type":"array","items":{"type":"object","required":["serial"],"properties":{"serial":{"type":"string"},"imei":{"type":"string"},"barcode":{"type":"string"}}}}}}}}}'::jsonb),
    ('scm.po_receipt_for_branch', 1, 'scm-mystoreguard', 'app-scm', 'app-mystoreguard', 3,
     'A supplier is delivering an SCM purchase order straight to a MyStoreGuard branch: MyStoreGuard opens an incoming delivery; its receipt closes the PO line.',
     '{"type":"object","required":["po_id","po_number","supplier_party_id","loc_id","side","currency","lines"],"properties":{
        "po_id":{"type":"string"},"po_number":{"type":"string"},"supplier_party_id":{"type":"string"},
        "loc_id":{"type":"string"},"side":{"enum":["STORE","WAREHOUSE"]},"expected_at":{"type":"string","format":"date"},
        "currency":{"type":"string","minLength":3,"maxLength":3},
        "lines":{"type":"array","minItems":1,"items":{"type":"object","required":["po_line_id","product_id","qty","unit_cost"],"properties":{
          "po_line_id":{"type":"string"},"product_id":{"type":"string"},"kind":{"type":"string"},"qty":{"type":"integer","minimum":1},
          "unit_cost":{"type":"string"},"suggested_price":{"type":"string"}}}}}}'::jsonb),
    ('msg.branch_delivery_received', 1, 'scm-mystoreguard', 'app-mystoreguard', 'app-scm', 3,
     'MyStoreGuard confirmed an incoming delivery from SCM: what arrived and what was short, line by line.',
     '{"type":"object","required":["source_kind","source_id","delivery_id","received_at","lines"],"properties":{
        "source_kind":{"enum":["shipment","purchase_order"]},"source_id":{"type":"string"},"delivery_id":{"type":"string"},
        "received_at":{"type":"string","format":"date-time"},
        "lines":{"type":"array","items":{"type":"object","required":["source_line_id","qty_received"],"properties":{
          "source_line_id":{"type":"string"},"qty_received":{"type":"integer","minimum":0},"qty_short":{"type":"integer","minimum":0},
          "batch_id":{"type":"string"}}}}}}'::jsonb),
    ('msg.reorder_requested', 1, 'mystoreguard-scm', 'app-mystoreguard', 'app-scm', 4,
     'A MyStoreGuard branch is low: SCM drafts a requisition (platform/purchasing.CreateRequisition).',
     '{"type":"object","required":["request_id","loc_id","side","lines"],"properties":{
        "request_id":{"type":"string"},"loc_id":{"type":"string"},"side":{"enum":["STORE","WAREHOUSE"]},
        "needed_by":{"type":"string","format":"date"},"note":{"type":"string"},
        "lines":{"type":"array","minItems":1,"items":{"type":"object","required":["product_id","qty"],"properties":{
          "product_id":{"type":"string"},"kind":{"type":"string"},"qty":{"type":"integer","minimum":1},
          "on_hand":{"type":"integer"},"reorder_level":{"type":"integer"}}}}}}'::jsonb),
    ('msg.return_to_warehouse_sent', 1, 'mystoreguard-scm', 'app-mystoreguard', 'app-scm', 4,
     'MyStoreGuard sent stock back to an SCM warehouse: SCM opens a return receipt; stock enters at the batch''s cost.',
     '{"type":"object","required":["return_id","number","loc_id","warehouse_id","currency","lines"],"properties":{
        "return_id":{"type":"string"},"number":{"type":"string"},"loc_id":{"type":"string"},"warehouse_id":{"type":"string"},
        "currency":{"type":"string","minLength":3,"maxLength":3},"reason":{"type":"string"},
        "lines":{"type":"array","minItems":1,"items":{"type":"object","required":["product_id","batch_id","qty","unit_cost"],"properties":{
          "product_id":{"type":"string"},"kind":{"type":"string"},"batch_id":{"type":"string"},"qty":{"type":"integer","minimum":1},
          "unit_cost":{"type":"string"},"expiry_date":{"type":"string","format":"date"},
          "serials":{"type":"array","items":{"type":"object","required":["serial"],"properties":{"serial":{"type":"string"},"imei":{"type":"string"},"barcode":{"type":"string"}}}}}}}}}'::jsonb),
    ('scm.return_received', 1, 'mystoreguard-scm', 'app-scm', 'app-mystoreguard', 4,
     'SCM took in a return from a MyStoreGuard branch: what arrived, line by line.',
     '{"type":"object","required":["return_id","receipt_id","received_at","lines"],"properties":{
        "return_id":{"type":"string"},"receipt_id":{"type":"string"},"received_at":{"type":"string","format":"date-time"},
        "lines":{"type":"array","items":{"type":"object","required":["batch_id","qty_received"],"properties":{
          "batch_id":{"type":"string"},"qty_received":{"type":"integer","minimum":0}}}}}}'::jsonb)
    ) v
)
INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
SELECT k.kind, k.version, k.link_key, k.source_app, k.target_app, k.phase, k.description,
       jsonb_set(e.e, '{properties,data}', k.data) || jsonb_build_object('title', k.kind || ' v' || k.version), now()
  FROM kinds k CROSS JOIN envelope e
ON CONFLICT (kind, version) DO UPDATE SET
    link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
    phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
    updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                        OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                      THEN now() ELSE core_platform.cp_event_schemas.updated_at END;

-- ===================================================================== SCM: mapping and inbox
DO $$
BEGIN
    IF to_regclass('scm.scm_warehouses') IS NULL THEN
        RAISE NOTICE 'msg-scm plumbing: no SCM schema here: its mapping and inbox come with it';
        RETURN;
    END IF;

    -- Which SCM warehouse supplies which MyStoreGuard place (a Core location, and its side: the
    -- shop floor STORE or the stockroom WAREHOUSE). One supplier per place; a warehouse supplies
    -- any number of places. SCM refuses mapping a warehouse onto its own location's stockroom
    -- (one owner per place, decision 1).
    CREATE TABLE IF NOT EXISTS scm.scm_branch_supply (
        id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id     text NOT NULL,
        org_id        text,
        bus_id        text NOT NULL,
        warehouse_id  text NOT NULL REFERENCES scm.scm_warehouses (id),
        loc_id        text NOT NULL,
        side          text NOT NULL DEFAULT 'STORE',
        note          text,
        cdatetime     timestamptz NOT NULL DEFAULT now(),
        created_by    text,
        updated_at    timestamptz NOT NULL DEFAULT now(),
        updated_by    text,
        CONSTRAINT ck_scm_branch_supply_side CHECK (side IN ('STORE', 'WAREHOUSE'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS scm_branch_supply_place_uq ON scm.scm_branch_supply (tenant_id, bus_id, loc_id, side);
    CREATE INDEX IF NOT EXISTS scm_branch_supply_warehouse_idx ON scm.scm_branch_supply (tenant_id, bus_id, warehouse_id);

    CREATE TABLE IF NOT EXISTS scm.scm_link_inbox (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        link_key         text NOT NULL,
        source_app       text NOT NULL,
        kind             text NOT NULL,
        version          integer NOT NULL DEFAULT 1,
        event_id         bigint NOT NULL,
        idempotency_key  text NOT NULL,
        subject_id       text NOT NULL DEFAULT '',
        payload          jsonb NOT NULL DEFAULT '{}',
        sent_at          timestamptz NOT NULL,
        status           text NOT NULL DEFAULT 'PENDING',
        attempts         integer NOT NULL DEFAULT 0,
        next_attempt_at  timestamptz NOT NULL DEFAULT now(),
        claimed_until    timestamptz,
        last_error       text,
        result           jsonb,
        received_at      timestamptz NOT NULL DEFAULT now(),
        handled_at       timestamptz,
        CONSTRAINT ck_scm_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS scm_link_inbox_once ON scm.scm_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS scm_link_inbox_due ON scm.scm_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS scm_link_inbox_business ON scm.scm_link_inbox (tenant_id, bus_id, received_at DESC);
END $$;

-- ===================================================================== MyStoreGuard: inbox
DO $$
BEGIN
    IF to_regnamespace('mystoreguard') IS NULL THEN
        RAISE NOTICE 'msg-scm plumbing: no mystoreguard schema here: its inbox comes with it';
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS mystoreguard.msg_link_inbox (
        id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        link_key         text NOT NULL,
        source_app       text NOT NULL,
        kind             text NOT NULL,
        version          integer NOT NULL DEFAULT 1,
        event_id         bigint NOT NULL,
        idempotency_key  text NOT NULL,
        subject_id       text NOT NULL DEFAULT '',
        payload          jsonb NOT NULL DEFAULT '{}',
        sent_at          timestamptz NOT NULL,
        status           text NOT NULL DEFAULT 'PENDING',
        attempts         integer NOT NULL DEFAULT 0,
        next_attempt_at  timestamptz NOT NULL DEFAULT now(),
        claimed_until    timestamptz,
        last_error       text,
        result           jsonb,
        received_at      timestamptz NOT NULL DEFAULT now(),
        handled_at       timestamptz,
        CONSTRAINT ck_msg_link_inbox_status CHECK (status IN ('PENDING', 'RETRY', 'DONE', 'REFUSED', 'DEAD'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS msg_link_inbox_once ON mystoreguard.msg_link_inbox (tenant_id, source_app, idempotency_key);
    CREATE INDEX IF NOT EXISTS msg_link_inbox_due ON mystoreguard.msg_link_inbox (next_attempt_at) WHERE status IN ('PENDING', 'RETRY');
    CREATE INDEX IF NOT EXISTS msg_link_inbox_business ON mystoreguard.msg_link_inbox (tenant_id, bus_id, received_at DESC);
END $$;

-- ===================================================================== try a dead letter again
-- What Core Platform -> Connected apps calls: puts DEAD / REFUSED rows of one business back to
-- PENDING (all of them, or the ids given). Nothing else: the receiver checks the switch, the
-- subscriptions and the event again on its next pass. Answers how many it sent back.
DO $$
BEGIN
    IF to_regclass('scm.scm_link_inbox') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION scm.scm_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
        RETURNS integer LANGUAGE sql AS $f$
            WITH r AS (
                UPDATE scm.scm_link_inbox
                   SET status = 'PENDING', attempts = 0, next_attempt_at = now(), claimed_until = NULL
                 WHERE tenant_id = p_tenant AND bus_id = p_bus AND status IN ('DEAD', 'REFUSED')
                   AND (p_ids IS NULL OR id = ANY (p_ids))
                RETURNING 1)
            SELECT count(*)::integer FROM r
        $f$;
    END IF;
    IF to_regclass('mystoreguard.msg_link_inbox') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION mystoreguard.msg_link_inbox_retry(p_tenant text, p_bus text, p_ids text[] DEFAULT NULL)
        RETURNS integer LANGUAGE sql AS $f$
            WITH r AS (
                UPDATE mystoreguard.msg_link_inbox
                   SET status = 'PENDING', attempts = 0, next_attempt_at = now(), claimed_until = NULL
                 WHERE tenant_id = p_tenant AND bus_id = p_bus AND status IN ('DEAD', 'REFUSED')
                   AND (p_ids IS NULL OR id = ANY (p_ids))
                RETURNING 1)
            SELECT count(*)::integer FROM r
        $f$;
    END IF;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
     WHERE link_key IN ('scm-mystoreguard', 'mystoreguard-scm')
       AND (split_part(kind, '.', 1) <> CASE source_app WHEN 'app-scm' THEN 'scm' WHEN 'app-mystoreguard' THEN 'msg' END
            OR schema #> '{properties,data}' IS NULL);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'msg-scm plumbing: catalogue rows whose prefix does not name the sender, or with no data schema: %', bad;
    END IF;
    -- The links start OFF for everyone: this file must never have switched one on.
    IF to_regclass('core_platform.cp_app_connections') IS NOT NULL AND EXISTS (
        SELECT 1 FROM core_platform.cp_app_connections
         WHERE link_key IN ('scm-mystoreguard', 'mystoreguard-scm') AND changed_by = 'system') THEN
        RAISE EXCEPTION 'msg-scm plumbing: a system row switched an MSG<->SCM link on; they start OFF';
    END IF;
END $$;

COMMIT;
