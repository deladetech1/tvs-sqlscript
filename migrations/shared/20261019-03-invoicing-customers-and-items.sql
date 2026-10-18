-- Invoicing Release 1, part one: customers and the products and services invoices are for.
--
-- Customers (inv_customers): who an invoice goes to -- their name, contacts, billing address
-- (country, region and postcode decide their tax), tax number, the currency and language their
-- invoices are in, their terms and the customer groups tax rules match on.
--
-- Items (inv_items): products and services, each with its price and currency, its category
-- (tax rules match on it) and its tax: by the rules, one chosen rate or group, or none.
--
-- Either may come from another app of the suite: customers from MyStoreGuard and LoanDrift,
-- products from MyStoreGuard. source_app + source_id link the row to where it came from, so
-- importing again updates rather than doubles; edited_locally keeps the business's own
-- changes from being written over by the next import.
--
-- The sources are read through views made only where the source app's tables exist (an
-- enterprise or silo database without one simply has no view, and Invoicing offers no import
-- from it):
--   * invoicing.src_mystoreguard_customers, invoicing.src_loandrift_clients;
--   * invoicing.src_mystoreguard_products: a product, or one per kind (product_size) where the
--     kinds sell at different prices -- as MyStoreGuard's till prices them;
--   * invoicing.src_mystoreguard_product_locations: the locations a product is at (a store or
--     warehouse row, or stock in a delivery there), so an import can be limited to the
--     locations someone may see;
--   * invoicing.msg_base_price(tenant, business, product, batch, location): MyStoreGuard's own
--     base price -- the best STORE price row (a location's own price first when one location is
--     named), else the latest delivery's base selling price. MyStoreGuard's pricing rules and
--     taxes are its own; an imported price is before tax, and Invoicing's taxes apply.
-- Views and the function are owned by the migrator and read MyStoreGuard and LoanDrift as it;
-- Invoicing's login needs no grant on their tables.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_customers (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    kind                text NOT NULL DEFAULT 'business' CHECK (kind IN ('business', 'person')),
    name                text NOT NULL CHECK (btrim(name) <> ''),
    contact_name        text NOT NULL DEFAULT '',
    email               text NOT NULL DEFAULT '',
    cc_emails           text[] NOT NULL DEFAULT '{}',
    phone               text NOT NULL DEFAULT '',
    website             text NOT NULL DEFAULT '',
    tax_number          text NOT NULL DEFAULT '',
    address_line1       text NOT NULL DEFAULT '',
    address_line2       text NOT NULL DEFAULT '',
    city                text NOT NULL DEFAULT '',
    region              text NOT NULL DEFAULT '',
    postal_code         text NOT NULL DEFAULT '',
    country             char(2) CHECK (country IS NULL OR country ~ '^[A-Z]{2}$'),
    -- Their invoices' currency and language; NULL: the business's own.
    currency            char(3) CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    locale              text,
    payment_terms_days  integer CHECK (payment_terms_days IS NULL OR payment_terms_days BETWEEN 0 AND 3650),
    groups              text[] NOT NULL DEFAULT '{}',
    notes               text NOT NULL DEFAULT '',
    archived_at         timestamptz,
    source_app          text CHECK (source_app IS NULL OR source_app IN ('mystoreguard', 'loandrift')),
    source_id           text,
    source_hash         text,
    source_removed      boolean NOT NULL DEFAULT false,
    edited_locally      boolean NOT NULL DEFAULT false,
    imported_at         timestamptz,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_by          text
);
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        CREATE INDEX IF NOT EXISTS inv_customers_bus_idx ON invoicing.inv_customers (bus_id, lower(name));
    END IF;
END $guard$;
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        CREATE UNIQUE INDEX IF NOT EXISTS inv_customers_source_uq ON invoicing.inv_customers (bus_id, source_app, source_id) WHERE source_app IS NOT NULL;
    END IF;
END $guard$;
-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        CREATE INDEX IF NOT EXISTS inv_customers_email_idx ON invoicing.inv_customers (bus_id, lower(email)) WHERE email <> '';
    END IF;
END $guard$;

