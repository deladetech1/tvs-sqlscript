-- =====================================================================
-- Accounting's customers and suppliers are the business's shared records
-- ---------------------------------------------------------------------
-- The same records every other app uses (20261019-29, -30): core_platform.cp_parties,
-- one per person or company a business deals with, is_customer and/or is_supplier.
-- A customer entered at the shop's till or in Invoicing is in Accounting's customer
-- list, and a supplier Accounting adds is the one Expenses pays.
--
--   * accounting.acc_customers and accounting.acc_suppliers become VIEWS of the
--     business's customers / suppliers, with the columns Accounting reads; its
--     screens (EF) and its reports write and read through them. The old tables are
--     kept as acc_customers_legacy / acc_suppliers_legacy.
--   * Accounting's own fields (code, credit limit, payment terms, currency, external
--     reference, source, custom fields) are in acc_customer_settings /
--     acc_supplier_settings, keyed by the party.
--   * Rows already in the old tables are matched to a party of the same business by
--     name AND (email or phone), never by name alone; the rest become parties with
--     their ids kept. Documents of a matched row are pointed at the party.
--   * Invoices, bills, credit notes, supplier credits and payments are registered in
--     cp_party_references, so cp_party_merge moves them and cp_party_in_use sees them.
--   * Deleting through the view: refused while Accounting's own documents name the
--     party; archived when another app still uses it; otherwise it stops being a
--     customer (supplier) of the business.
--
-- The EF model maps both as views from IdentityFromCorePlatform (module 6) on, so no EF
-- migration alters them. A write through either view under
-- SET session_replication_role = replica is silently lost (Postgres skips a view's
-- triggers there, and they cannot be ENABLE ALWAYS): seed cp_parties directly.
--
-- Re-runs every deploy: idempotent. Does nothing where Accounting is not installed or
-- its books are not yet per business (BooksPerBusiness).
-- =====================================================================
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.dependents(p_table regclass)
RETURNS TABLE (name text, def text) LANGUAGE sql AS $f$
    SELECT DISTINCT v.oid::regclass::text, pg_get_viewdef(v.oid)
      FROM pg_depend dp JOIN pg_rewrite rw ON rw.oid = dp.objid JOIN pg_class v ON v.oid = rw.ev_class
     WHERE dp.refobjid = p_table AND v.oid <> p_table
$f$;

CREATE TABLE IF NOT EXISTS pg_temp.rebuild (name text, def text);

-- ===================================================================== Accounting's own fields
DO $$
BEGIN
    IF to_regclass('accounting.acc_org_settings') IS NULL OR to_regclass('core_platform.cp_parties') IS NULL THEN
        RAISE NOTICE 'No Accounting books here (or no shared parties); nothing to do';
        RETURN;
    END IF;
    CREATE TABLE IF NOT EXISTS accounting.acc_customer_settings (
        party_id           text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id          text NOT NULL,
        bus_id             text NOT NULL CHECK (btrim(bus_id) <> ''),
        code               text NOT NULL DEFAULT '',
        credit_limit       numeric(18,2) NOT NULL DEFAULT 0,
        payment_terms_days integer,
        currency           text,
        external_reference text,
        source             text NOT NULL DEFAULT 'MANUAL',
        custom_fields_json jsonb NOT NULL DEFAULT '{}'::jsonb,
        created_at         timestamptz NOT NULL DEFAULT now(),
        updated_at         timestamptz NOT NULL DEFAULT now(),
        created_by_id      text,
        updated_by_id      text
    );
    CREATE TABLE IF NOT EXISTS accounting.acc_supplier_settings (
        party_id           text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id          text NOT NULL,
        bus_id             text NOT NULL CHECK (btrim(bus_id) <> ''),
        code               text NOT NULL DEFAULT '',
        credit_limit       numeric(18,2) NOT NULL DEFAULT 0,
        payment_terms_days integer,
        currency           text,
        external_reference text,
        source             text NOT NULL DEFAULT 'MANUAL',
        custom_fields_json jsonb NOT NULL DEFAULT '{}'::jsonb,
        created_at         timestamptz NOT NULL DEFAULT now(),
        updated_at         timestamptz NOT NULL DEFAULT now(),
        created_by_id      text,
        updated_by_id      text
    );
    -- A code (C-0001, S-0001) names one record in a business's books.
    CREATE UNIQUE INDEX IF NOT EXISTS ux_acc_customer_settings_bus_code ON accounting.acc_customer_settings (tenant_id, bus_id, code) WHERE code <> '';
    CREATE UNIQUE INDEX IF NOT EXISTS ux_acc_supplier_settings_bus_code ON accounting.acc_supplier_settings (tenant_id, bus_id, code) WHERE code <> '';
