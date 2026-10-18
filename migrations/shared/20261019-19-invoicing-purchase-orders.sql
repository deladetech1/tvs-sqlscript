-- Invoicing: purchase orders, and suppliers.
--
-- A purchase order is a fourth kind of document (with invoices, quotes and credit notes): the
-- same lines, numbers, designs, languages, PDF, sending and link -- sent to a supplier, who
-- can confirm or decline it from the link. It is never money in: reports, statements, the
-- customer's page and what is owed leave it out.
--
-- Suppliers are contacts in inv_customers with a role: customer, supplier, or both (one a
-- business both buys from and sells to is one contact).
--
-- MyStoreGuard: its suppliers import as suppliers, and its purchase orders can be brought in
-- -- linked, not copied away: source_app/source_id name the order there, and what has been
-- received and paid is read from MyStoreGuard as it happens. Through views, made only where
-- MyStoreGuard's tables exist:
--   * invoicing.src_mystoreguard_suppliers
--   * invoicing.src_mystoreguard_purchase_orders (with its supplier, location, received and paid)
--   * invoicing.src_mystoreguard_purchase_order_lines
--
-- Idempotent; safe to re-run on every deploy. Constraints are replaced under the same names,
-- so the earlier migrations' checks find them and leave them.

BEGIN;

-- Contacts: customer, supplier or both.
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'customer';
    END IF;
END $guard$;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_customers_role_ck') THEN
        ALTER TABLE invoicing.inv_customers ADD CONSTRAINT inv_customers_role_ck CHECK (role IN ('customer', 'supplier', 'both'));
    END IF;
END $$;
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        CREATE INDEX IF NOT EXISTS inv_customers_role_idx ON invoicing.inv_customers (bus_id, role);
    END IF;
END $guard$;

-- The purchase order kind, and its statuses: open (sent), accepted (confirmed by the supplier),
-- declined, received (all of it in), void.
DO $$
DECLARE c text;
BEGIN
    SELECT conname INTO c FROM pg_constraint WHERE conrelid = 'invoicing.inv_invoices'::regclass AND conname = 'inv_invoices_kind_ck'
       AND pg_get_constraintdef(oid) NOT LIKE '%purchase_order%';
    IF c IS NOT NULL THEN
        ALTER TABLE invoicing.inv_invoices DROP CONSTRAINT inv_invoices_kind_ck;
        ALTER TABLE invoicing.inv_invoices ADD CONSTRAINT inv_invoices_kind_ck CHECK (kind IN ('invoice', 'quote', 'credit_note', 'purchase_order'));
    END IF;
    SELECT conname INTO c FROM pg_constraint WHERE conrelid = 'invoicing.inv_invoices'::regclass AND conname = 'inv_invoices_status_ck'
       AND pg_get_constraintdef(oid) NOT LIKE '%received%';
    IF c IS NOT NULL THEN
        ALTER TABLE invoicing.inv_invoices DROP CONSTRAINT inv_invoices_status_ck;
        ALTER TABLE invoicing.inv_invoices ADD CONSTRAINT inv_invoices_status_ck
            CHECK (status IN ('draft', 'open', 'paid', 'void', 'accepted', 'declined', 'converted', 'applied', 'received'));
    END IF;
    -- Purchase orders number in their own series.
    SELECT conname INTO c FROM pg_constraint WHERE conrelid = 'invoicing.inv_number_series'::regclass AND conname = 'inv_number_series_kind_check'
       AND pg_get_constraintdef(oid) NOT LIKE '%purchase_order%';
    IF c IS NOT NULL THEN
        ALTER TABLE invoicing.inv_number_series DROP CONSTRAINT inv_number_series_kind_check;
        ALTER TABLE invoicing.inv_number_series ADD CONSTRAINT inv_number_series_kind_check
            CHECK (kind IN ('invoice', 'quote', 'credit_note', 'receipt', 'purchase_order'));
    END IF;
END $$;

