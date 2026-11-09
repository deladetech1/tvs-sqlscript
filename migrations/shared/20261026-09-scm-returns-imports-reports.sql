-- SCM: returns, imports and reports (Phase C flows).
--
--   scm_returns          a return of goods: from a customer against a shipment (kind customer,
--                        numbered RMA-) or to a supplier against a goods receipt (kind supplier,
--                        numbered SRN-). draft -> approved -> completed, or cancelled. Completing
--                        writes the ledger: a customer return puts stock back ("return" movements,
--                        into the lot it left; quarantined goods into a quarantine bin when the
--                        warehouse has one), a supplier return takes it out. version guards every
--                        change against a stale copy.
--   scm_return_lines     what comes back, line by line, each naming the shipment line or receipt
--                        line it returns (so a line is never returned twice over), with the
--                        disposition of a customer return: restock, quarantine or scrap.
--   scm_number_series    the kind list now also holds customer_return (RMA-), supplier_return
--                        (SRN-) and stock_count (CNT-, Phase C stock takes, 20261026-08). This file
--                        owns that CHECK from now on; 20261026-02 no longer sets it.
--   indexes              for the dashboard trends and the reports: the ledger by day, receipts
--                        by the day they were received, shipments by the day they shipped.
--   permissions          scm|returns|get/create/update/approve/post/cancel, scm|imports|create,
--                        scm|reports|get, granted like their nearest neighbours: returns like
--                        shipments and receipts (approving like the other approvals), imports like
--                        managing items, reports like reading inventory.
--   features             scm.imports (BASIC), scm.returns and scm.reports (ADVANCE).
--
-- Status and kind lists are CHECK constraints owned by this file. Party and product columns are
-- registered for the shared merge. Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== numbering
ALTER TABLE scm.scm_number_series DROP CONSTRAINT IF EXISTS scm_number_series_kind_check;
ALTER TABLE scm.scm_number_series ADD CONSTRAINT scm_number_series_kind_check CHECK (kind IN
    ('requisition', 'purchase_order', 'receipt', 'adjustment', 'transfer', 'sales_order', 'shipment',
     'stock_count', 'customer_return', 'supplier_return'));
COMMENT ON TABLE scm.scm_number_series IS
    'Document numbering per business and kind. Defaults: requisition REQ-, purchase_order PO-, receipt GRN-, adjustment ADJ-, transfer TRF-, sales_order SO-, shipment SHP-, stock_count CNT-, customer_return RMA-, supplier_return SRN-; padding 5. Taken with SELECT ... FOR UPDATE.';

-- ======================================================================= returns
CREATE TABLE IF NOT EXISTS scm.scm_returns (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    number            text NOT NULL,
    kind              text NOT NULL,
    customer_id       text,
    supplier_id       text,
    shipment_id       text REFERENCES scm.scm_shipments (id),
    receipt_id        text REFERENCES scm.scm_receipts (id),
    warehouse_id      text NOT NULL REFERENCES scm.scm_warehouses (id),
    status            text NOT NULL DEFAULT 'draft',
    reason            text,
    notes             text,
    cancelled_reason  text,
    approved_by       text,
    approved_at       timestamptz,
    completed_by      text,
    completed_at      timestamptz,
    cancelled_by      text,
    cancelled_at      timestamptz,
    version           integer NOT NULL DEFAULT 1,
    idempotency_key   text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text
);
ALTER TABLE scm.scm_returns DROP CONSTRAINT IF EXISTS scm_returns_kind_check;
ALTER TABLE scm.scm_returns ADD CONSTRAINT scm_returns_kind_check CHECK (kind IN ('customer', 'supplier'));
ALTER TABLE scm.scm_returns DROP CONSTRAINT IF EXISTS scm_returns_status_check;
ALTER TABLE scm.scm_returns ADD CONSTRAINT scm_returns_status_check CHECK (status IN ('draft', 'approved', 'completed', 'cancelled'));
-- A customer return names its customer and shipment and nothing of a supplier; a supplier
-- return the other way round.
ALTER TABLE scm.scm_returns DROP CONSTRAINT IF EXISTS scm_returns_source_check;
ALTER TABLE scm.scm_returns ADD CONSTRAINT scm_returns_source_check CHECK (
    (kind = 'customer' AND customer_id IS NOT NULL AND shipment_id IS NOT NULL AND supplier_id IS NULL AND receipt_id IS NULL)
 OR (kind = 'supplier' AND supplier_id IS NOT NULL AND receipt_id IS NOT NULL AND customer_id IS NULL AND shipment_id IS NULL));