END $$;

-- ===================================================================== the old tables, in
-- p_kind: 'customer' | 'supplier'. Runs only while the old table is still a table.
CREATE OR REPLACE FUNCTION pg_temp.acc_parties_in(p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE
    tbl     regclass := to_regclass(format('accounting.acc_%ss', p_kind));
    flag    text := format('is_%s', p_kind);
    r       record;
    target  text;
    c       record;
BEGIN
    IF tbl IS NULL OR (SELECT relkind FROM pg_class WHERE oid = tbl) <> 'r' THEN
        RETURN;  -- already a view, or no Accounting here
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'accounting' AND table_name = format('acc_%ss', p_kind) AND column_name = 'bus_id') THEN
        RAISE NOTICE 'acc_%ss has no bus_id yet (BooksPerBusiness has not run); left as it is', p_kind;
        RETURN;
    END IF;
    FOR r IN EXECUTE format('SELECT * FROM %s ORDER BY created_at, id', tbl) LOOP
        -- The same business's record of the same name AND the same email or phone; never name alone.
        SELECT p.id INTO target
          FROM core_platform.cp_parties p
         WHERE p.tenant_id = r.tenant_id AND p.bus_id = r.bus_id AND p.deleted_at IS NULL AND p.id <> r.id
           AND lower(btrim(p.name)) = lower(btrim(r.name))
           AND ((btrim(coalesce(r.email, '')) <> '' AND lower(btrim(p.email)) = lower(btrim(r.email)))
             OR (btrim(coalesce(r.phone, '')) <> '' AND regexp_replace(p.phone, '\D', '', 'g') = regexp_replace(r.phone, '\D', '', 'g')))
         ORDER BY p.cdatetime, p.id LIMIT 1;
        IF target IS NULL THEN
            target := r.id;
            EXECUTE format($i$
            INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, email, phone, city, tax_number, currency,
                   payment_terms_days, %I, source_app, archived_at, cdatetime, updated_at, created_by, updated_by)
            VALUES ($1, $2, $3, $4, 'company', coalesce(nullif(btrim($5), ''), initcap($17)), coalesce(btrim($6), ''), coalesce(btrim($7), ''),
                   coalesce(btrim($8), ''), coalesce(btrim($9), ''),
                   CASE WHEN $10 ~ '^[A-Za-z]{3}$' THEN upper($10) END,
                   CASE WHEN $11 BETWEEN 0 AND 3650 THEN $11 END, true, 'accounting',
                   CASE WHEN $12 = 'INACTIVE' THEN $14 END, $13, $14, $15, $16)
            ON CONFLICT (id) DO UPDATE SET %I = true
            $i$, flag, flag)
            USING r.id, r.tenant_id, r.org_id, r.bus_id, r.name, r.email, r.phone, r.city, r.tin, r.currency,
                  r.payment_terms_days, r.status, r.created_at, r.updated_at, r.created_by_id, r.updated_by_id, p_kind;
        ELSE
            -- What the shared record lacks, it takes from Accounting's.
            EXECUTE format($u$
            UPDATE core_platform.cp_parties SET %I = true, updated_at = now(),
                   email = CASE WHEN email = '' THEN coalesce(btrim($2), '') ELSE email END,
                   phone = CASE WHEN phone = '' THEN coalesce(btrim($3), '') ELSE phone END,
                   city = CASE WHEN city = '' THEN coalesce(btrim($4), '') ELSE city END,
                   tax_number = CASE WHEN tax_number = '' THEN coalesce(btrim($5), '') ELSE tax_number END
             WHERE id = $1
            $u$, flag) USING target, r.email, r.phone, r.city, r.tin;
            -- Accounting's documents follow the record they now are.
            IF p_kind = 'customer' THEN
                UPDATE accounting.acc_sales_invoices SET customer_id = target WHERE customer_id = r.id AND tenant_id = r.tenant_id;
                UPDATE accounting.acc_credit_notes SET party_id = target WHERE party_id = r.id AND tenant_id = r.tenant_id;
            ELSE
                UPDATE accounting.acc_purchase_bills SET supplier_id = target WHERE supplier_id = r.id AND tenant_id = r.tenant_id;
                UPDATE accounting.acc_supplier_credits SET party_id = target WHERE party_id = r.id AND tenant_id = r.tenant_id;
            END IF;
            UPDATE accounting.acc_payments SET party_id = target WHERE party_id = r.id AND tenant_id = r.tenant_id;
        END IF;
        EXECUTE format($s$
        INSERT INTO accounting.acc_%s_settings (party_id, tenant_id, bus_id, code, credit_limit, payment_terms_days, currency, external_reference,
               source, custom_fields_json, created_at, updated_at, created_by_id, updated_by_id)
        VALUES ($1, $2, $3, coalesce($4, ''), coalesce($5, 0), $6, $7, $8, coalesce($9, 'MANUAL'), coalesce($10, '{}'::jsonb), $11, $12, $13, $14)
        ON CONFLICT (party_id) DO NOTHING
        $s$, p_kind)
        USING target, r.tenant_id, r.bus_id, r.code, r.credit_limit, r.payment_terms_days, r.currency, r.external_reference,
              r.source, r.custom_fields_json, r.created_at, r.updated_at, r.created_by_id, r.updated_by_id;
    END LOOP;
    FOR c IN SELECT conrelid::regclass AS t, conname FROM pg_constraint WHERE confrelid = tbl LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.t, c.conname);
    END LOOP;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents(tbl) d;
    EXECUTE format('ALTER TABLE %s RENAME TO acc_%ss_legacy', tbl, p_kind);
