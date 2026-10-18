-- =====================================================================
-- Suppliers, kept once per business in Core Platform and used by every app
-- ---------------------------------------------------------------------
-- MyStoreGuard, Expenses, Invoicing and Accounting each kept their own list of
-- the people and companies a business buys from; a supplier's new phone number
-- reached one app and not the others, and Accounting could not tell that the
-- "Kasapreko" of one app was the "Kasapreko" of another. Who a supplier IS now
-- lives in Core Platform, once per business (a pharmacy and a hardware shop of
-- one owner buy from different people), shared by every app the business uses:
--
--   core_platform.cp_parties            a person or company the business deals
--                                       with: a supplier (is_supplier), and later its
--                                       customers too (is_customer) -- one record
--                                       when it is both
--   core_platform.cp_party_references   every column in the suite that holds a
--                                       party's id, so two records found to be one
--                                       can be merged (cp_party_merge) everywhere
--
-- What an app alone needs about a supplier stays in the app (MyStoreGuard's
-- profile picture and attachments, Expenses' default category per business).
--
--   * MyStoreGuard's msg_suppliers table becomes a VIEW of the business's
--     suppliers, with the columns MyStoreGuard reads; its supplier screens
--     write through it. Done once, while it is still a
--     table; the old table is kept as msg_suppliers_legacy. Ids are kept, so
--     purchase orders, batches, returns and attachments still point at the
--     same supplier. Nothing is merged automatically: two "EBA"s of one
--     business stay two records until someone merges them.
--   * Expenses' vendors are the business's suppliers. Its own default
--     category per business is in exp_vendor_settings; the old exp_vendors
--     table is kept as exp_vendors_legacy.
--   * Invoicing (inv_customers, role supplier/both) and Accounting
--     (acc_suppliers) adopt it next; until then they keep their own.
--
-- The EF model in Trovesuite.Database.MyStoreGuard still describes msg_suppliers
-- as a table, as it does msg_taxes: a future EF migration must not alter it.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_parties (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    kind               text NOT NULL DEFAULT 'company' CHECK (kind IN ('company', 'person')),
    name               text NOT NULL CHECK (btrim(name) <> ''),
    contact_name       text NOT NULL DEFAULT '',
    email              text NOT NULL DEFAULT '',
    phone              text NOT NULL DEFAULT '',
    tax_number         text NOT NULL DEFAULT '',
    address_line1      text NOT NULL DEFAULT '',
    address_line2      text NOT NULL DEFAULT '',
    city               text NOT NULL DEFAULT '',
    region             text NOT NULL DEFAULT '',
    postal_code        text NOT NULL DEFAULT '',
    country            char(2),
    currency           char(3),
    payment_terms_days integer CHECK (payment_terms_days IS NULL OR payment_terms_days BETWEEN 0 AND 3650),
    is_supplier        boolean NOT NULL DEFAULT false,
    is_customer        boolean NOT NULL DEFAULT false,
    -- Where to send it money: {kind: mobile_money|bank, bank_code, bank_name, account_number, account_name}.
    pay_to             jsonb NOT NULL DEFAULT '{}',
    notes              text NOT NULL DEFAULT '',
    -- The app it was first entered in.
    source_app         text NOT NULL DEFAULT '',
    archived_at        timestamptz,
    deleted_at         timestamptz,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_by         text,
    deleted_by         text
);
CREATE INDEX IF NOT EXISTS cp_parties_bus_idx ON core_platform.cp_parties (tenant_id, bus_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS cp_parties_name_idx ON core_platform.cp_parties (bus_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_party_references (
    table_name  text NOT NULL,
    column_name text NOT NULL,
    PRIMARY KEY (table_name, column_name)
);
-- An extension (an app's own fields, a customer's saved cards or points) moves with the party when
-- two are merged but does not stop it being deleted; anything else (a sale, an order, a bill) does.
ALTER TABLE core_platform.cp_party_references ADD COLUMN IF NOT EXISTS is_extension boolean NOT NULL DEFAULT false;

-- in use: does anything other than an extension point at the party?
CREATE OR REPLACE FUNCTION core_platform.cp_party_in_use(p_id text)
RETURNS boolean LANGUAGE plpgsql STABLE AS $f$
DECLARE
    r record;
    hit boolean;
BEGIN
    FOR r IN SELECT table_name, column_name FROM core_platform.cp_party_references WHERE NOT is_extension LOOP
        IF to_regclass(r.table_name) IS NOT NULL
           AND (SELECT relkind FROM pg_class WHERE oid = to_regclass(r.table_name)) = 'r' THEN
            EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s WHERE %I = $1)', r.table_name, r.column_name) INTO hit USING p_id;
            IF hit THEN
                RETURN true;
            END IF;
        END IF;
    END LOOP;
    RETURN false;
END
$f$;

-- merge: everything that points at p_drop points at p_keep, and p_drop is marked deleted
-- (merged). Both must be the same business's. Answers the rows moved.
CREATE OR REPLACE FUNCTION core_platform.cp_party_merge(p_keep text, p_drop text, p_by text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql AS $f$
DECLARE
    k core_platform.cp_parties;
    d core_platform.cp_parties;
    r record;
    moved integer := 0;
    n integer;
BEGIN
    SELECT * INTO k FROM core_platform.cp_parties WHERE id = p_keep AND deleted_at IS NULL FOR UPDATE;
    SELECT * INTO d FROM core_platform.cp_parties WHERE id = p_drop AND deleted_at IS NULL FOR UPDATE;
    IF k.id IS NULL OR d.id IS NULL OR k.id = d.id THEN
        RAISE EXCEPTION 'choose two different records to merge';
    END IF;
    IF k.tenant_id <> d.tenant_id OR k.bus_id <> d.bus_id THEN
        RAISE EXCEPTION 'only records of one business are merged';
    END IF;
    FOR r IN SELECT table_name, column_name, is_extension FROM core_platform.cp_party_references LOOP
        IF to_regclass(r.table_name) IS NOT NULL
           AND (SELECT relkind FROM pg_class WHERE oid = to_regclass(r.table_name)) = 'r' THEN
            BEGIN
                EXECUTE format('UPDATE %s SET %I = $1 WHERE %I = $2', r.table_name, r.column_name, r.column_name) USING p_keep, p_drop;
                GET DIAGNOSTICS n = ROW_COUNT;
                moved := moved + n;
            EXCEPTION WHEN unique_violation THEN
                -- An app's own row for each party (its settings, a profile): the kept one's stays.
                IF NOT r.is_extension THEN
                    RAISE;
                END IF;
                EXECUTE format('DELETE FROM %s WHERE %I = $1', r.table_name, r.column_name) USING p_drop;
            END;
        END IF;
    END LOOP;
    -- What the kept record lacks, it takes from the other.
    UPDATE core_platform.cp_parties SET
        email = CASE WHEN email = '' THEN d.email ELSE email END,
        phone = CASE WHEN phone = '' THEN d.phone ELSE phone END,
        tax_number = CASE WHEN tax_number = '' THEN d.tax_number ELSE tax_number END,
        address_line1 = CASE WHEN address_line1 = '' THEN d.address_line1 ELSE address_line1 END,
        city = CASE WHEN city = '' THEN d.city ELSE city END,
        pay_to = CASE WHEN pay_to = '{}'::jsonb THEN d.pay_to ELSE pay_to END,
        notes = CASE WHEN notes = '' THEN d.notes WHEN d.notes = '' THEN notes ELSE notes || E'\n' || d.notes END,
        is_supplier = is_supplier OR d.is_supplier, is_customer = is_customer OR d.is_customer,
        updated_at = now(), updated_by = coalesce(p_by, updated_by)
     WHERE id = p_keep;
    UPDATE core_platform.cp_parties SET deleted_at = now(), deleted_by = p_by, is_customer = false, is_supplier = false,
           notes = CASE WHEN notes = '' THEN 'Merged into ' || p_keep ELSE notes || E'\nMerged into ' || p_keep END
     WHERE id = p_drop;
    RETURN moved;
END
$f$;

-- ===================================================================== MyStoreGuard's
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_suppliers') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'mystoreguard.msg_suppliers'::regclass) <> 'r' THEN
        RETURN;  -- already a view, or no MyStoreGuard here
    END IF;
    INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, name, email, phone, address_line1, notes, is_supplier, source_app,
           archived_at, deleted_at, cdatetime, updated_at, created_by, updated_by, deleted_by)
    SELECT s.id, s.tenant_id, s.org_id, s.bus_id, coalesce(nullif(btrim(s.fullname), ''), 'Supplier'), coalesce(btrim(s.email), ''), coalesce(btrim(s.contact), ''),
           coalesce(btrim(s.address), ''), coalesce(s.description, ''), true, 'mystoreguard',
           CASE WHEN s.is_active IS FALSE THEN coalesce(s.cdatetime, now()) END,
           CASE WHEN s.delete_status <> 'NOT_DELETED' THEN coalesce(s.cdatetime, now()) END,
           coalesce(s.cdatetime, now()), coalesce(s.cdatetime, now()), s.created_by, s.updated_by, s.deleted_by
      FROM mystoreguard.msg_suppliers s
    ON CONFLICT (id) DO NOTHING;
    -- MyStoreGuard's own: the profile picture.
    CREATE TABLE IF NOT EXISTS mystoreguard.msg_supplier_profiles (
        party_id            text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id           text NOT NULL,
        profile_document_id text
    );
    INSERT INTO mystoreguard.msg_supplier_profiles (party_id, tenant_id, profile_document_id)
    SELECT s.id, s.tenant_id, s.profile_document_id FROM mystoreguard.msg_suppliers s WHERE s.profile_document_id IS NOT NULL
    ON CONFLICT (party_id) DO NOTHING;
    ALTER TABLE mystoreguard.msg_purchase_orders DROP CONSTRAINT IF EXISTS fk_msg_purchase_orders_suppliers_tenant_id_org_id_bus_id_suppl;
    ALTER TABLE mystoreguard.msg_suppliers RENAME TO msg_suppliers_legacy;
END $$;

DO $$
DECLARE
    deps record;
    defs text[] := ARRAY[]::text[];
    i integer;
BEGIN
    IF to_regclass('mystoreguard.msg_suppliers_legacy') IS NULL THEN
        RETURN;  -- no MyStoreGuard here
    END IF;
    CREATE TABLE IF NOT EXISTS mystoreguard.msg_supplier_profiles (
        party_id            text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id           text NOT NULL,
        profile_document_id text
    );
    -- Views reading the legacy table (the rename carried them along) read the new view.
    FOR deps IN SELECT DISTINCT v.oid::regclass::text AS name, pg_get_viewdef(v.oid) AS def
                  FROM pg_depend dp JOIN pg_rewrite rw ON rw.oid = dp.objid JOIN pg_class v ON v.oid = rw.ev_class
                 WHERE dp.refobjid = 'mystoreguard.msg_suppliers_legacy'::regclass AND v.oid <> 'mystoreguard.msg_suppliers_legacy'::regclass LOOP
        defs := defs || ARRAY[deps.name, replace(deps.def, 'msg_suppliers_legacy', 'msg_suppliers')];
    END LOOP;
    -- The view: the business's suppliers as MyStoreGuard reads them.
    EXECUTE $v$
    CREATE OR REPLACE VIEW mystoreguard.msg_suppliers AS
    SELECT p.tenant_id, p.id, p.org_id, p.bus_id, p.name AS fullname, nullif(p.email, '') AS email, nullif(p.phone, '') AS contact,
           nullif(p.address_line1, '') AS address,
           to_char(p.cdatetime, 'YYYY-MM-DD') AS cdate, to_char(p.cdatetime, 'HH24:MI:SS') AS ctime, p.cdatetime,
           p.created_by, p.updated_by, p.deleted_by,
           CASE WHEN p.deleted_at IS NULL THEN 'NOT_DELETED' ELSE 'DELETED' END AS delete_status,
           (p.archived_at IS NULL) AS is_active, nullif(p.notes, '') AS description, pr.profile_document_id
      FROM core_platform.cp_parties p
      LEFT JOIN mystoreguard.msg_supplier_profiles pr ON pr.party_id = p.id
     WHERE p.is_supplier
    $v$;
    FOR i IN 1 .. coalesce(array_length(defs, 1), 0) BY 2 LOOP
        EXECUTE format('CREATE OR REPLACE VIEW %s AS %s', defs[i], defs[i + 1]);
    END LOOP;
    -- MyStoreGuard's supplier screens write through the view.
    EXECUTE $t$
    CREATE OR REPLACE FUNCTION mystoreguard.msg_suppliers_write() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    BEGIN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, name, email, phone, address_line1, notes, is_supplier, source_app,
                   archived_at, cdatetime, updated_at, created_by)
            VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id, NEW.org_id, NEW.bus_id, coalesce(nullif(btrim(NEW.fullname), ''), 'Supplier'),
                   coalesce(btrim(NEW.email), ''), coalesce(btrim(NEW.contact), ''), coalesce(btrim(NEW.address), ''), coalesce(NEW.description, ''),
                   true, 'mystoreguard', CASE WHEN NEW.is_active IS FALSE THEN now() END,
                   coalesce(NEW.cdatetime, now()), now(), NEW.created_by)
            ON CONFLICT (id) DO UPDATE SET is_supplier = true, deleted_at = NULL
            RETURNING id INTO NEW.id;
            IF NEW.profile_document_id IS NOT NULL THEN
                INSERT INTO mystoreguard.msg_supplier_profiles (party_id, tenant_id, profile_document_id) VALUES (NEW.id, NEW.tenant_id, NEW.profile_document_id)
                ON CONFLICT (party_id) DO UPDATE SET profile_document_id = EXCLUDED.profile_document_id;
            END IF;
            NEW.delete_status := 'NOT_DELETED';
            RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
            UPDATE core_platform.cp_parties
               SET name = coalesce(nullif(btrim(NEW.fullname), ''), name), email = coalesce(btrim(NEW.email), ''), phone = coalesce(btrim(NEW.contact), ''),
                   address_line1 = coalesce(btrim(NEW.address), ''), notes = coalesce(NEW.description, ''),
                   archived_at = CASE WHEN NEW.is_active IS FALSE THEN coalesce(archived_at, now()) ELSE NULL END,
                   deleted_at = CASE WHEN NEW.delete_status IS DISTINCT FROM 'NOT_DELETED' THEN coalesce(deleted_at, now()) ELSE NULL END,
                   deleted_by = NEW.deleted_by, updated_at = now(), updated_by = NEW.updated_by
             WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            IF NEW.profile_document_id IS DISTINCT FROM OLD.profile_document_id THEN
                INSERT INTO mystoreguard.msg_supplier_profiles (party_id, tenant_id, profile_document_id) VALUES (OLD.id, OLD.tenant_id, NEW.profile_document_id)
                ON CONFLICT (party_id) DO UPDATE SET profile_document_id = EXCLUDED.profile_document_id;
            END IF;
            RETURN NEW;
        ELSE
            -- Removed in MyStoreGuard: refused while an order or a bill names it (as the table's
            -- keys refused it), else it is no longer the business's supplier.
            IF core_platform.cp_party_in_use(OLD.id) THEN
                RAISE foreign_key_violation USING MESSAGE = 'This supplier is used by orders or bills and cannot be deleted';
            END IF;
            UPDATE core_platform.cp_parties
               SET is_supplier = false,
                   deleted_at = CASE WHEN is_customer THEN deleted_at ELSE coalesce(deleted_at, now()) END,
                   deleted_by = coalesce(OLD.deleted_by, deleted_by),
                   updated_at = now()
             WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            RETURN OLD;
        END IF;
    END
    $f$
    $t$;
    DROP TRIGGER IF EXISTS msg_suppliers_write ON mystoreguard.msg_suppliers;
    CREATE TRIGGER msg_suppliers_write INSTEAD OF INSERT OR UPDATE OR DELETE ON mystoreguard.msg_suppliers
        FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_suppliers_write();
    -- Purchase orders keep their supplier.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'msg_purchase_orders_cp_supplier_fk') THEN
        ALTER TABLE mystoreguard.msg_purchase_orders ADD CONSTRAINT msg_purchase_orders_cp_supplier_fk
            FOREIGN KEY (supplier_id) REFERENCES core_platform.cp_parties (id) ON DELETE RESTRICT NOT VALID;
    END IF;
    INSERT INTO core_platform.cp_party_references (table_name, column_name) VALUES
        ('mystoreguard.msg_purchase_orders', 'supplier_id'), ('mystoreguard.msg_purchase_batches', 'supplier_id'),
        ('mystoreguard.msg_purchase_returns', 'supplier_id')
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
        ('mystoreguard.msg_supplier_attachments', 'supplier_id', true), ('mystoreguard.msg_supplier_profiles', 'party_id', true)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = true;
