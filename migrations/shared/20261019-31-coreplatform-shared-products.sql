-- =====================================================================
-- Products, kept once per business in Core Platform; each app its own row
-- ---------------------------------------------------------------------
-- MyStoreGuard, Invoicing and the CRM each kept the business's products, and
-- the last two copied MyStoreGuard's in. WHAT a product is -- its name, SKU,
-- barcode, description, unit and category -- now lives once, per business:
--
--   core_platform.cp_products            a product or service of the business; a
--                                        kind a product is sold in (MyStoreGuard's
--                                        "256GB") is a product of its own, with
--                                        parent_id and variant
--   core_platform.cp_product_references  every column holding a product's id, so two
--                                        found to be one can be merged (cp_product_merge)
--
-- How an app sells it stays the app's, in a row of its own that is also how the app lists
-- it: a product is in MyStoreGuard when MyStoreGuard has its row (stock, tracking,
-- retirement), in Invoicing when Invoicing has priced it, in the CRM when the CRM has. So
-- a renamed product is renamed everywhere, and nothing is copied; but Invoicing does not
-- list a shop product it has never priced, and the shop does not list a consulting service.
--
--   * mystoreguard.msg_products   a VIEW of msg_product_profiles + cp_products. The 16
--                                 tables that pointed at the table point at the profile, with
--                                 the same delete rules (a price goes with its product, a
--                                 sale stops it being deleted). Kept as msg_products_legacy.
--   * invoicing.inv_items         a VIEW of inv_item_settings + cp_products. Kept as
--                                 inv_items_legacy.
--   * crm.crm_products            a VIEW of crm_product_settings + cp_products. Kept as
--                                 crm_products_legacy.
--   * Invoicing's and the CRM's copies of MyStoreGuard's products are merged into them by
--     their own link (source_id), and copies of the same kind into one product. A new item
--     brought in from MyStoreGuard is attached to its product, not copied.
--   * Deleting in one app removes that app's row; the product goes when no app has one.
--
-- Earlier migrations that alter or index these tables skip them once they are views. The EF
-- model still describes msg_products as a table: a future EF migration must not alter it. A
-- write through these views under session_replication_role = replica is silently lost.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_products (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    org_id      text NOT NULL,
    bus_id      text NOT NULL,
    parent_id   text REFERENCES core_platform.cp_products (id) ON DELETE SET NULL,
    variant     text NOT NULL DEFAULT '',
    kind        text NOT NULL DEFAULT 'goods' CHECK (kind IN ('goods', 'service')),
    name        text NOT NULL CHECK (btrim(name) <> ''),
    sku         text NOT NULL DEFAULT '',
    barcode     text NOT NULL DEFAULT '',
    code        text NOT NULL DEFAULT '',
    description text NOT NULL DEFAULT '',
    category    text NOT NULL DEFAULT '',
    unit        text NOT NULL DEFAULT '',
    source_app  text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS cp_products_bus_idx ON core_platform.cp_products (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS cp_products_variant_uq ON core_platform.cp_products (parent_id, variant) WHERE parent_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_product_references (
    table_name   text NOT NULL,
    column_name  text NOT NULL,
    -- An app's own row for the product: moved by a merge, it is not a use.
    is_extension boolean NOT NULL DEFAULT false,
    PRIMARY KEY (table_name, column_name)
);

-- merge: every reference to p_drop points at p_keep, and p_drop goes. Answers the rows moved.
CREATE OR REPLACE FUNCTION core_platform.cp_product_merge(p_keep text, p_drop text)
RETURNS integer LANGUAGE plpgsql AS $f$
DECLARE
    k core_platform.cp_products;
    d core_platform.cp_products;
    r record;
    moved integer := 0;
    n integer;
BEGIN
    SELECT * INTO k FROM core_platform.cp_products WHERE id = p_keep FOR UPDATE;
    SELECT * INTO d FROM core_platform.cp_products WHERE id = p_drop FOR UPDATE;
    IF k.id IS NULL OR d.id IS NULL OR k.id = d.id THEN
        RAISE EXCEPTION 'choose two different products to merge';
    END IF;
    IF k.tenant_id <> d.tenant_id OR k.bus_id <> d.bus_id THEN
        RAISE EXCEPTION 'only products of one business are merged';
    END IF;
    FOR r IN SELECT table_name, column_name, is_extension FROM core_platform.cp_product_references LOOP
        IF to_regclass(r.table_name) IS NOT NULL
           AND (SELECT relkind FROM pg_class WHERE oid = to_regclass(r.table_name)) = 'r' THEN
            BEGIN
                EXECUTE format('UPDATE %s SET %I = $1 WHERE %I = $2', r.table_name, r.column_name, r.column_name) USING p_keep, p_drop;
                GET DIAGNOSTICS n = ROW_COUNT;
                moved := moved + n;
            EXCEPTION WHEN unique_violation THEN
                IF NOT r.is_extension THEN
                    RAISE;
                END IF;
                EXECUTE format('DELETE FROM %s WHERE %I = $1', r.table_name, r.column_name) USING p_drop;
            END;
        END IF;
    END LOOP;
    UPDATE core_platform.cp_products SET parent_id = p_keep WHERE parent_id = p_drop AND variant NOT IN
        (SELECT variant FROM core_platform.cp_products WHERE parent_id = p_keep);
    UPDATE core_platform.cp_products SET
        sku = CASE WHEN sku = '' THEN d.sku ELSE sku END, barcode = CASE WHEN barcode = '' THEN d.barcode ELSE barcode END,
        code = CASE WHEN code = '' THEN d.code ELSE code END, description = CASE WHEN description = '' THEN d.description ELSE description END,
        category = CASE WHEN category = '' THEN d.category ELSE category END, unit = CASE WHEN unit = '' THEN d.unit ELSE unit END,
        updated_at = now()
     WHERE id = p_keep;
    DELETE FROM core_platform.cp_products WHERE id = p_drop;
    RETURN moved;
END
$f$;

-- has an app's row: is the product still in some app?
CREATE OR REPLACE FUNCTION core_platform.cp_product_kept(p_id text)
RETURNS boolean LANGUAGE plpgsql STABLE AS $f$
DECLARE r record; hit boolean;
BEGIN
    FOR r IN SELECT table_name, column_name FROM core_platform.cp_product_references LOOP
        IF to_regclass(r.table_name) IS NOT NULL AND (SELECT relkind FROM pg_class WHERE oid = to_regclass(r.table_name)) = 'r' THEN
            EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s WHERE %I = $1)', r.table_name, r.column_name) INTO hit USING p_id;
            IF hit THEN
                RETURN true;
            END IF;
        END IF;
    END LOOP;
    RETURN EXISTS (SELECT 1 FROM core_platform.cp_products WHERE parent_id = p_id);
END
$f$;

-- An app's item that came from MyStoreGuard: the product it is (source_id "prd"), or the kind
-- of it ("prd::256GB"), made when it is first brought in. NULL when MyStoreGuard has no such product.
CREATE OR REPLACE FUNCTION core_platform.cp_product_for_source(p_tenant text, p_bus text, p_source_id text, p_name text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
    parent text := split_part(p_source_id, '::', 1);
    v text := split_part(p_source_id, '::', 2);
    found text;
BEGIN
    IF p_source_id IS NULL OR p_source_id = '' THEN
        RETURN NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_products WHERE cp_products.id = parent AND cp_products.tenant_id = p_tenant AND cp_products.bus_id = p_bus) THEN
        RETURN NULL;
    END IF;
    IF v = '' THEN
        RETURN parent;
    END IF;
    SELECT c.id INTO found FROM core_platform.cp_products c WHERE c.parent_id = parent AND c.variant = v;
    IF found IS NULL THEN
        INSERT INTO core_platform.cp_products (tenant_id, org_id, bus_id, parent_id, variant, name, sku, barcode, description, category, unit, source_app)
        SELECT p.tenant_id, p.org_id, p.bus_id, p.id, v, coalesce(nullif(btrim(p_name), ''), p.name || ' – ' || v), p.sku, p.barcode, p.description,
               p.category, p.unit, 'mystoreguard'
          FROM core_platform.cp_products p WHERE p.id = parent
        RETURNING cp_products.id INTO found;
    END IF;
    RETURN found;
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.dependents(p_table regclass)
RETURNS TABLE (name text, def text) LANGUAGE sql AS $f$
    SELECT DISTINCT v.oid::regclass::text, pg_get_viewdef(v.oid)
      FROM pg_depend dp JOIN pg_rewrite rw ON rw.oid = dp.objid JOIN pg_class v ON v.oid = rw.ev_class
     WHERE dp.refobjid = p_table AND v.oid <> p_table
$f$;
CREATE TABLE IF NOT EXISTS pg_temp.rebuild (name text, def text);

-- ===================================================================== MyStoreGuard's, in
DO $$
DECLARE c record;
BEGIN
    IF to_regclass('mystoreguard.msg_products') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'mystoreguard.msg_products'::regclass) <> 'r' THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, name, sku, barcode, description, source_app, cdatetime, updated_at, created_by, updated_by)
    SELECT m.id, m.tenant_id, m.org_id, m.bus_id, coalesce(nullif(btrim(m.name), ''), 'Product'), coalesce(m.sku, ''), coalesce(m.bar_code, ''),
           coalesce(m.description, ''), 'mystoreguard', coalesce(m.cdatetime, now()), coalesce(m.cdatetime, now()), m.created_by, m.updated_by
      FROM mystoreguard.msg_products m
    ON CONFLICT (id) DO NOTHING;
    CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_profiles (
        product_id    text PRIMARY KEY REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
        tenant_id     text NOT NULL,
        org_id        text NOT NULL,
        bus_id        text NOT NULL,
        cdate         text,
        ctime         text,
        cdatetime     timestamptz,
        created_by    text,
        updated_by    text,
        deleted_by    text,
        delete_status text NOT NULL DEFAULT 'NOT_DELETED',
        is_active     boolean NOT NULL DEFAULT true,
        tracking_type text,
        retired_at    timestamptz,
        retired_by    text,
        retire_reason text,
        UNIQUE (tenant_id, org_id, bus_id, product_id)
    );
    INSERT INTO mystoreguard.msg_product_profiles (product_id, tenant_id, org_id, bus_id, cdate, ctime, cdatetime, created_by, updated_by, deleted_by,
           delete_status, is_active, tracking_type, retired_at, retired_by, retire_reason)
    SELECT m.id, m.tenant_id, m.org_id, m.bus_id, m.cdate, m.ctime, m.cdatetime, m.created_by, m.updated_by, m.deleted_by,
           coalesce(m.delete_status, 'NOT_DELETED'), coalesce(m.is_active, true), m.tracking_type, m.retired_at, m.retired_by, m.retire_reason
      FROM mystoreguard.msg_products m
    ON CONFLICT (product_id) DO NOTHING;
    -- The tables that pointed at the product point at MyStoreGuard's row for it, with the same rules.
    FOR c IN SELECT conrelid::regclass AS tbl, conname, pg_get_constraintdef(oid) AS def
               FROM pg_constraint WHERE confrelid = 'mystoreguard.msg_products'::regclass LOOP
        IF c.def !~ 'REFERENCES (mystoreguard\.)?msg_products\(tenant_id, org_id, bus_id, id\)' THEN
            RAISE EXCEPTION 'unexpected key on msg_products: % %', c.conname, c.def;
        END IF;
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.tbl, c.conname);
        EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s', c.tbl, c.conname,
                       regexp_replace(c.def, 'REFERENCES (mystoreguard\.)?msg_products\(tenant_id, org_id, bus_id, id\)',
                                      'REFERENCES mystoreguard.msg_product_profiles(tenant_id, org_id, bus_id, product_id)'));
    END LOOP;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents('mystoreguard.msg_products') d;
    ALTER TABLE mystoreguard.msg_products RENAME TO msg_products_legacy;