END
$f$;

DO $$
BEGIN
    IF to_regclass('accounting.acc_customer_settings') IS NULL THEN
        RETURN;
    END IF;
    PERFORM pg_temp.acc_parties_in('customer');
    PERFORM pg_temp.acc_parties_in('supplier');
END $$;

-- ===================================================================== the views
DO $$
DECLARE
    k text;
    r record;
BEGIN
    FOREACH k IN ARRAY ARRAY['customer', 'supplier'] LOOP
        IF to_regclass(format('accounting.acc_%ss_legacy', k)) IS NULL OR to_regclass(format('accounting.acc_%s_settings', k)) IS NULL THEN
            CONTINUE;  -- not moved (no Accounting, or books not yet per business)
        END IF;
        -- Columns only ever appended: CREATE OR REPLACE VIEW cannot reorder them.
        EXECUTE format($v$
        CREATE OR REPLACE VIEW accounting.acc_%1$ss AS
        SELECT p.id, p.tenant_id, p.org_id, p.bus_id, coalesce(st.code, '') AS code, p.name, p.email, p.phone, p.city,
               nullif(p.tax_number, '') AS tin, coalesce(st.payment_terms_days, p.payment_terms_days, 30) AS payment_terms_days,
               coalesce(st.credit_limit, 0)::numeric(18,2) AS credit_limit,
               CASE WHEN p.archived_at IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END AS status,
               st.external_reference, coalesce(st.source, 'MANUAL') AS source,
               coalesce(st.currency, btrim(p.currency::text), os.base_currency, 'GHS') AS currency,
               coalesce(st.custom_fields_json, '{}'::jsonb) AS custom_fields_json,
               p.cdatetime AS created_at, p.updated_at, p.created_by AS created_by_id, p.updated_by AS updated_by_id,
               p.source_app
          FROM core_platform.cp_parties p
          LEFT JOIN accounting.acc_%1$s_settings st ON st.party_id = p.id
          LEFT JOIN accounting.acc_org_settings os ON os.tenant_id = p.tenant_id AND os.org_id = p.org_id AND os.bus_id = p.bus_id
         WHERE p.is_%1$s AND p.deleted_at IS NULL
        $v$, k);

        EXECUTE format($t$
        CREATE OR REPLACE FUNCTION accounting.acc_%1$ss_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        DECLARE
            used boolean;
        BEGIN
            IF TG_OP = 'DELETE' THEN
                -- Accounting's own documents name it: refused, as the books must keep their party.
                IF '%1$s' = 'customer' THEN
                    used := EXISTS (SELECT 1 FROM accounting.acc_sales_invoices WHERE customer_id = OLD.id)
                         OR EXISTS (SELECT 1 FROM accounting.acc_credit_notes WHERE party_id = OLD.id)
                         OR EXISTS (SELECT 1 FROM accounting.acc_payments WHERE party_id = OLD.id);
                ELSE
                    used := EXISTS (SELECT 1 FROM accounting.acc_purchase_bills WHERE supplier_id = OLD.id)
                         OR EXISTS (SELECT 1 FROM accounting.acc_supplier_credits WHERE party_id = OLD.id)
                         OR EXISTS (SELECT 1 FROM accounting.acc_payments WHERE party_id = OLD.id);
                END IF;
                IF used THEN
                    RAISE foreign_key_violation USING MESSAGE = 'This %1$s is used in the books and cannot be deleted; make it inactive instead';
                END IF;
                IF core_platform.cp_party_in_use(OLD.id) THEN
                    -- Another app's documents name it: archived, never removed.
                    UPDATE core_platform.cp_parties SET archived_at = coalesce(archived_at, now()), updated_at = now()
                     WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                    RETURN OLD;
                END IF;
                DELETE FROM accounting.acc_%1$s_settings WHERE party_id = OLD.id;
                UPDATE core_platform.cp_parties
                   SET is_%1$s = false,
                       deleted_at = CASE WHEN is_%2$s THEN deleted_at ELSE coalesce(deleted_at, now()) END,
                       updated_at = now()
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                RETURN OLD;
            END IF;

            IF TG_OP = 'INSERT' THEN
                INSERT INTO core_platform.cp_parties AS cp (id, tenant_id, org_id, bus_id, kind, name, email, phone, city, tax_number, currency,
                       payment_terms_days, is_%1$s, source_app, archived_at, cdatetime, updated_at, created_by, updated_by)
                VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id,
                       coalesce(NEW.org_id, (SELECT b.org_id FROM core_platform.cp_businesses b WHERE b.id = NEW.bus_id AND b.tenant_id = NEW.tenant_id)),
                       NEW.bus_id, 'company', btrim(NEW.name), coalesce(btrim(NEW.email), ''), coalesce(btrim(NEW.phone), ''),
                       coalesce(btrim(NEW.city), ''), coalesce(btrim(NEW.tin), ''),
                       CASE WHEN NEW.currency ~ '^[A-Za-z]{3}$' THEN upper(NEW.currency) END,
                       CASE WHEN NEW.payment_terms_days BETWEEN 0 AND 3650 THEN NEW.payment_terms_days END,
                       true, 'accounting', CASE WHEN NEW.status = 'INACTIVE' THEN now() END,
                       coalesce(NEW.created_at, now()), coalesce(NEW.updated_at, now()), NEW.created_by_id, NEW.updated_by_id)
                -- An existing record of this business (say a supplier) becomes a %1$s too; another business's never.
                ON CONFLICT (id) DO UPDATE SET is_%1$s = true, deleted_at = NULL, updated_at = now()
                 WHERE cp.tenant_id = EXCLUDED.tenant_id AND cp.bus_id = EXCLUDED.bus_id
                RETURNING cp.id, cp.source_app INTO NEW.id, NEW.source_app;
                IF NEW.id IS NULL THEN
                    RAISE unique_violation USING MESSAGE = 'That id belongs to another business''s record';
                END IF;
            ELSE
                UPDATE core_platform.cp_parties
                   SET name = coalesce(nullif(btrim(NEW.name), ''), name), email = coalesce(btrim(NEW.email), ''),
                       phone = coalesce(btrim(NEW.phone), ''), city = coalesce(btrim(NEW.city), ''), tax_number = coalesce(btrim(NEW.tin), ''),
                       archived_at = CASE WHEN NEW.status = 'INACTIVE' THEN coalesce(archived_at, now()) ELSE NULL END,
                       updated_at = now(), updated_by = coalesce(NEW.updated_by_id, updated_by)
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                NEW.source_app := OLD.source_app;
            END IF;
            INSERT INTO accounting.acc_%1$s_settings (party_id, tenant_id, bus_id, code, credit_limit, payment_terms_days, currency,
                   external_reference, source, custom_fields_json, created_at, updated_at, created_by_id, updated_by_id)
            VALUES (NEW.id, NEW.tenant_id, NEW.bus_id, coalesce(NEW.code, ''), coalesce(NEW.credit_limit, 0), NEW.payment_terms_days,
                   nullif(upper(btrim(coalesce(NEW.currency, ''))), ''), NEW.external_reference, coalesce(NEW.source, 'MANUAL'),
                   coalesce(NEW.custom_fields_json, '{}'::jsonb), coalesce(NEW.created_at, now()), coalesce(NEW.updated_at, now()),
                   NEW.created_by_id, NEW.updated_by_id)
            ON CONFLICT (party_id) DO UPDATE SET
                   code = CASE WHEN EXCLUDED.code = '' THEN accounting.acc_%1$s_settings.code ELSE EXCLUDED.code END,
                   credit_limit = EXCLUDED.credit_limit, payment_terms_days = EXCLUDED.payment_terms_days, currency = EXCLUDED.currency,
                   external_reference = EXCLUDED.external_reference, source = EXCLUDED.source, custom_fields_json = EXCLUDED.custom_fields_json,
                   updated_at = EXCLUDED.updated_at, updated_by_id = EXCLUDED.updated_by_id;
            RETURN NEW;
        END
        $f$
        $t$, k, CASE WHEN k = 'customer' THEN 'supplier' ELSE 'customer' END);

        EXECUTE format('DROP TRIGGER IF EXISTS acc_%1$ss_write ON accounting.acc_%1$ss', k);
        EXECUTE format('CREATE TRIGGER acc_%1$ss_write INSTEAD OF INSERT OR UPDATE OR DELETE ON accounting.acc_%1$ss
                        FOR EACH ROW EXECUTE FUNCTION accounting.acc_%1$ss_write()', k);
    END LOOP;

    -- Views that read the old tables read the new ones.
    FOR r IN SELECT name, def FROM pg_temp.rebuild LOOP
        EXECUTE format('CREATE OR REPLACE VIEW %s AS %s', r.name,
                       replace(replace(r.def, 'acc_customers_legacy', 'acc_customers'), 'acc_suppliers_legacy', 'acc_suppliers'));
    END LOOP;
END $$;

-- ===================================================================== what points at a party
DO $$
DECLARE k record;
BEGIN
    IF to_regclass('accounting.acc_customer_settings') IS NULL THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
        -- Uses: a party any of these name is never deleted.
        ('accounting.acc_sales_invoices', 'customer_id', false), ('accounting.acc_credit_notes', 'party_id', false),
        ('accounting.acc_purchase_bills', 'supplier_id', false), ('accounting.acc_supplier_credits', 'party_id', false),
        ('accounting.acc_payments', 'party_id', false),
        -- Accounting's own fields: they move with a merge (the kept record's stay).
        ('accounting.acc_customer_settings', 'party_id', true), ('accounting.acc_supplier_settings', 'party_id', true)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

    -- The documents point at Core Platform. NOT VALID: rows made before are not checked, new ones are.
    -- DEFERRABLE INITIALLY DEFERRED: a save may write a document and its new party in either order.
    FOR k IN SELECT * FROM (VALUES
            ('accounting.acc_sales_invoices', 'customer_id', 'acc_sales_invoices_customer_party_fk'),
            ('accounting.acc_credit_notes', 'party_id', 'acc_credit_notes_party_fk'),
            ('accounting.acc_purchase_bills', 'supplier_id', 'acc_purchase_bills_supplier_party_fk'),
            ('accounting.acc_supplier_credits', 'party_id', 'acc_supplier_credits_party_fk'),
            ('accounting.acc_payments', 'party_id', 'acc_payments_party_fk')) AS v(tbl, col, con) LOOP
        IF to_regclass(k.tbl) IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass(k.tbl) AND conname = k.con) THEN
            EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES core_platform.cp_parties (id) ON DELETE RESTRICT
                            DEFERRABLE INITIALLY DEFERRED NOT VALID', k.tbl, k.con, k.col);
        END IF;
    END LOOP;
