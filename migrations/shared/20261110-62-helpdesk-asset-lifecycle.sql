-- Help Desk phase 3b: the asset lifecycle through SCM and Accounting, and licence terms
-- (tvs-shared-apps-bk docs/helpdesk/contracts/P3-field-service-assets.md §1, §2, §4, §5).
--
-- Two links in Core Platform -> Connected apps (app_connections_catalogue.py), per business, OFF until a
-- business turns them on (no row in cp_app_connections is OFF; this file writes none, no backfill):
--
--   helpdesk-scm         Help Desk <-> SCM (two-way): helpdesk.equipment_requested (Help Desk -> SCM; SCM's
--                        inbox scm.scm_link_inbox makes the requisition with SCM's own code), answered by
--                        scm.equipment_status and scm.equipment_received (SCM -> Help Desk; Help Desk's inbox
--                        helpdesk.hd_link_inbox fills the assets). Each receiver enforces, failing closed.
--   helpdesk-accounting  Help Desk -> Accounting: helpdesk.asset_disposed, posted by Accounting's PostingRun.
--
-- Neither app writes the other's tables:
--   * helpdesk.hd_catalog_equipment     a "request equipment" catalogue item: which SCM item, asset type, warranty
--   * helpdesk.hd_equipment_requests    one per approved request: what was asked of SCM and how it went
--   * helpdesk.hd_assets                + equipment_request_id, scm_receipt_line_id, scm_unit_key; licence terms
--   * helpdesk.hd_asset_disposals       the disposal record that Accounting is told of
--   * scm.scm_requisitions              + hd_request_id, hd_ticket_number (written by SCM's inbox)
--   * helpdesk.src_scm_items            a read-only view of SCM's items for the catalogue setup screen
--
-- Plan feature helpdesk.asset-lifecycle (PREMIUM, rank 3). Idempotent; safe to re-run on every deploy. This
-- file owns the catalogue rows of its four event kinds (a newer file that changes a schema adds a version).

BEGIN;

-- ===================================================================== event catalogue
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'helpdesk asset lifecycle: no event catalogue here; skipping its rows';
        RETURN;
    END IF;
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
        ('helpdesk.equipment_requested', 1, 'helpdesk-scm', 'app-helpdesk', 'app-scm', 1,
         'An approved Help Desk equipment request: SCM makes a requisition for it with its own rules, and answers how it goes.',
         '{"type":"object","required":["request_id","ticket_id","number","title","product_id","qty","approved_by"],"properties":{
            "request_id":{"type":"string"},"ticket_id":{"type":"string"},"number":{"type":"string"},"title":{"type":"string","minLength":1},
            "product_id":{"type":"string"},"qty":{"type":"integer","minimum":1,"maximum":50},"approved_by":{"type":"string"},
            "requested_by":{"type":"string"},"requester_name":{"type":"string"},"needed_by":{"type":"string","format":"date"},
            "note":{"type":"string"},"link":{"type":"string"}}}'::jsonb),
        ('scm.equipment_status', 1, 'helpdesk-scm', 'app-scm', 'app-helpdesk', 1,
         'Where SCM''s requisition for a Help Desk equipment request stands: submitted, approved, rejected, cancelled, ordered, or refused.',
         '{"type":"object","required":["request_id","status"],"properties":{
            "request_id":{"type":"string"},"status":{"enum":["submitted","approved","rejected","cancelled","ordered","refused"]},
            "requisition_id":{"type":"string"},"requisition_number":{"type":"string"},"purchase_order_number":{"type":"string"},
            "reason":{"type":"string"},"at":{"type":"string","format":"date-time"}}}'::jsonb),
        ('scm.equipment_received', 1, 'helpdesk-scm', 'app-scm', 'app-helpdesk', 1,
         'Goods SCM received for a Help Desk equipment request: Help Desk makes or fills its assets (serials, cost, supplier, warranty).',
         '{"type":"object","required":["request_id","receipt_id","receipt_number","lines"],"properties":{
            "request_id":{"type":"string"},"receipt_id":{"type":"string"},"receipt_number":{"type":"string"},
            "requisition_id":{"type":"string"},"requisition_number":{"type":"string"},
            "purchase_order_id":{"type":"string"},"purchase_order_number":{"type":"string"},
            "received_at":{"type":"string","format":"date-time"},"supplier_party_id":{"type":"string"},"supplier_name":{"type":"string"},
            "currency":{"type":"string"},
            "lines":{"type":"array","maxItems":500,"items":{"type":"object","required":["receipt_line_id","product_id","qty"],"properties":{
              "receipt_line_id":{"type":"string"},"product_id":{"type":"string"},"product_name":{"type":"string"},
              "qty":{"type":"string"},"unit_cost":{"type":"string"},"serials":{"type":"array","items":{"type":"string"}}}}}}}'::jsonb)
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

    -- Into the books (a plain payload, as HMS's; Accounting reads it, not a link inbox).
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    VALUES ('helpdesk.asset_disposed', 1, 'helpdesk-accounting', 'app-helpdesk', 'app-accounting', 1,
        'A Help Desk asset disposed of or written off: Accounting disposes of it in its fixed-asset register when it holds it, else books any proceeds.',
        jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'title', 'helpdesk.asset_disposed v1', 'type', 'object',
            'required', jsonb_build_array('version', 'app', 'id', 'document_number', 'date', 'asset_id', 'asset_tag', 'method', 'cost', 'proceeds'),
            'properties', jsonb_build_object(
                'version', jsonb_build_object('type', 'integer', 'const', 1), 'app', jsonb_build_object('type', 'string', 'const', 'helpdesk'),
                'org_id', jsonb_build_object('type', 'string'), 'id', jsonb_build_object('type', 'string'),
                'document_number', jsonb_build_object('type', 'string'), 'date', jsonb_build_object('type', 'string', 'format', 'date'),
                'currency', jsonb_build_object('type', 'string'), 'asset_id', jsonb_build_object('type', 'string'),
                'asset_tag', jsonb_build_object('type', 'string'), 'asset_name', jsonb_build_object('type', 'string'),
                'serial_number', jsonb_build_object('type', 'string'),
                'method', jsonb_build_object('enum', jsonb_build_array('sold', 'scrapped', 'donated', 'recycled', 'returned_to_vendor', 'lost', 'stolen', 'other')),
                'cost', jsonb_build_object('type', 'string'), 'proceeds', jsonb_build_object('type', 'string'),
                'purchase_date', jsonb_build_object('type', 'string'), 'recipient', jsonb_build_object('type', 'string'),
                'reason', jsonb_build_object('type', 'string'))),
        now())
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