CREATE TABLE IF NOT EXISTS invoicing.inv_items (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    kind             text NOT NULL DEFAULT 'service' CHECK (kind IN ('product', 'service')),
    name             text NOT NULL CHECK (btrim(name) <> ''),
    description      text NOT NULL DEFAULT '',
    sku              text NOT NULL DEFAULT '',
    category         text NOT NULL DEFAULT '',
    unit             text NOT NULL DEFAULT '',
    price            numeric(18, 6) NOT NULL DEFAULT 0 CHECK (price >= 0),
    currency         char(3) CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    -- rules: the business's tax rules decide; rate/group: this one always; none: no tax.
    tax_mode         text NOT NULL DEFAULT 'rules' CHECK (tax_mode IN ('rules', 'rate', 'group', 'none')),
    tax_rate_id      text REFERENCES invoicing.inv_tax_rates (id) ON DELETE SET NULL,
    tax_group_id     text REFERENCES invoicing.inv_tax_groups (id) ON DELETE SET NULL,
    archived_at      timestamptz,
    source_app       text CHECK (source_app IS NULL OR source_app = 'mystoreguard'),
    source_id        text,
    source_hash      text,
    source_removed   boolean NOT NULL DEFAULT false,
    -- The locations it was imported from (MyStoreGuard loc ids), for the record.
    source_locations text[] NOT NULL DEFAULT '{}',
    edited_locally   boolean NOT NULL DEFAULT false,
    imported_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_by       text
);
-- Only while it is a table (a view of Core Platform's products since 20261019-31).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_items')) = 'r' THEN
        CREATE INDEX IF NOT EXISTS inv_items_bus_idx ON invoicing.inv_items (bus_id, lower(name));
    END IF;
END $guard$;
-- Only while it is a table (a view of Core Platform's products since 20261019-31).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_items')) = 'r' THEN
        CREATE UNIQUE INDEX IF NOT EXISTS inv_items_source_uq ON invoicing.inv_items (bus_id, source_app, source_id) WHERE source_app IS NOT NULL;
    END IF;
END $guard$;