END $$;

-- ===================================================================== Invoicing's, in
DO $$
BEGIN
    IF to_regclass('invoicing.inv_items') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'invoicing.inv_items'::regclass) <> 'r' THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, kind, name, sku, code, description, category, unit, source_app,
           cdatetime, updated_at, created_by, updated_by)
    SELECT i.id, i.tenant_id, coalesce(i.org_id, b.org_id), i.bus_id, CASE WHEN i.kind = 'service' THEN 'service' ELSE 'goods' END, i.name, i.sku,
           coalesce(i.code, ''), i.description, i.category, i.unit, 'invoicing', i.cdatetime, i.updated_at, i.created_by, i.updated_by
      FROM invoicing.inv_items i JOIN core_platform.cp_businesses b ON b.id = i.bus_id
    ON CONFLICT (id) DO NOTHING;
    CREATE TABLE IF NOT EXISTS invoicing.inv_item_settings (
        item_id          text PRIMARY KEY REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
        tenant_id        text NOT NULL,
        bus_id           text NOT NULL,
        kind             text NOT NULL DEFAULT 'service' CHECK (kind IN ('product', 'service')),
        price            numeric(18, 6) NOT NULL DEFAULT 0,
        currency         char(3),
        tax_mode         text NOT NULL DEFAULT 'rules' CHECK (tax_mode IN ('rules', 'rate', 'group', 'none')),
        tax_rate_id      text REFERENCES core_platform.cp_tax_rates (id) ON DELETE SET NULL,
        tax_group_id     text REFERENCES core_platform.cp_tax_groups (id) ON DELETE SET NULL,
        archived_at      timestamptz,
        source_app       text,
        source_id        text,
        source_hash      text,
        source_removed   boolean NOT NULL DEFAULT false,
        source_locations text[] NOT NULL DEFAULT '{}',
        edited_locally   boolean NOT NULL DEFAULT false,
        imported_at      timestamptz,
        cdatetime        timestamptz NOT NULL DEFAULT now(),
        updated_at       timestamptz NOT NULL DEFAULT now(),
        created_by       text,
        updated_by       text
    );
    INSERT INTO invoicing.inv_item_settings (item_id, tenant_id, bus_id, kind, price, currency, tax_mode, tax_rate_id, tax_group_id, archived_at, source_app,
           source_id, source_hash, source_removed, source_locations, edited_locally, imported_at, cdatetime, updated_at, created_by, updated_by)
    SELECT i.id, i.tenant_id, i.bus_id, i.kind, i.price, i.currency, i.tax_mode, i.tax_rate_id, i.tax_group_id, i.archived_at, i.source_app, i.source_id,
           i.source_hash, i.source_removed, coalesce(i.source_locations, '{}'), i.edited_locally, i.imported_at, i.cdatetime, i.updated_at, i.created_by,
           i.updated_by
      FROM invoicing.inv_items i
    ON CONFLICT (item_id) DO NOTHING;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents('invoicing.inv_items') d;
    ALTER TABLE invoicing.inv_items RENAME TO inv_items_legacy;
