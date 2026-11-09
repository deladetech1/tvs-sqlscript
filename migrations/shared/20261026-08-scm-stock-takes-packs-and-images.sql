-- SCM phase C (stock): stock takes, pack sizes, item images, optimistic locking on the stock
-- documents, and the control tower's thresholds in settings.
--
--   scm_stock_counts       a stock take of one warehouse (or one bin of it): draft, counting
--                          (the expected quantities are snapshotted when it starts), submitted,
--                          posted (every non-zero variance becomes an "adjustment" movement with
--                          reason "count", reference_type "stock_count") or cancelled. Numbered
--                          CNT-00001 from scm_number_series (kind stock_count).
--   scm_stock_count_lines  one row per item, bin and lot counted: expected_qty (the snapshot),
--                          counted_qty (NULL until counted), variance (generated: counted less
--                          expected), who counted it and when; added marks a line found during the
--                          count that the snapshot did not hold.
--   scm_item_packs         the packs an item is bought or sold in ("Carton of 12"): qty_per_pack
--                          base units, an optional barcode (unique per business among live packs;
--                          the API also refuses a pack barcode that is an item's), defaults for
--                          purchasing and sales, archived rather than deleted.
--   pack_id, pack_qty      on requisition, purchase-order and sales-order lines: the line was
--                          entered as pack_qty packs; qty stays in base units (pack_qty x
--                          qty_per_pack) and prices stay per base unit.
--   image_*                on scm_item_settings: the item's one picture, kept in SCM's private
--                          storage (container scm-files); the row holds where, not the bytes.
--   version                on shipments, receipts, adjustments and transfers: a change made
--                          against a stale copy is refused (409) by the API.
--   scm_settings           the control tower's thresholds, each 1..365 days, defaulting to the
--                          values the scan used before they were settings.
--
-- Stock takes number from scm_number_series, kind stock_count (prefix CNT-). This file does not
-- touch that table's kind CHECK: 20261026-09 owns it and lists stock_count (20261026-02 no longer
-- sets it, the same change -09's branch makes). Also: permissions
-- scm|stock_counts|get|manage|post mapped like their neighbour inventory (whoever reads
-- inventory reads counts; whoever adjusts stock runs and posts them), and the plan features
-- scm.item_images (BASIC), scm.pack_sizes and scm.stock_counts (ADVANCE).
--
-- Status and kind lists are CHECK constraints owned by this file. Idempotent; safe to re-run.

BEGIN;

-- =============================================================== stock takes
CREATE TABLE IF NOT EXISTS scm.scm_stock_counts (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    bin_id            text REFERENCES scm.scm_bins (id),
    status            text NOT NULL DEFAULT 'draft',
    -- Blind: counters do not see what the system expects until the count is submitted.
    blind             boolean NOT NULL DEFAULT false,
    scope             text NOT NULL DEFAULT 'all',
    category          text,
    item_ids          text[] NOT NULL DEFAULT '{}',
    notes             text,
    version           integer NOT NULL DEFAULT 1,
    started_at        timestamptz,
    started_by        text,
    submitted_at      timestamptz,
    submitted_by      text,
    posted_at         timestamptz,
    posted_by         text,
    cancelled_at      timestamptz,
    cancelled_by      text,
    cancelled_reason  text,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_stock_counts DROP CONSTRAINT IF EXISTS scm_stock_counts_status_check;
ALTER TABLE scm.scm_stock_counts ADD CONSTRAINT scm_stock_counts_status_check
    CHECK (status IN ('draft', 'counting', 'submitted', 'posted', 'cancelled'));
ALTER TABLE scm.scm_stock_counts DROP CONSTRAINT IF EXISTS scm_stock_counts_scope_check;
ALTER TABLE scm.scm_stock_counts ADD CONSTRAINT scm_stock_counts_scope_check CHECK (
    (scope = 'all' AND category IS NULL AND cardinality(item_ids) = 0)
    OR (scope = 'category' AND coalesce(category, '') <> '' AND cardinality(item_ids) = 0)
    OR (scope = 'items' AND category IS NULL AND cardinality(item_ids) > 0));
ALTER TABLE scm.scm_stock_counts DROP CONSTRAINT IF EXISTS scm_stock_counts_version_check;
ALTER TABLE scm.scm_stock_counts ADD CONSTRAINT scm_stock_counts_version_check CHECK (version > 0);
CREATE UNIQUE INDEX IF NOT EXISTS scm_stock_counts_number_uq ON scm.scm_stock_counts (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_stock_counts_idem_uq ON scm.scm_stock_counts (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_stock_counts_board_idx ON scm.scm_stock_counts (bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_stock_counts_warehouse_idx ON scm.scm_stock_counts (bus_id, warehouse_id);

CREATE TABLE IF NOT EXISTS scm.scm_stock_count_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    count_id      text NOT NULL REFERENCES scm.scm_stock_counts (id) ON DELETE CASCADE,
    product_id    text NOT NULL,
    bin_id        text REFERENCES scm.scm_bins (id),
    lot_id        text REFERENCES scm.scm_lots (id),
    -- What the ledger held at expected_at: when the count started, when the line was added, or
    -- (a line whose stock moved, accepted at posting) when it was posted. Stock moved after
    -- expected_at makes the line "moved": posting it needs a recount or an explicit accept.
    expected_qty  numeric(14,3) NOT NULL DEFAULT 0,
    expected_at   timestamptz NOT NULL DEFAULT now(),
    counted_qty   numeric(14,3),
    variance      numeric(14,3) GENERATED ALWAYS AS (counted_qty - expected_qty) STORED,
    added         boolean NOT NULL DEFAULT false,
    note          text,
    counted_by    text,
    counted_at    timestamptz
);
ALTER TABLE scm.scm_stock_count_lines DROP CONSTRAINT IF EXISTS scm_stock_count_lines_counted_check;
ALTER TABLE scm.scm_stock_count_lines ADD CONSTRAINT scm_stock_count_lines_counted_check CHECK (counted_qty IS NULL OR counted_qty >= 0);
CREATE UNIQUE INDEX IF NOT EXISTS scm_stock_count_lines_uq
    ON scm.scm_stock_count_lines (count_id, product_id, coalesce(bin_id, ''), coalesce(lot_id, ''));
CREATE INDEX IF NOT EXISTS scm_stock_count_lines_count_idx ON scm.scm_stock_count_lines (count_id);

-- ================================================================ pack sizes
CREATE TABLE IF NOT EXISTS scm.scm_item_packs (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    product_id         text NOT NULL REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
    name               text NOT NULL,
    qty_per_pack       numeric(14,3) NOT NULL,
    barcode            text,
    default_purchase   boolean NOT NULL DEFAULT false,
    default_sales      boolean NOT NULL DEFAULT false,
    archived_at        timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text
);
ALTER TABLE scm.scm_item_packs DROP CONSTRAINT IF EXISTS scm_item_packs_qty_check;
ALTER TABLE scm.scm_item_packs ADD CONSTRAINT scm_item_packs_qty_check CHECK (qty_per_pack > 0);
ALTER TABLE scm.scm_item_packs DROP CONSTRAINT IF EXISTS scm_item_packs_name_check;
ALTER TABLE scm.scm_item_packs ADD CONSTRAINT scm_item_packs_name_check CHECK (btrim(name) <> '');
CREATE UNIQUE INDEX IF NOT EXISTS scm_item_packs_name_uq ON scm.scm_item_packs (bus_id, product_id, lower(name)) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS scm_item_packs_barcode_uq ON scm.scm_item_packs (bus_id, barcode)
    WHERE archived_at IS NULL AND coalesce(barcode, '') <> '';
-- At most one live default per direction for an item.
CREATE UNIQUE INDEX IF NOT EXISTS scm_item_packs_default_purchase_uq ON scm.scm_item_packs (bus_id, product_id)
    WHERE archived_at IS NULL AND default_purchase;
CREATE UNIQUE INDEX IF NOT EXISTS scm_item_packs_default_sales_uq ON scm.scm_item_packs (bus_id, product_id)
    WHERE archived_at IS NULL AND default_sales;
CREATE INDEX IF NOT EXISTS scm_item_packs_product_idx ON scm.scm_item_packs (bus_id, product_id);

-- Document lines entered in packs. Both or neither.
ALTER TABLE scm.scm_requisition_lines    ADD COLUMN IF NOT EXISTS pack_id  text REFERENCES scm.scm_item_packs (id);
ALTER TABLE scm.scm_requisition_lines    ADD COLUMN IF NOT EXISTS pack_qty numeric(14,3);
ALTER TABLE scm.scm_purchase_order_lines ADD COLUMN IF NOT EXISTS pack_id  text REFERENCES scm.scm_item_packs (id);
ALTER TABLE scm.scm_purchase_order_lines ADD COLUMN IF NOT EXISTS pack_qty numeric(14,3);
ALTER TABLE scm.scm_sales_order_lines    ADD COLUMN IF NOT EXISTS pack_id  text REFERENCES scm.scm_item_packs (id);
ALTER TABLE scm.scm_sales_order_lines    ADD COLUMN IF NOT EXISTS pack_qty numeric(14,3);
ALTER TABLE scm.scm_requisition_lines DROP CONSTRAINT IF EXISTS scm_requisition_lines_pack_check;
ALTER TABLE scm.scm_requisition_lines ADD CONSTRAINT scm_requisition_lines_pack_check
    CHECK ((pack_id IS NULL AND pack_qty IS NULL) OR (pack_id IS NOT NULL AND pack_qty > 0));
ALTER TABLE scm.scm_purchase_order_lines DROP CONSTRAINT IF EXISTS scm_purchase_order_lines_pack_check;
ALTER TABLE scm.scm_purchase_order_lines ADD CONSTRAINT scm_purchase_order_lines_pack_check
    CHECK ((pack_id IS NULL AND pack_qty IS NULL) OR (pack_id IS NOT NULL AND pack_qty > 0));
ALTER TABLE scm.scm_sales_order_lines DROP CONSTRAINT IF EXISTS scm_sales_order_lines_pack_check;
ALTER TABLE scm.scm_sales_order_lines ADD CONSTRAINT scm_sales_order_lines_pack_check
    CHECK ((pack_id IS NULL AND pack_qty IS NULL) OR (pack_id IS NOT NULL AND pack_qty > 0));

-- =============================================================== item images
ALTER TABLE scm.scm_item_settings ADD COLUMN IF NOT EXISTS image_path         text;
ALTER TABLE scm.scm_item_settings ADD COLUMN IF NOT EXISTS image_content_type text;
ALTER TABLE scm.scm_item_settings ADD COLUMN IF NOT EXISTS image_size_bytes   bigint;
ALTER TABLE scm.scm_item_settings ADD COLUMN IF NOT EXISTS image_updated_at   timestamptz;
ALTER TABLE scm.scm_item_settings DROP CONSTRAINT IF EXISTS scm_item_settings_image_check;
ALTER TABLE scm.scm_item_settings ADD CONSTRAINT scm_item_settings_image_check CHECK (
    (image_path IS NULL AND image_content_type IS NULL)
    OR (image_path IS NOT NULL AND image_content_type IN ('image/jpeg', 'image/png', 'image/webp')
        AND image_size_bytes BETWEEN 1 AND 5242880));

-- ======================================================== optimistic locking
ALTER TABLE scm.scm_shipments   ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE scm.scm_receipts    ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE scm.scm_adjustments ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE scm.scm_transfers   ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;

-- ============================================== the control tower's thresholds
ALTER TABLE scm.scm_settings ADD COLUMN IF NOT EXISTS po_confirm_grace_days     integer NOT NULL DEFAULT 2;
ALTER TABLE scm.scm_settings ADD COLUMN IF NOT EXISTS po_confirm_soon_days      integer NOT NULL DEFAULT 3;
ALTER TABLE scm.scm_settings ADD COLUMN IF NOT EXISTS so_allocate_horizon_days  integer NOT NULL DEFAULT 3;
ALTER TABLE scm.scm_settings ADD COLUMN IF NOT EXISTS lot_expiry_horizon_days   integer NOT NULL DEFAULT 30;
ALTER TABLE scm.scm_settings ADD COLUMN IF NOT EXISTS receipt_variance_days     integer NOT NULL DEFAULT 30;
ALTER TABLE scm.scm_settings DROP CONSTRAINT IF EXISTS scm_settings_thresholds_check;
ALTER TABLE scm.scm_settings ADD CONSTRAINT scm_settings_thresholds_check CHECK (
    po_confirm_grace_days BETWEEN 1 AND 365 AND po_confirm_soon_days BETWEEN 1 AND 365
    AND so_allocate_horizon_days BETWEEN 1 AND 365 AND lot_expiry_horizon_days BETWEEN 1 AND 365
    AND receipt_variance_days BETWEEN 1 AND 365);

-- ================================================ where SCM holds a product
INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_item_packs',        'product_id', false),
    ('scm.scm_stock_count_lines', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ================================================================ permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-scm-stock_counts', 'SCM Stock Takes', 'Stock takes: counting a warehouse and posting the differences', 'rt-subscribed-app-scm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('stock_counts', 'rt-scm-stock_counts', 'get',    'View stock takes and their counts'),
    ('stock_counts', 'rt-scm-stock_counts', 'manage', 'Start stock takes, enter counts, submit and cancel them'),
    ('stock_counts', 'rt-scm-stock_counts', 'post',   'Post a stock take: write its differences to the stock ledger')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-scm-' || spec.resource_key || '-' || spec.action,
       'SCM ' || initcap(replace(spec.resource_key, '_', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'scm',
       resource_key = substring(p.id FROM '^permission-scm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-scm-stock_counts-%'
   AND (p.app_prefix IS DISTINCT FROM 'scm' OR p.resource_key IS NULL OR p.action IS NULL);

-- Like their neighbour, inventory: whoever reads inventory reads stock takes; whoever adjusts
-- stock counts it and posts the differences. The manager holds every SCM permission (20261026-01
-- grants it the ones that exist when it runs; these are new, so granted here too).
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', g.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    SELECT rp.role_id, 'get' AS action
      FROM core_platform.cp_role_permissions rp
     WHERE rp.permission_id = 'permission-scm-inventory-get' AND rp.role_id LIKE 'role-scm-%'
    UNION
    SELECT rp.role_id, a.action
      FROM core_platform.cp_role_permissions rp
      CROSS JOIN (VALUES ('get'), ('manage'), ('post')) AS a(action)
     WHERE rp.permission_id = 'permission-scm-inventory-adjust' AND rp.role_id LIKE 'role-scm-%'
    UNION
    SELECT 'role-scm-manager', a.action FROM (VALUES ('get'), ('manage'), ('post')) AS a(action)
  ) AS g
  JOIN core_platform.cp_roles r ON r.id = g.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'scm' AND p.resource_key = 'stock_counts' AND p.action = g.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== features
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('scm.item_images',  'app-scm', 'Item Images',  1, 'A picture on each item, shown in lists, pickers and documents'),
('scm.pack_sizes',   'app-scm', 'Pack Sizes',   2, 'Buy and sell items in packs (a carton of 12) with their own barcodes'),
('scm.stock_counts', 'app-scm', 'Stock Takes',  2, 'Count a warehouse, blind or not, and post the differences to the ledger')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
-- Properties, never counts.
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-scm-stock_counts-%'
       AND (app_prefix IS DISTINCT FROM 'scm' OR resource_key IS DISTINCT FROM 'stock_counts' OR action IS NULL
            OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% SCM stock-take permission(s) have no pair; nothing would match them', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'scm' AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-scm-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-scm-manager lacks % SCM permission(s)', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-scm-viewer' AND p.app_prefix = 'scm' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-scm-viewer holds % SCM permission(s) that change data', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-scm-admin' AND permission_id LIKE 'permission-scm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-scm-admin holds SCM permission rows';
    END IF;
    -- Posting a count moves stock: only roles that may adjust stock may post one.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                WHERE rp.permission_id = 'permission-scm-stock_counts-post'
                  AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions a
                                   WHERE a.role_id = rp.role_id AND a.tenant_id = rp.tenant_id
                                     AND a.permission_id = 'permission-scm-inventory-adjust')) THEN
        RAISE EXCEPTION 'a role may post stock takes without being allowed to adjust stock';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'scm' AND table_name = 'scm_stock_count_lines'
                      AND column_name = 'variance' AND is_generated = 'ALWAYS') THEN
        RAISE EXCEPTION 'scm_stock_count_lines.variance is not generated from the counts';
    END IF;
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'scm' AND column_name = 'version'
       AND table_name IN ('scm_shipments', 'scm_receipts', 'scm_adjustments', 'scm_transfers', 'scm_stock_counts');
    IF n <> 5 THEN
        RAISE EXCEPTION 'scm: % of 5 stock documents carry a version', n;
    END IF;
    RAISE NOTICE 'scm: % permission(s), % feature(s)',
        (SELECT count(*) FROM core_platform.cp_permissions WHERE app_prefix = 'scm'),
        (SELECT count(*) FROM core_platform.cp_app_feature_catalog WHERE app_id = 'app-scm');
END $$;

COMMIT;