-- Each import, for "last imported ... : 12 added, 3 updated".
CREATE TABLE IF NOT EXISTS invoicing.inv_imports (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    source      text NOT NULL,
    added       integer NOT NULL DEFAULT 0,
    updated     integer NOT NULL DEFAULT 0,
    linked      integer NOT NULL DEFAULT 0,
    unchanged   integer NOT NULL DEFAULT 0,
    removed     integer NOT NULL DEFAULT 0,
    locations   text[] NOT NULL DEFAULT '{}',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE INDEX IF NOT EXISTS inv_imports_bus_idx ON invoicing.inv_imports (bus_id, source, cdatetime DESC);

-- ================================================================== source views
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_customers') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_mystoreguard_customers AS
        SELECT c.tenant_id, c.org_id, c.bus_id,
               c.id                                AS source_id,
               btrim(c.fullname)                   AS name,
               NULLIF(btrim(c.contact), '')        AS phone,
               NULLIF(lower(btrim(c.email)), '')   AS email,
               NULLIF(btrim(c.address), '')        AS address_line,
               (c.delete_status <> 'NOT_DELETED' OR c.is_active IS FALSE) AS is_removed,
               md5(row(c.fullname, c.contact, c.email, c.address, c.delete_status, c.is_active)::text) AS row_hash
          FROM mystoreguard.msg_customers c
        $v$;
    END IF;

    IF to_regclass('loandrift.ld_clients') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.src_loandrift_clients AS
        SELECT c.tenant_id, c.org_id, c.bus_id,
               c.id                                    AS source_id,
               btrim(coalesce(NULLIF(btrim(c.fullname), ''),
                     concat_ws(' ', NULLIF(btrim(c.first_name), ''), NULLIF(btrim(c.middle_names), ''), NULLIF(btrim(c.surname), '')))) AS name,
               NULLIF(btrim(c.contact), '')            AS phone,
               NULLIF(lower(btrim(c.email)), '')       AS email,
               NULLIF(btrim(c.residential_address), '') AS address_line,
               (c.delete_status <> 'NOT_DELETED' OR c.is_active IS FALSE) AS is_removed,
               md5(row(c.fullname, c.first_name, c.middle_names, c.surname, c.contact, c.email, c.residential_address,
                       c.delete_status, c.is_active)::text) AS row_hash
          FROM loandrift.ld_clients c
        $v$;
    END IF;

    IF to_regclass('mystoreguard.msg_products') IS NOT NULL AND to_regclass('mystoreguard.msg_purchase_batches') IS NOT NULL
       AND to_regclass('mystoreguard.msg_product_prices') IS NOT NULL AND to_regclass('mystoreguard.msg_product_metadata') IS NOT NULL
       AND to_regclass('mystoreguard.msg_assign_metadata_to_products') IS NOT NULL THEN

        -- MyStoreGuard's base price (its till's first step); no pricing rule, no tax.
        EXECUTE $fn$
        CREATE OR REPLACE FUNCTION invoicing.msg_base_price(p_tenant text, p_bus text, p_product text, p_batch text DEFAULT NULL, p_loc text DEFAULT NULL)
        RETURNS TABLE (price numeric, currency_id text, has_price boolean)
        LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $body$
        DECLARE
            v_sku text; v_cat text[]; v_tag text[]; v_brand text[]; v_label text[];
            v_base numeric; v_cur text; v_row numeric; v_row_cur text;
        BEGIN
            SELECT NULLIF(btrim(p.sku), '') INTO v_sku FROM mystoreguard.msg_products p
             WHERE p.id = p_product AND p.tenant_id = p_tenant AND p.bus_id = p_bus;
            SELECT array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'CATEGORY'), array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'TAG'),
                   array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'BRAND'), array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'LABEL')
              INTO v_cat, v_tag, v_brand, v_label
              FROM mystoreguard.msg_assign_metadata_to_products amp
              JOIN mystoreguard.msg_product_metadata pm ON pm.id = amp.product_metadata_id AND pm.tenant_id = amp.tenant_id AND pm.bus_id = amp.bus_id
             WHERE amp.tenant_id = p_tenant AND amp.bus_id = p_bus AND amp.product_id = p_product AND pm.delete_status = 'NOT_DELETED';
            SELECT b.base_selling_price, b.currency_id INTO v_base, v_cur
              FROM mystoreguard.msg_purchase_batches b
             WHERE b.product_id = p_product AND b.tenant_id = p_tenant AND b.bus_id = p_bus AND b.delete_status = 'NOT_DELETED'
               AND (p_batch IS NULL OR b.id = p_batch)
             ORDER BY b.cdatetime DESC, b.id DESC LIMIT 1;
            SELECT x.price, x.currency INTO v_row, v_row_cur
              FROM mystoreguard.msg_product_prices x
             WHERE x.product_id = p_product AND x.tenant_id = p_tenant AND x.bus_id = p_bus
               AND x.channel = 'STORE' AND (x.deleted_by IS NULL OR x.deleted_by = '')
               AND (   x.of_type = 'GLOBAL'
                    OR (x.of_type = 'SKU' AND x.target_id = v_sku)
                    OR (x.of_type = 'LOCATION' AND p_loc IS NOT NULL AND x.target_id = p_loc)
                    OR (x.of_type = 'CATEGORY' AND x.target_id = ANY(v_cat))
                    OR (x.of_type = 'TAG' AND x.target_id = ANY(v_tag))
                    OR (x.of_type = 'BRAND' AND x.target_id = ANY(v_brand))
                    OR (x.of_type = 'LABEL' AND x.target_id = ANY(v_label)))
             ORDER BY coalesce(x.stops_other_prices, false) DESC,
                      CASE x.of_type WHEN 'SKU' THEN 1 WHEN 'LOCATION' THEN 2 WHEN 'TAG' THEN 3 WHEN 'CATEGORY' THEN 3
                                     WHEN 'BRAND' THEN 3 WHEN 'LABEL' THEN 3 WHEN 'GLOBAL' THEN 4 END,
                      x.priority DESC
             LIMIT 1;
            IF FOUND THEN
                RETURN QUERY SELECT round(v_row, 2), coalesce(v_cur, v_row_cur), true;
            ELSIF v_base IS NOT NULL THEN
                RETURN QUERY SELECT round(v_base, 2), v_cur, true;
            ELSE
                RETURN QUERY SELECT 0::numeric, v_cur, false;
            END IF;
        END;
        $body$
        $fn$;

        -- What is built on it (20261019-21's locations view) goes first; 21 builds it again.
        EXECUTE 'DROP VIEW IF EXISTS invoicing.src_mystoreguard_item_locations';
        EXECUTE 'DROP VIEW IF EXISTS invoicing.src_mystoreguard_products';
        EXECUTE $v$
        CREATE VIEW invoicing.src_mystoreguard_products AS
        WITH kinds AS (
            SELECT DISTINCT ON (b.product_id, lower(regexp_replace(b.product_size, '\s+', '', 'g')))
                   b.product_id, b.tenant_id, b.bus_id, btrim(b.product_size) AS kind, b.id AS batch_id, b.base_selling_price
              FROM mystoreguard.msg_purchase_batches b
             WHERE b.delete_status = 'NOT_DELETED' AND NULLIF(btrim(b.product_size), '') IS NOT NULL
             ORDER BY b.product_id, lower(regexp_replace(b.product_size, '\s+', '', 'g')), b.cdatetime DESC, b.id DESC
        ), split AS (
            SELECT k.product_id, k.tenant_id, k.bus_id FROM kinds k
             GROUP BY k.product_id, k.tenant_id, k.bus_id
            HAVING count(DISTINCT k.base_selling_price) > 1
               AND NOT EXISTS (SELECT 1 FROM mystoreguard.msg_product_prices x
                                WHERE x.product_id = k.product_id AND x.tenant_id = k.tenant_id AND x.bus_id = k.bus_id
                                  AND x.channel = 'STORE' AND (x.deleted_by IS NULL OR x.deleted_by = ''))
        ), category AS (
            SELECT DISTINCT ON (amp.product_id) amp.product_id, amp.tenant_id, btrim(pm.name) AS name
              FROM mystoreguard.msg_assign_metadata_to_products amp
              JOIN mystoreguard.msg_product_metadata pm ON pm.id = amp.product_metadata_id AND pm.tenant_id = amp.tenant_id
             WHERE upper(pm.of_type) = 'CATEGORY' AND pm.delete_status = 'NOT_DELETED'
             ORDER BY amp.product_id, pm.name
        ), unit AS (
            SELECT DISTINCT ON (b.product_id) b.product_id, b.tenant_id, b.unit_of_measure_id
              FROM mystoreguard.msg_purchase_batches b WHERE b.delete_status = 'NOT_DELETED'
             ORDER BY b.product_id, b.cdatetime DESC, b.id DESC
        )
        SELECT p.tenant_id, p.org_id, p.bus_id, p.id || '::' || k.kind AS source_id, p.id AS product_id, k.batch_id,
               btrim(p.name) || ' – ' || k.kind AS name, NULLIF(btrim(p.sku), '') AS sku, NULLIF(btrim(p.description), '') AS description,
               c.name AS category, u.unit_of_measure_id,
               (p.delete_status <> 'NOT_DELETED' OR p.is_active IS FALSE OR p.retired_at IS NOT NULL) AS is_removed
          FROM mystoreguard.msg_products p
          JOIN split sp ON sp.product_id = p.id AND sp.tenant_id = p.tenant_id AND sp.bus_id = p.bus_id
          JOIN kinds k ON k.product_id = p.id AND k.tenant_id = p.tenant_id AND k.bus_id = p.bus_id
          LEFT JOIN category c ON c.product_id = p.id AND c.tenant_id = p.tenant_id
          LEFT JOIN unit u ON u.product_id = p.id AND u.tenant_id = p.tenant_id
        UNION ALL
        SELECT p.tenant_id, p.org_id, p.bus_id, p.id, p.id, NULL::text,
               btrim(p.name), NULLIF(btrim(p.sku), ''), NULLIF(btrim(p.description), ''),
               c.name, u.unit_of_measure_id,
               (p.delete_status <> 'NOT_DELETED' OR p.is_active IS FALSE OR p.retired_at IS NOT NULL)
          FROM mystoreguard.msg_products p
          LEFT JOIN category c ON c.product_id = p.id AND c.tenant_id = p.tenant_id
          LEFT JOIN unit u ON u.product_id = p.id AND u.tenant_id = p.tenant_id
         WHERE NOT EXISTS (SELECT 1 FROM split sp WHERE sp.product_id = p.id AND sp.tenant_id = p.tenant_id AND sp.bus_id = p.bus_id)
            OR EXISTS (SELECT 1 FROM mystoreguard.msg_purchase_batches b
                        WHERE b.product_id = p.id AND b.tenant_id = p.tenant_id AND b.bus_id = p.bus_id
                          AND b.delete_status = 'NOT_DELETED' AND NULLIF(btrim(b.product_size), '') IS NULL)
        $v$;

        -- Where a product is: a store or warehouse row for it, or stock of one of its deliveries.
        EXECUTE 'DROP VIEW IF EXISTS invoicing.src_mystoreguard_product_locations';
        EXECUTE format($v$
        CREATE VIEW invoicing.src_mystoreguard_product_locations AS
        SELECT DISTINCT tenant_id, bus_id, product_id, loc_id FROM (
            SELECT sp.tenant_id, sp.bus_id, sp.product_id, sp.loc_id FROM mystoreguard.msg_store_products sp
             WHERE sp.delete_status = 'NOT_DELETED' AND sp.loc_id IS NOT NULL
            %s
            UNION ALL
            SELECT b.tenant_id, b.bus_id, b.product_id, bl.loc_id
              FROM mystoreguard.msg_batch_locations bl
              JOIN mystoreguard.msg_purchase_batches b ON b.id = bl.purchase_batche_id AND b.tenant_id = bl.tenant_id
             WHERE bl.qty > 0 AND b.delete_status = 'NOT_DELETED'
        ) x
        $v$, CASE WHEN to_regclass('mystoreguard.msg_warehouse_products') IS NOT NULL THEN
                'UNION ALL SELECT wp.tenant_id, wp.bus_id, wp.product_id, wp.loc_id FROM mystoreguard.msg_warehouse_products wp
                  WHERE wp.delete_status = ''NOT_DELETED'' AND wp.loc_id IS NOT NULL' ELSE '' END);
    END IF;
END $$;

COMMIT;