END $$;

-- ===================================================================== the CRM's, in
DO $$
BEGIN
    IF to_regclass('crm.crm_products') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'crm.crm_products'::regclass) <> 'r' THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, name, sku, description, category, unit, source_app, cdatetime, updated_at,
           created_by, updated_by)
    SELECT p.id, p.tenant_id, coalesce(p.org_id, b.org_id), p.bus_id, coalesce(nullif(btrim(p.name), ''), 'Product'), coalesce(p.sku, ''),
           coalesce(p.description, ''), coalesce(p.category, ''), coalesce(p.unit_name, ''), 'crm', p.cdatetime, p.updated_at, p.created_by, p.updated_by
      FROM crm.crm_products p JOIN core_platform.cp_businesses b ON b.id = p.bus_id
    ON CONFLICT (id) DO NOTHING;
    CREATE TABLE IF NOT EXISTS crm.crm_product_settings (
        product_id     text PRIMARY KEY REFERENCES core_platform.cp_products (id) ON DELETE CASCADE,
        tenant_id      text NOT NULL,
        bus_id         text NOT NULL,
        unit_price     numeric(18, 2) NOT NULL DEFAULT 0,
        currency_id    text,
        tax_rate       numeric(12, 6) NOT NULL DEFAULT 0,
        source         text NOT NULL DEFAULT 'manual',
        source_id      text,
        source_hash    text,
        source_removed boolean NOT NULL DEFAULT false,
        is_active      boolean NOT NULL DEFAULT true,
        delete_status  text NOT NULL DEFAULT 'NOT_DELETED',
        created_by     text,
        updated_by     text,
        deleted_by     text,
        cdatetime      timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        list_price     numeric(18, 2),
        price_rule     text,
        tax_inclusive  boolean NOT NULL DEFAULT false,
        tax_names      text,
        final_price    numeric(18, 2),
        has_price      boolean NOT NULL DEFAULT true,
        priced_at      timestamptz
    );
    INSERT INTO crm.crm_product_settings (product_id, tenant_id, bus_id, unit_price, currency_id, tax_rate, source, source_id, source_hash, source_removed,
           is_active, delete_status, created_by, updated_by, deleted_by, cdatetime, updated_at, list_price, price_rule, tax_inclusive, tax_names,
           final_price, has_price, priced_at)
    SELECT p.id, p.tenant_id, p.bus_id, coalesce(p.unit_price, 0), p.currency_id, coalesce(p.tax_rate, 0), coalesce(p.source, 'manual'), p.source_id, p.source_hash, coalesce(p.source_removed, false),
           coalesce(p.is_active, true), coalesce(p.delete_status, 'NOT_DELETED'), p.created_by, p.updated_by, p.deleted_by, p.cdatetime, p.updated_at,
           p.list_price, p.price_rule, coalesce(p.tax_inclusive, false), p.tax_names, p.final_price, coalesce(p.has_price, true), p.priced_at
      FROM crm.crm_products p
    ON CONFLICT (product_id) DO NOTHING;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents('crm.crm_products') d;
    ALTER TABLE crm.crm_products RENAME TO crm_products_legacy;