ALTER TABLE scm.scm_returns DROP CONSTRAINT IF EXISTS scm_returns_version_check;
ALTER TABLE scm.scm_returns ADD CONSTRAINT scm_returns_version_check CHECK (version > 0);
CREATE UNIQUE INDEX IF NOT EXISTS scm_returns_number_uq ON scm.scm_returns (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS scm_returns_idem_uq ON scm.scm_returns (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_returns_board_idx ON scm.scm_returns (bus_id, kind, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS scm_returns_shipment_idx ON scm.scm_returns (shipment_id) WHERE shipment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_returns_receipt_idx ON scm.scm_returns (receipt_id) WHERE receipt_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS scm.scm_return_lines (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    return_id           text NOT NULL REFERENCES scm.scm_returns (id) ON DELETE CASCADE,
    line_no             integer NOT NULL,
    -- The line returned: a shipment line (customer) or a receipt line (supplier).
    shipment_line_id    text REFERENCES scm.scm_shipment_lines (id),
    receipt_line_id     text REFERENCES scm.scm_receipt_lines (id),
    product_id          text NOT NULL,
    lot_id              text REFERENCES scm.scm_lots (id),
    bin_id              text REFERENCES scm.scm_bins (id),
    qty                 numeric(14,3) NOT NULL CHECK (qty > 0),
    disposition         text,
    unit_cost           numeric(14,4) CHECK (unit_cost IS NULL OR unit_cost >= 0),
    note                text,
    -- Set when the return is completed: the bin the goods went into (or came out of).
    posted_bin_id       text REFERENCES scm.scm_bins (id),
    posted_note         text
);
ALTER TABLE scm.scm_return_lines DROP CONSTRAINT IF EXISTS scm_return_lines_disposition_check;
ALTER TABLE scm.scm_return_lines ADD CONSTRAINT scm_return_lines_disposition_check
    CHECK (disposition IS NULL OR disposition IN ('restock', 'quarantine', 'scrap'));
ALTER TABLE scm.scm_return_lines DROP CONSTRAINT IF EXISTS scm_return_lines_source_check;
ALTER TABLE scm.scm_return_lines ADD CONSTRAINT scm_return_lines_source_check
    CHECK ((shipment_line_id IS NULL) <> (receipt_line_id IS NULL));
CREATE UNIQUE INDEX IF NOT EXISTS scm_return_lines_uq ON scm.scm_return_lines (return_id, line_no);
CREATE INDEX IF NOT EXISTS scm_return_lines_shipment_line_idx ON scm.scm_return_lines (shipment_line_id) WHERE shipment_line_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS scm_return_lines_receipt_line_idx ON scm.scm_return_lines (receipt_line_id) WHERE receipt_line_id IS NOT NULL;

INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_returns', 'customer_id', false),
    ('scm.scm_returns', 'supplier_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
    ('scm.scm_return_lines', 'product_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ============================================================ trends and reports
CREATE INDEX IF NOT EXISTS scm_inventory_movements_day_idx ON scm.scm_inventory_movements (bus_id, cdatetime);
CREATE INDEX IF NOT EXISTS scm_receipts_received_idx ON scm.scm_receipts (bus_id, received_at) WHERE status = 'posted';
CREATE INDEX IF NOT EXISTS scm_shipments_shipped_idx ON scm.scm_shipments (bus_id, shipped_at) WHERE shipped_at IS NOT NULL;

-- ================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-scm-returns', 'SCM Returns', 'Returns from customers and to suppliers',                    'rt-subscribed-app-scm'),
('rt-scm-imports', 'SCM Imports', 'CSV imports of items, suppliers, customers and opening stock', 'rt-subscribed-app-scm'),
('rt-scm-reports', 'SCM Reports', 'Stock, supplier and sales reports',                          'rt-subscribed-app-scm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('returns', 'rt-scm-returns', 'get',     'View returns from customers and to suppliers'),
    ('returns', 'rt-scm-returns', 'create',  'Raise returns against shipments and goods receipts'),
    ('returns', 'rt-scm-returns', 'update',  'Change draft returns'),
    ('returns', 'rt-scm-returns', 'approve', 'Approve returns'),
    ('returns', 'rt-scm-returns', 'post',    'Complete returns: put stock back, quarantine or scrap it, or send it to the supplier'),
    ('returns', 'rt-scm-returns', 'cancel',  'Cancel returns'),
    ('imports', 'rt-scm-imports', 'create',  'Import items, suppliers, customers and opening stock from CSV files'),
    ('reports', 'rt-scm-reports', 'get',     'View stock, supplier and sales reports')
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
 WHERE p.id IN ('permission-scm-returns-get', 'permission-scm-returns-create', 'permission-scm-returns-update',
                'permission-scm-returns-approve', 'permission-scm-returns-post', 'permission-scm-returns-cancel',
                'permission-scm-imports-create', 'permission-scm-reports-get')
   AND (p.app_prefix IS DISTINCT FROM 'scm' OR p.resource_key IS NULL OR p.action IS NULL);

-- 20261026-01 gives the manager every SCM permission and the planner and viewer every read, but
-- it runs before this file: the first deploy needs these grants here.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
    ('role-scm-manager',   'returns', 'get'), ('role-scm-manager', 'returns', 'create'), ('role-scm-manager', 'returns', 'update'),
    ('role-scm-manager',   'returns', 'approve'), ('role-scm-manager', 'returns', 'post'), ('role-scm-manager', 'returns', 'cancel'),
    ('role-scm-manager',   'imports', 'create'), ('role-scm-manager', 'reports', 'get'),
    -- Returns like shipments and receipts: the warehouse raises, changes, completes and cancels them.
    ('role-scm-warehouse', 'returns', 'get'), ('role-scm-warehouse', 'returns', 'create'), ('role-scm-warehouse', 'returns', 'update'),
    ('role-scm-warehouse', 'returns', 'post'), ('role-scm-warehouse', 'returns', 'cancel'), ('role-scm-warehouse', 'reports', 'get'),
    -- Approving is the approver's, as for requisitions and purchase orders.
    ('role-scm-approver',  'returns', 'get'), ('role-scm-approver', 'returns', 'approve'), ('role-scm-approver', 'reports', 'get'),
    -- Whoever reads shipments or receipts reads their returns; whoever reads inventory reads the reports.
    ('role-scm-buyer',     'returns', 'get'), ('role-scm-buyer', 'reports', 'get'),
    ('role-scm-orderdesk', 'returns', 'get'), ('role-scm-orderdesk', 'reports', 'get'),
    ('role-scm-planner',   'returns', 'get'), ('role-scm-planner', 'reports', 'get'),
    ('role-scm-viewer',    'returns', 'get'), ('role-scm-viewer', 'reports', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'scm' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('scm.imports', 'app-scm', 'Imports', 1, 'CSV imports of items, suppliers, customers and opening stock, checked before anything is saved'),
('scm.returns', 'app-scm', 'Returns', 2, 'Customer returns against shipments and returns to suppliers against goods receipts'),
('scm.reports', 'app-scm', 'Reports', 2, 'Stock valuation and ageing, slow movers, ABC, supplier performance, sales by item and reorder suggestions')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id IN ('permission-scm-returns-get', 'permission-scm-returns-create', 'permission-scm-returns-update',
                  'permission-scm-returns-approve', 'permission-scm-returns-post', 'permission-scm-returns-cancel',
                  'permission-scm-imports-create', 'permission-scm-reports-get')
       AND (app_prefix IS DISTINCT FROM 'scm' OR resource_key IS NULL OR action IS NULL
            OR coalesce(target, '') <> '' OR scope IS DISTINCT FROM 'any');
    IF n > 0 THEN
        RAISE EXCEPTION '% SCM returns/imports/reports permission(s) have no pair', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'scm' AND p.resource_key IN ('returns', 'imports', 'reports')
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-scm-manager' AND rp.permission_id = p.id);
    IF n > 0 THEN
        RAISE EXCEPTION 'role-scm-manager lacks % SCM returns/imports/reports permission(s)', n;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                JOIN core_platform.cp_actions a ON a.action = p.action
                WHERE rp.role_id = 'role-scm-viewer' AND p.app_prefix = 'scm' AND NOT a.is_read_only) THEN
        RAISE EXCEPTION 'role-scm-viewer holds an SCM permission that changes data';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id NOT IN ('role-scm-manager', 'role-scm-approver')
                  AND p.app_prefix = 'scm' AND p.action = 'approve') THEN
        RAISE EXCEPTION 'a role other than SCM Supply Chain Manager or Procurement Approver may approve';
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-scm-admin' AND permission_id LIKE 'permission-scm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-scm-admin holds SCM permission rows';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'scm_number_series_kind_check'
                    AND conrelid = 'scm.scm_number_series'::regclass
                    AND pg_get_constraintdef(oid) LIKE '%customer_return%' AND pg_get_constraintdef(oid) LIKE '%stock_count%') THEN
        RAISE EXCEPTION 'scm_number_series_kind_check does not hold the return and stock-count series';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references WHERE table_name = 'scm.scm_returns' AND column_name = 'customer_id')
       OR NOT EXISTS (SELECT 1 FROM core_platform.cp_product_references WHERE table_name = 'scm.scm_return_lines' AND column_name = 'product_id') THEN
        RAISE EXCEPTION 'the returns'' party and product columns are not registered for the shared merge';
    END IF;
    RAISE NOTICE 'scm returns/imports/reports: % permission(s), % feature(s)',
        (SELECT count(*) FROM core_platform.cp_permissions WHERE app_prefix = 'scm' AND resource_key IN ('returns', 'imports', 'reports')),
        (SELECT count(*) FROM core_platform.cp_app_feature_catalog WHERE feature_key IN ('scm.imports', 'scm.returns', 'scm.reports'));
END $$;

COMMIT;