END $$;

-- ===================================================================== invariants
DO $$
DECLARE k text;
BEGIN
    IF to_regclass('accounting.acc_customer_settings') IS NULL THEN
        RETURN;
    END IF;
    FOREACH k IN ARRAY ARRAY['customer', 'supplier'] LOOP
        IF to_regclass(format('accounting.acc_%ss_legacy', k)) IS NOT NULL
           AND (SELECT relkind FROM pg_class WHERE oid = to_regclass(format('accounting.acc_%ss', k))) IS DISTINCT FROM 'v' THEN
            RAISE EXCEPTION 'accounting.acc_%ss should be a view of core_platform.cp_parties', k;
        END IF;
        IF to_regclass(format('accounting.acc_%ss_legacy', k)) IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = to_regclass(format('accounting.acc_%ss', k)) AND tgname = format('acc_%ss_write', k)) THEN
            RAISE EXCEPTION 'accounting.acc_%ss has no write trigger', k;
        END IF;
    END LOOP;
    -- Every document Accounting writes from here on names a party of Core Platform (the keys above check
    -- new rows); one written before that names none is reported, not fatal: it still reads, without a name.
    IF EXISTS (SELECT 1 FROM accounting.acc_sales_invoices i
                WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_parties p WHERE p.id = i.customer_id))
       OR EXISTS (SELECT 1 FROM accounting.acc_purchase_bills b
                   WHERE NOT EXISTS (SELECT 1 FROM core_platform.cp_parties p WHERE p.id = b.supplier_id)) THEN
        RAISE WARNING 'Accounting has invoices or bills naming no shared party (written before 20261019-37)';
    END IF;
END $$;

COMMIT;