END $$;

DO $$
BEGIN
    IF to_regclass('invoicing.inv_item_settings') IS NOT NULL THEN
        CREATE UNIQUE INDEX IF NOT EXISTS inv_item_settings_source_uq ON invoicing.inv_item_settings (bus_id, source_app, source_id) WHERE source_app IS NOT NULL;
    END IF;
    IF to_regclass('crm.crm_product_settings') IS NOT NULL THEN
        CREATE UNIQUE INDEX IF NOT EXISTS crm_product_settings_source_uq ON crm.crm_product_settings (tenant_id, bus_id, source, source_id) WHERE source_id IS NOT NULL;
    END IF;
    INSERT INTO core_platform.cp_product_references (table_name, column_name, is_extension) VALUES
        ('mystoreguard.msg_product_profiles', 'product_id', true), ('invoicing.inv_item_settings', 'item_id', true),
        ('crm.crm_product_settings', 'product_id', true),
        ('invoicing.inv_invoice_lines', 'item_id', false), ('crm.crm_deal_lines', 'product_id', false), ('crm.crm_quote_lines', 'product_id', false)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
END $$;

-- ===================================================================== the copies are the products
-- Invoicing's and the CRM's copies of a MyStoreGuard product become it; their copies of one kind
-- of it become one product (the kind).
DO $$
DECLARE c record; target text;
BEGIN
    IF to_regclass('invoicing.inv_item_settings') IS NOT NULL THEN
        FOR c IN SELECT st.item_id, st.tenant_id, st.bus_id, st.source_id, p.name FROM invoicing.inv_item_settings st
                   JOIN core_platform.cp_products p ON p.id = st.item_id
                  WHERE st.source_app = 'mystoreguard' AND st.source_id IS NOT NULL AND st.item_id <> st.source_id
                    AND p.parent_id IS NULL LOOP
            IF position('::' IN c.source_id) > 0 THEN
                -- A kind: the copy itself becomes the kind of the product, unless there is one.
                IF EXISTS (SELECT 1 FROM core_platform.cp_products WHERE id = split_part(c.source_id, '::', 1) AND bus_id = c.bus_id) THEN
                    SELECT id INTO target FROM core_platform.cp_products WHERE parent_id = split_part(c.source_id, '::', 1) AND variant = split_part(c.source_id, '::', 2);
                    IF target IS NULL THEN
                        UPDATE core_platform.cp_products SET parent_id = split_part(c.source_id, '::', 1), variant = split_part(c.source_id, '::', 2),
                               source_app = 'mystoreguard' WHERE id = c.item_id;
                    ELSE
                        PERFORM core_platform.cp_product_merge(target, c.item_id);
                    END IF;
                END IF;
            ELSIF EXISTS (SELECT 1 FROM core_platform.cp_products WHERE id = c.source_id AND bus_id = c.bus_id AND tenant_id = c.tenant_id) THEN
                PERFORM core_platform.cp_product_merge(c.source_id, c.item_id);
            END IF;
        END LOOP;
    END IF;
    IF to_regclass('crm.crm_product_settings') IS NOT NULL THEN
        FOR c IN SELECT st.product_id, st.tenant_id, st.bus_id, st.source_id FROM crm.crm_product_settings st
                   JOIN core_platform.cp_products p ON p.id = st.product_id
                  WHERE st.source = 'mystoreguard' AND st.source_id IS NOT NULL AND st.product_id <> st.source_id AND p.parent_id IS NULL LOOP
            IF position('::' IN c.source_id) > 0 THEN
                IF EXISTS (SELECT 1 FROM core_platform.cp_products WHERE id = split_part(c.source_id, '::', 1) AND bus_id = c.bus_id) THEN
                    SELECT id INTO target FROM core_platform.cp_products WHERE parent_id = split_part(c.source_id, '::', 1) AND variant = split_part(c.source_id, '::', 2);
                    IF target IS NULL THEN
                        UPDATE core_platform.cp_products SET parent_id = split_part(c.source_id, '::', 1), variant = split_part(c.source_id, '::', 2),
                               source_app = 'mystoreguard' WHERE id = c.product_id;
                    ELSE
                        PERFORM core_platform.cp_product_merge(target, c.product_id);
                    END IF;
                END IF;
            ELSIF EXISTS (SELECT 1 FROM core_platform.cp_products WHERE id = c.source_id AND bus_id = c.bus_id AND tenant_id = c.tenant_id) THEN
                PERFORM core_platform.cp_product_merge(c.source_id, c.product_id);
            END IF;
        END LOOP;
    END IF;