-- ===================================================================== plan feature
DO $$
BEGIN
    IF to_regclass('core_platform.cp_app_feature_catalog') IS NULL
       OR NOT EXISTS (SELECT 1 FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-helpdesk') THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
    ('helpdesk.asset-lifecycle', 'app-helpdesk', 'Asset Lifecycle', 3,
     'Request equipment from the catalogue, buy it through SCM (needs SCM too), make assets from what is received, and post disposals to Accounting')
    ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title,
        min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;
END $$;

-- ===================================================================== Help Desk tables
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_assets') IS NULL THEN
        RAISE NOTICE 'helpdesk asset lifecycle: no helpdesk schema here; it comes with it';
        RETURN;
    END IF;

    CREATE TABLE IF NOT EXISTS helpdesk.hd_catalog_equipment (
        item_id          text PRIMARY KEY REFERENCES helpdesk.hd_catalog_items (id) ON DELETE CASCADE,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        scm_product_id   text NOT NULL,
        product_name     text,
        asset_type_id    text REFERENCES helpdesk.hd_asset_types (id),
        warranty_months  int CONSTRAINT hd_catalog_equipment_warranty_check CHECK (warranty_months BETWEEN 0 AND 240),
        qty_field        text NOT NULL DEFAULT 'quantity',
        cdatetime        timestamptz NOT NULL DEFAULT now(),
        created_by       text,
        updated_at       timestamptz,
        updated_by       text
    );

    CREATE TABLE IF NOT EXISTS helpdesk.hd_equipment_requests (
        id                      text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id               text NOT NULL,
        bus_id                  text NOT NULL,
        ticket_id               text NOT NULL REFERENCES helpdesk.hd_tickets (id),
        item_id                 text REFERENCES helpdesk.hd_catalog_items (id),
        request_id              text NOT NULL,
        scm_product_id          text NOT NULL,
        product_name            text,
        qty                     int NOT NULL CONSTRAINT hd_equipment_requests_qty_check CHECK (qty BETWEEN 1 AND 50),
        asset_type_id           text REFERENCES helpdesk.hd_asset_types (id),
        warranty_months         int,
        status                  text NOT NULL DEFAULT 'sent'
                                CONSTRAINT hd_equipment_requests_status_check CHECK (status IN ('sent', 'submitted', 'approved', 'ordered',
                                    'partially_received', 'received', 'rejected', 'cancelled', 'refused', 'not_sent')),
        reason                  text,
        scm_requisition_id      text,
        scm_requisition_number  text,
        scm_po_number           text,
        received_qty            int NOT NULL DEFAULT 0,
        event_id                bigint,
        cdatetime               timestamptz NOT NULL DEFAULT now(),
        created_by              text,
        updated_at              timestamptz,
        updated_by              text
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_equipment_requests_ticket_uq ON helpdesk.hd_equipment_requests (tenant_id, ticket_id);
    CREATE UNIQUE INDEX IF NOT EXISTS hd_equipment_requests_request_uq ON helpdesk.hd_equipment_requests (tenant_id, request_id);
    CREATE INDEX IF NOT EXISTS hd_equipment_requests_business_idx ON helpdesk.hd_equipment_requests (tenant_id, bus_id, status);

    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS equipment_request_id text REFERENCES helpdesk.hd_equipment_requests (id);
    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS scm_receipt_line_id text;
    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS scm_unit_key text;
    CREATE UNIQUE INDEX IF NOT EXISTS hd_assets_scm_unit_uq ON helpdesk.hd_assets (equipment_request_id, scm_unit_key)
        WHERE scm_unit_key IS NOT NULL;
    CREATE INDEX IF NOT EXISTS hd_assets_equipment_request_idx ON helpdesk.hd_assets (equipment_request_id) WHERE equipment_request_id IS NOT NULL;

    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS licence_renews_on date;
    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS licence_cost numeric(14,2);
    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS licence_period text;
    ALTER TABLE helpdesk.hd_assets ADD COLUMN IF NOT EXISTS licence_notice_days int;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'helpdesk.hd_assets'::regclass AND conname = 'hd_assets_licence_terms_check') THEN
        ALTER TABLE helpdesk.hd_assets ADD CONSTRAINT hd_assets_licence_terms_check CHECK (
            (licence_period IS NULL OR licence_period IN ('monthly', 'yearly', 'one_time'))
            AND (licence_cost IS NULL OR (licence_cost >= 0 AND currency IS NOT NULL))
            AND (licence_notice_days IS NULL OR licence_notice_days BETWEEN 0 AND 365));
    END IF;
    CREATE INDEX IF NOT EXISTS hd_assets_licence_renewal_idx ON helpdesk.hd_assets (licence_renews_on) WHERE licence_renews_on IS NOT NULL;

    CREATE TABLE IF NOT EXISTS helpdesk.hd_asset_disposals (
        id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
        tenant_id     text NOT NULL,
        bus_id        text NOT NULL,
        number        text NOT NULL,
        asset_id      text NOT NULL REFERENCES helpdesk.hd_assets (id),
        method        text NOT NULL CONSTRAINT hd_asset_disposals_method_check CHECK (method IN ('sold', 'scrapped', 'donated',
                          'recycled', 'returned_to_vendor', 'lost', 'stolen', 'other')),
        disposed_on   date NOT NULL,
        proceeds      numeric(14,2) NOT NULL DEFAULT 0 CONSTRAINT hd_asset_disposals_proceeds_check CHECK (proceeds >= 0),
        currency      text CONSTRAINT hd_asset_disposals_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
        cost          numeric(14,2),
        recipient     text,
        notes         text,
        event_id      bigint,
        cdatetime     timestamptz NOT NULL DEFAULT now(),
        created_by    text,
        CONSTRAINT hd_asset_disposals_money_check CHECK (proceeds = 0 OR currency IS NOT NULL)
    );
    CREATE UNIQUE INDEX IF NOT EXISTS hd_asset_disposals_asset_uq ON helpdesk.hd_asset_disposals (asset_id);
    CREATE UNIQUE INDEX IF NOT EXISTS hd_asset_disposals_number_uq ON helpdesk.hd_asset_disposals (tenant_id, bus_id, number);
    CREATE INDEX IF NOT EXISTS hd_asset_disposals_business_idx ON helpdesk.hd_asset_disposals (tenant_id, bus_id, disposed_on);
END $$;

-- ===================================================================== SCM: where a requisition came from
DO $$
BEGIN
    IF to_regclass('scm.scm_requisitions') IS NULL THEN
        RAISE NOTICE 'helpdesk asset lifecycle: no scm schema here; its columns come with it';
        RETURN;
    END IF;
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS hd_request_id text;
    ALTER TABLE scm.scm_requisitions ADD COLUMN IF NOT EXISTS hd_ticket_number text;
    CREATE INDEX IF NOT EXISTS scm_requisitions_hd_request_idx ON scm.scm_requisitions (bus_id, hd_request_id) WHERE hd_request_id IS NOT NULL;
END $$;

-- ===================================================================== the view (read-only)
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_assets') IS NULL OR to_regclass('scm.scm_items') IS NULL THEN
        RAISE NOTICE 'helpdesk asset lifecycle: Help Desk and SCM are not both here: no view';
        RETURN;
    END IF;
    -- SCM's live items, for choosing what a "request equipment" item buys. Help Desk shows it only while both
    -- subscriptions are live and helpdesk-scm is on.
    EXECUTE $v$
    CREATE OR REPLACE VIEW helpdesk.src_scm_items AS
    SELECT i.tenant_id, i.bus_id, i.id AS product_id, i.name, i.sku, coalesce(i.tracking, 'none') AS tracking, i.unit AS uom
      FROM scm.scm_items i
     WHERE i.archived_at IS NULL
    $v$;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE bad text;
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key IN ('helpdesk-scm', 'helpdesk-accounting')
           AND split_part(kind, '.', 1) <> CASE source_app WHEN 'app-helpdesk' THEN 'helpdesk' WHEN 'app-scm' THEN 'scm' END;
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'helpdesk asset lifecycle: catalogue rows whose prefix does not name the sender: %', bad;
        END IF;
    END IF;
    IF to_regclass('core_platform.cp_app_connections') IS NOT NULL AND EXISTS (
        SELECT 1 FROM core_platform.cp_app_connections WHERE link_key IN ('helpdesk-scm', 'helpdesk-accounting') AND changed_by = 'system') THEN
        RAISE EXCEPTION 'helpdesk asset lifecycle: a system row switched a link on; they start OFF';
    END IF;
    IF to_regclass('helpdesk.hd_asset_disposals') IS NOT NULL AND EXISTS (
        SELECT 1 FROM helpdesk.hd_asset_disposals d JOIN helpdesk.hd_assets a ON a.id = d.asset_id
         WHERE a.tenant_id <> d.tenant_id OR a.bus_id <> d.bus_id) THEN
        RAISE EXCEPTION 'helpdesk asset lifecycle: a disposal belongs to another business''s asset';
    END IF;
END $$;

COMMIT;