-- Where the goods go (a purchase order's own address), when it was received, and the order in
-- another app it stands for.
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS deliver_to  text NOT NULL DEFAULT '';
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS received_at timestamptz;
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS source_app  text;
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS source_id   text;
CREATE UNIQUE INDEX IF NOT EXISTS inv_invoices_source_uq ON invoicing.inv_invoices (bus_id, source_app, source_id)
    WHERE source_id IS NOT NULL AND status <> 'void';

-- What came in, per line (by hand here, or from MyStoreGuard's receipts for a linked order).
ALTER TABLE invoicing.inv_invoice_lines ADD COLUMN IF NOT EXISTS qty_received numeric(18,4) NOT NULL DEFAULT 0;
ALTER TABLE invoicing.inv_invoice_lines ADD COLUMN IF NOT EXISTS source_line_id text;

DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_suppliers') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_suppliers AS
        SELECT s.tenant_id, s.org_id, s.bus_id,
               s.id                                AS source_id,
               btrim(s.fullname)                   AS name,
               NULLIF(btrim(s.contact), '')        AS phone,
               NULLIF(lower(btrim(s.email)), '')   AS email,
               NULLIF(btrim(s.address), '')        AS address_line,
               (s.delete_status <> 'NOT_DELETED' OR s.is_active IS FALSE) AS is_removed,
               md5(row(s.fullname, s.contact, s.email, s.address, s.delete_status, s.is_active)::text) AS row_hash
          FROM mystoreguard.msg_suppliers s
        $v$;
    END IF;

    IF to_regclass('mystoreguard.msg_purchase_orders') IS NOT NULL AND to_regclass('mystoreguard.msg_purchase_order_items') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_purchase_order_lines AS
        SELECT i.tenant_id, i.bus_id,
               i.purchase_order_id                         AS order_id,
               i.id                                        AS source_line_id,
               coalesce(NULLIF(btrim(p.name), ''), 'Item') AS name,
               coalesce(p.sku, '')                         AS code,
               concat_ws(' · ', NULLIF(btrim(i.product_size), ''), NULLIF(btrim(i.description), '')) AS description,
               coalesce(i.qty_ordered, 0)                  AS qty_ordered,
               coalesce(i.qty_received, 0)                 AS qty_received,
               coalesce(i.cost_price, 0)                   AS unit_cost,
               coalesce(i.discount_amount, 0)              AS discount_amount,
               coalesce(i.tax_rate, 0)                     AS tax_rate,
               cur.code                                    AS currency
          FROM mystoreguard.msg_purchase_order_items i
          LEFT JOIN mystoreguard.msg_products p ON p.id = i.product_id
          LEFT JOIN core_platform.cp_currencies cur ON cur.id = i.currency_id AND cur.tenant_id = i.tenant_id
        $v$;

        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_purchase_orders AS
        SELECT o.tenant_id, o.org_id, o.bus_id,
               o.id                           AS source_id,
               coalesce(o.po_number, '')      AS number,
               coalesce(o.status, '')         AS status,
               o.order_date, o.expected_delivery_date,
               coalesce(o.notes, '')          AS notes,
               o.supplier_id,
               coalesce(s.fullname, '')       AS supplier_name,
               coalesce(o.destination, '')    AS destination,
               o.destination_loc_id,
               (SELECT max(l.currency) FROM invoicing.src_mystoreguard_purchase_order_lines l WHERE l.order_id = o.id) AS currency,
               (SELECT coalesce(sum(l.qty_ordered), 0) FROM invoicing.src_mystoreguard_purchase_order_lines l WHERE l.order_id = o.id)  AS qty_ordered,
               (SELECT coalesce(sum(l.qty_received), 0) FROM invoicing.src_mystoreguard_purchase_order_lines l WHERE l.order_id = o.id) AS qty_received,
               (SELECT coalesce(sum(l.qty_ordered * l.unit_cost - l.discount_amount), 0) FROM invoicing.src_mystoreguard_purchase_order_lines l WHERE l.order_id = o.id) AS total_cost,
               o.cdatetime
          FROM mystoreguard.msg_purchase_orders o
          LEFT JOIN mystoreguard.msg_suppliers s ON s.id = o.supplier_id AND s.bus_id = o.bus_id
        $v$;
    END IF;

    IF to_regclass('mystoreguard.msg_purchase_payments') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_purchase_payments AS
        SELECT p.tenant_id, p.bus_id, p.purchase_order_id AS order_id,
               coalesce(sum(p.paid_amount), 0) AS paid, max(p.cdatetime) AS last_paid_at
          FROM mystoreguard.msg_purchase_payments p
         WHERE p.deleted_at IS NULL AND coalesce(p.payment_status, 'SUCCESS') = 'SUCCESS'
         GROUP BY p.tenant_id, p.bus_id, p.purchase_order_id
        $v$;
    END IF;
END $$;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-invoicing-purchase-orders', 'Invoicing Purchase Orders', 'Purchase orders to suppliers', 'rt-subscribed-app-invoicing')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('purchase-orders', 'get',    'View purchase orders'),
    ('purchase-orders', 'create', 'Create purchase orders'),
    ('purchase-orders', 'update', 'Edit purchase orders and mark them received'),
    ('purchase-orders', 'delete', 'Delete draft purchase orders'),
    ('purchase-orders', 'send',   'Send purchase orders to suppliers'),
    ('purchase-orders', 'void',   'Cancel purchase orders')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime, app_prefix, resource_key, action, target, scope)
SELECT 'permission-invoicing-' || spec.resource_key || '-' || spec.action,
       'Invoicing Purchase Orders ' || initcap(spec.action), 'rt-invoicing-purchase-orders', spec.label,
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'invoicing', spec.resource_key, spec.action, '', 'any'
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description,
                               app_prefix = EXCLUDED.app_prefix, resource_key = EXCLUDED.resource_key,
                               action = EXCLUDED.action, target = EXCLUDED.target, scope = EXCLUDED.scope;

-- The manager everything; the clerk makes, sends and receives (no delete, no cancel); the
-- accountant and the viewer read.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-invoicing-manager', 'get'), ('role-invoicing-manager', 'create'), ('role-invoicing-manager', 'update'),
        ('role-invoicing-manager', 'delete'), ('role-invoicing-manager', 'send'), ('role-invoicing-manager', 'void'),
        ('role-invoicing-clerk', 'get'), ('role-invoicing-clerk', 'create'), ('role-invoicing-clerk', 'update'), ('role-invoicing-clerk', 'send'),
        ('role-invoicing-accountant', 'get'),
        ('role-invoicing-viewer', 'get')) AS spec(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.id = 'permission-invoicing-purchase-orders-' || spec.action
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

COMMIT;