END $$;

-- ===================================================================== the views
DO $$
DECLARE r record;
BEGIN
    IF to_regclass('mystoreguard.msg_products_legacy') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW mystoreguard.msg_products AS
        SELECT pr.tenant_id, p.id, pr.org_id, pr.bus_id, p.name, nullif(p.sku, '') AS sku, nullif(p.barcode, '') AS bar_code, pr.cdate, pr.ctime,
               pr.cdatetime, pr.created_by, pr.updated_by, pr.deleted_by, pr.delete_status, pr.is_active, nullif(p.description, '') AS description,
               pr.tracking_type, pr.retired_at, pr.retired_by, pr.retire_reason
          FROM mystoreguard.msg_product_profiles pr
          JOIN core_platform.cp_products p ON p.id = pr.product_id
        $v$;
        EXECUTE $t$
        CREATE OR REPLACE FUNCTION mystoreguard.msg_products_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        BEGIN
            IF TG_OP = 'INSERT' THEN
                NEW.id := coalesce(NEW.id, gen_random_uuid()::text);
                INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, name, sku, barcode, description, source_app, cdatetime, created_by)
                VALUES (NEW.id, NEW.tenant_id, NEW.org_id, NEW.bus_id, coalesce(nullif(btrim(NEW.name), ''), 'Product'),
                       coalesce(NEW.sku, ''), coalesce(NEW.bar_code, ''), coalesce(NEW.description, ''), 'mystoreguard', coalesce(NEW.cdatetime, now()),
                       NEW.created_by)
                ON CONFLICT (id) DO NOTHING;
                INSERT INTO mystoreguard.msg_product_profiles (product_id, tenant_id, org_id, bus_id, cdate, ctime, cdatetime, created_by, updated_by,
                       deleted_by, delete_status, is_active, tracking_type, retired_at, retired_by, retire_reason)
                VALUES (NEW.id, NEW.tenant_id, NEW.org_id, NEW.bus_id, NEW.cdate, NEW.ctime, coalesce(NEW.cdatetime, now()), NEW.created_by, NEW.updated_by,
                       NEW.deleted_by, coalesce(NEW.delete_status, 'NOT_DELETED'), coalesce(NEW.is_active, true), NEW.tracking_type, NEW.retired_at,
                       NEW.retired_by, NEW.retire_reason);
                NEW.delete_status := coalesce(NEW.delete_status, 'NOT_DELETED');
                NEW.is_active := coalesce(NEW.is_active, true);
                RETURN NEW;
            ELSIF TG_OP = 'UPDATE' THEN
                UPDATE core_platform.cp_products SET name = coalesce(nullif(btrim(NEW.name), ''), name), sku = coalesce(NEW.sku, ''),
                       barcode = coalesce(NEW.bar_code, ''), description = coalesce(NEW.description, ''), updated_at = now(),
                       updated_by = coalesce(NEW.updated_by, updated_by)
                 WHERE id = OLD.id;
                UPDATE mystoreguard.msg_product_profiles SET updated_by = NEW.updated_by, deleted_by = NEW.deleted_by,
                       delete_status = coalesce(NEW.delete_status, 'NOT_DELETED'), is_active = coalesce(NEW.is_active, true), tracking_type = NEW.tracking_type,
                       retired_at = NEW.retired_at, retired_by = NEW.retired_by, retire_reason = NEW.retire_reason
                 WHERE product_id = OLD.id;
                RETURN NEW;
            ELSE
                -- Its rows in MyStoreGuard go (or stop it, as the table's keys did); the product
                -- itself goes when no other app sells it.
                DELETE FROM mystoreguard.msg_product_profiles WHERE product_id = OLD.id;
                IF NOT core_platform.cp_product_kept(OLD.id) THEN
                    DELETE FROM core_platform.cp_products WHERE id = OLD.id;
                END IF;
                RETURN OLD;
            END IF;
        END
        $f$
        $t$;
        DROP TRIGGER IF EXISTS msg_products_write ON mystoreguard.msg_products;
        CREATE TRIGGER msg_products_write INSTEAD OF INSERT OR UPDATE OR DELETE ON mystoreguard.msg_products
            FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_products_write();
    END IF;

    IF to_regclass('invoicing.inv_items_legacy') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.inv_items AS
        SELECT p.id, st.tenant_id, p.org_id, st.bus_id, st.kind, p.name, p.description, p.sku, p.category, p.unit, st.price, st.currency, st.tax_mode,
               st.tax_rate_id, st.tax_group_id, st.archived_at, st.source_app, st.source_id, st.source_hash, st.source_removed, st.source_locations,
               st.edited_locally, st.imported_at, st.cdatetime, st.updated_at, st.created_by, st.updated_by, p.code
          FROM invoicing.inv_item_settings st
          JOIN core_platform.cp_products p ON p.id = st.item_id
        $v$;
        EXECUTE $t$
        CREATE OR REPLACE FUNCTION invoicing.inv_items_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        DECLARE pid text;
        BEGIN
            IF TG_OP = 'DELETE' THEN
                DELETE FROM invoicing.inv_item_settings WHERE item_id = OLD.id;
                IF NOT core_platform.cp_product_kept(OLD.id) THEN
                    DELETE FROM core_platform.cp_products WHERE id = OLD.id;
                END IF;
                RETURN OLD;
            END IF;
            IF TG_OP = 'INSERT' THEN
                -- From MyStoreGuard: its product (or the kind of it), not a copy.
                IF NEW.source_app = 'mystoreguard' THEN
                    pid := core_platform.cp_product_for_source(NEW.tenant_id, NEW.bus_id, NEW.source_id, NEW.name);
                END IF;
                IF pid IS NULL THEN
                    INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, kind, name, sku, code, description, category, unit, source_app,
                           cdatetime, created_by, updated_by)
                    VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id,
                           coalesce(NEW.org_id, (SELECT org_id FROM core_platform.cp_businesses WHERE id = NEW.bus_id)), NEW.bus_id,
                           CASE WHEN NEW.kind = 'service' THEN 'service' ELSE 'goods' END, NEW.name, coalesce(NEW.sku, ''), coalesce(NEW.code, ''),
                           coalesce(NEW.description, ''), coalesce(NEW.category, ''), coalesce(NEW.unit, ''), coalesce(NEW.source_app, 'invoicing'),
                           coalesce(NEW.cdatetime, now()), NEW.created_by, NEW.updated_by)
                    RETURNING id INTO pid;
                END IF;
                NEW.id := pid;
                INSERT INTO invoicing.inv_item_settings (item_id, tenant_id, bus_id, kind, price, currency, tax_mode, tax_rate_id, tax_group_id, archived_at,
                       source_app, source_id, source_hash, source_removed, source_locations, edited_locally, imported_at, created_by, updated_by)
                VALUES (pid, NEW.tenant_id, NEW.bus_id, coalesce(NEW.kind, 'service'), coalesce(NEW.price, 0), NEW.currency, coalesce(NEW.tax_mode, 'rules'),
                       NEW.tax_rate_id, NEW.tax_group_id, NEW.archived_at, NEW.source_app, NEW.source_id, NEW.source_hash, coalesce(NEW.source_removed, false),
                       coalesce(NEW.source_locations, '{}'), coalesce(NEW.edited_locally, false), NEW.imported_at, NEW.created_by, NEW.updated_by);
                RETURN NEW;
            END IF;
            UPDATE core_platform.cp_products SET kind = CASE WHEN NEW.kind = 'service' THEN 'service' ELSE 'goods' END, name = NEW.name,
                   sku = coalesce(NEW.sku, ''), code = coalesce(NEW.code, ''), description = coalesce(NEW.description, ''),
                   category = coalesce(NEW.category, ''), unit = coalesce(NEW.unit, ''), updated_at = now(), updated_by = coalesce(NEW.updated_by, updated_by)
             WHERE id = OLD.id;
            UPDATE invoicing.inv_item_settings SET kind = coalesce(NEW.kind, kind), price = coalesce(NEW.price, 0), currency = NEW.currency,
                   tax_mode = coalesce(NEW.tax_mode, 'rules'), tax_rate_id = NEW.tax_rate_id, tax_group_id = NEW.tax_group_id, archived_at = NEW.archived_at,
                   source_app = NEW.source_app, source_id = NEW.source_id, source_hash = NEW.source_hash, source_removed = coalesce(NEW.source_removed, false),
                   source_locations = coalesce(NEW.source_locations, '{}'), edited_locally = coalesce(NEW.edited_locally, false),
                   imported_at = NEW.imported_at, updated_at = coalesce(NEW.updated_at, now()), updated_by = NEW.updated_by
             WHERE item_id = OLD.id;
            RETURN NEW;
        END
        $f$
        $t$;
        DROP TRIGGER IF EXISTS inv_items_write ON invoicing.inv_items;
        CREATE TRIGGER inv_items_write INSTEAD OF INSERT OR UPDATE OR DELETE ON invoicing.inv_items
            FOR EACH ROW EXECUTE FUNCTION invoicing.inv_items_write();
    END IF;

    IF to_regclass('crm.crm_products_legacy') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.crm_products AS
        SELECT p.id, st.tenant_id, p.org_id, st.bus_id, p.name, nullif(p.sku, '') AS sku, nullif(p.description, '') AS description, st.unit_price,
               st.currency_id, st.tax_rate, nullif(p.unit, '') AS unit_name, nullif(p.category, '') AS category, st.source, st.source_id, st.source_hash,
               st.source_removed, st.is_active, st.delete_status, st.created_by, st.updated_by, st.deleted_by, st.cdatetime, st.updated_at, st.list_price,
               st.price_rule, st.tax_inclusive, st.tax_names, st.final_price, st.has_price, st.priced_at
          FROM crm.crm_product_settings st
          JOIN core_platform.cp_products p ON p.id = st.product_id
        $v$;
        EXECUTE $t$
        CREATE OR REPLACE FUNCTION crm.crm_products_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        DECLARE pid text;
        BEGIN
            IF TG_OP = 'DELETE' THEN
                DELETE FROM crm.crm_product_settings WHERE product_id = OLD.id;
                IF NOT core_platform.cp_product_kept(OLD.id) THEN
                    DELETE FROM core_platform.cp_products WHERE id = OLD.id;
                END IF;
                RETURN OLD;
            END IF;
            IF TG_OP = 'INSERT' THEN
                IF NEW.source = 'mystoreguard' THEN
                    pid := core_platform.cp_product_for_source(NEW.tenant_id, NEW.bus_id, NEW.source_id, NEW.name);
                END IF;
                IF pid IS NULL THEN
                    INSERT INTO core_platform.cp_products (id, tenant_id, org_id, bus_id, name, sku, description, category, unit, source_app, cdatetime,
                           created_by, updated_by)
                    VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id,
                           coalesce(NEW.org_id, (SELECT org_id FROM core_platform.cp_businesses WHERE id = NEW.bus_id)), NEW.bus_id,
                           coalesce(nullif(btrim(NEW.name), ''), 'Product'), coalesce(NEW.sku, ''), coalesce(NEW.description, ''), coalesce(NEW.category, ''),
                           coalesce(NEW.unit_name, ''), coalesce(nullif(NEW.source, ''), 'crm'), coalesce(NEW.cdatetime, now()), NEW.created_by, NEW.updated_by)
                    RETURNING id INTO pid;
                END IF;
                NEW.id := pid;
                INSERT INTO crm.crm_product_settings (product_id, tenant_id, bus_id, unit_price, currency_id, tax_rate, source, source_id, source_hash,
                       source_removed, is_active, delete_status, created_by, updated_by, deleted_by, list_price, price_rule, tax_inclusive, tax_names,
                       final_price, has_price, priced_at)
                VALUES (pid, NEW.tenant_id, NEW.bus_id, coalesce(NEW.unit_price, 0), NEW.currency_id, coalesce(NEW.tax_rate, 0), coalesce(NEW.source, 'manual'),
                       NEW.source_id, NEW.source_hash,
                       coalesce(NEW.source_removed, false), coalesce(NEW.is_active, true), coalesce(NEW.delete_status, 'NOT_DELETED'), NEW.created_by,
                       NEW.updated_by, NEW.deleted_by, NEW.list_price, NEW.price_rule, coalesce(NEW.tax_inclusive, false), NEW.tax_names, NEW.final_price,
                       coalesce(NEW.has_price, true), NEW.priced_at);
                NEW.is_active := coalesce(NEW.is_active, true);
                NEW.delete_status := coalesce(NEW.delete_status, 'NOT_DELETED');
                NEW.source_removed := coalesce(NEW.source_removed, false);
                NEW.source := coalesce(NEW.source, 'manual');
                NEW.unit_price := coalesce(NEW.unit_price, 0);
                NEW.tax_rate := coalesce(NEW.tax_rate, 0);
                RETURN NEW;
            END IF;
            UPDATE core_platform.cp_products SET name = coalesce(nullif(btrim(NEW.name), ''), name), sku = coalesce(NEW.sku, ''),
                   description = coalesce(NEW.description, ''), category = coalesce(NEW.category, ''), unit = coalesce(NEW.unit_name, ''),
                   updated_at = now(), updated_by = coalesce(NEW.updated_by, updated_by)
             WHERE id = OLD.id;
            UPDATE crm.crm_product_settings SET unit_price = coalesce(NEW.unit_price, 0), currency_id = NEW.currency_id, tax_rate = coalesce(NEW.tax_rate, 0),
                   source = coalesce(NEW.source, 'manual'),
                   source_id = NEW.source_id, source_hash = NEW.source_hash, source_removed = coalesce(NEW.source_removed, false),
                   is_active = coalesce(NEW.is_active, true), delete_status = coalesce(NEW.delete_status, 'NOT_DELETED'), updated_by = NEW.updated_by,
                   deleted_by = NEW.deleted_by, updated_at = coalesce(NEW.updated_at, now()), list_price = NEW.list_price, price_rule = NEW.price_rule,
                   tax_inclusive = coalesce(NEW.tax_inclusive, false), tax_names = NEW.tax_names, final_price = NEW.final_price,
                   has_price = coalesce(NEW.has_price, true), priced_at = NEW.priced_at
             WHERE product_id = OLD.id;
            RETURN NEW;
        END
        $f$
        $t$;
        DROP TRIGGER IF EXISTS crm_products_write ON crm.crm_products;
        CREATE TRIGGER crm_products_write INSTEAD OF INSERT OR UPDATE OR DELETE ON crm.crm_products
            FOR EACH ROW EXECUTE FUNCTION crm.crm_products_write();
    END IF;

    FOR r IN SELECT name, def FROM pg_temp.rebuild LOOP
        EXECUTE format('CREATE OR REPLACE VIEW %s AS %s', r.name,
                       replace(replace(replace(r.def, 'msg_products_legacy', 'msg_products'), 'inv_items_legacy', 'inv_items'),
                               'crm_products_legacy', 'crm_products'));
    END LOOP;
END $$;

COMMIT;