END $$;

-- ===================================================================== Expenses'
DO $$
BEGIN
    IF to_regclass('expenses.exp_bills') IS NULL THEN
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS expenses.exp_vendor_settings (
        party_id    text NOT NULL REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        bus_id      text NOT NULL,
        tenant_id   text NOT NULL,
        category_id text REFERENCES expenses.exp_categories (id) ON DELETE SET NULL,
        PRIMARY KEY (party_id, bus_id)
    );
    ALTER TABLE expenses.exp_bills DROP CONSTRAINT IF EXISTS exp_bills_vendor_id_fkey;
    -- Vendors entered before this become the business's suppliers; the table is kept.
    IF to_regclass('expenses.exp_vendors') IS NOT NULL THEN
        INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, name, email, phone, tax_number, pay_to, notes, is_supplier, source_app,
               archived_at, cdatetime, created_by)
        SELECT v.id, v.tenant_id, coalesce(v.org_id, b.org_id), v.bus_id, v.name, v.email, v.phone, v.tax_number, v.pay_to, v.notes, true, 'expenses',
               v.archived_at, v.cdatetime, v.created_by
          FROM expenses.exp_vendors v JOIN core_platform.cp_businesses b ON b.id = v.bus_id
        ON CONFLICT (id) DO NOTHING;
        INSERT INTO expenses.exp_vendor_settings (party_id, bus_id, tenant_id, category_id)
        SELECT v.id, v.bus_id, v.tenant_id, v.category_id FROM expenses.exp_vendors v WHERE v.category_id IS NOT NULL
        ON CONFLICT DO NOTHING;
        ALTER TABLE expenses.exp_vendors RENAME TO exp_vendors_legacy;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exp_bills_cp_vendor_fk') THEN
        ALTER TABLE expenses.exp_bills ADD CONSTRAINT exp_bills_cp_vendor_fk FOREIGN KEY (vendor_id) REFERENCES core_platform.cp_parties (id) ON DELETE RESTRICT;
    END IF;
    INSERT INTO core_platform.cp_party_references (table_name, column_name) VALUES
        ('expenses.exp_bills', 'vendor_id'), ('expenses.exp_requests', 'vendor_id')
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES ('expenses.exp_vendor_settings', 'party_id', true)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = true;
END $$;

COMMIT;
