-- =====================================================================
-- Customers, kept once per business in Core Platform and used by every app
-- ---------------------------------------------------------------------
-- The same records as the suppliers (20261019-29): core_platform.cp_parties,
-- one per person or company a business deals with, is_customer and/or
-- is_supplier. A customer added at the shop's till is the customer Invoicing
-- bills, and a new phone number entered in either app is the one both use.
--
--   * MyStoreGuard's msg_customers table becomes a VIEW of the business's
--     customers; its screens write through it. Ids are kept, so sales,
--     invoices, loyalty and the rest still point at the same customer. Its own
--     fields (the location a customer was added at, the profile picture) are in
--     msg_customer_profiles. The old table is kept as msg_customers_legacy.
--   * Invoicing's inv_customers table becomes a VIEW too: its customers and
--     suppliers (role customer / supplier / both), with Invoicing's own fields
--     (portal link, reminders, autopay, template, e-invoicing ids, where it was
--     imported from) in inv_customer_settings. Kept as inv_customers_legacy.
--   * A customer Invoicing had imported from MyStoreGuard is now that same
--     customer: it is merged into it (cp_party_merge), its invoices, payments,
--     contracts and saved cards moving with it. Matched only by the import's
--     own link (source_app, source_id), never by name.
--   * Deleting a customer an app still uses (a sale, an invoice) is refused,
--     as the old tables' keys refused it; Invoicing archives it instead.
--
-- Loandrift's clients (per location, with KYC) and the CRM's contacts (people
-- at a customer) are not moved: they will point at these records later.
--
-- Earlier migrations that alter these tables skip them once they are views.
-- The EF model still describes msg_customers as a table, as it does msg_taxes:
-- a future EF migration must not alter it. A write through either view under
-- SET session_replication_role = replica is silently lost: seed cp_parties.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

ALTER TABLE core_platform.cp_parties ADD COLUMN IF NOT EXISTS gender text;
ALTER TABLE core_platform.cp_parties ADD COLUMN IF NOT EXISTS date_of_birth date;

-- Views that read a table about to be renamed, captured to be rebuilt on the view that
-- replaces it.
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
    IF to_regclass('mystoreguard.msg_customers') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'mystoreguard.msg_customers'::regclass) <> 'r' THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, email, phone, address_line1, notes, gender, date_of_birth,
           is_customer, source_app, archived_at, deleted_at, cdatetime, updated_at, created_by, updated_by, deleted_by)
    SELECT m.id, m.tenant_id, m.org_id, m.bus_id, 'person', coalesce(nullif(btrim(m.fullname), ''), 'Customer'), coalesce(btrim(m.email), ''),
           coalesce(btrim(m.contact), ''), coalesce(btrim(m.address), ''), coalesce(m.description, ''), m.gender, m.date_of_birth,
           true, 'mystoreguard',
           CASE WHEN m.is_active IS FALSE THEN coalesce(m.cdatetime, now()) END,
           CASE WHEN m.delete_status <> 'NOT_DELETED' THEN coalesce(m.cdatetime, now()) END,
           coalesce(m.cdatetime, now()), coalesce(m.cdatetime, now()), m.created_by, m.updated_by, m.deleted_by
      FROM mystoreguard.msg_customers m
    ON CONFLICT (id) DO UPDATE SET is_customer = true;
    CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_profiles (
        party_id            text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id           text NOT NULL,
        loc_id              text,
        profile_document_id text
    );
    INSERT INTO mystoreguard.msg_customer_profiles (party_id, tenant_id, loc_id, profile_document_id)
    SELECT m.id, m.tenant_id, m.loc_id, m.profile_document_id FROM mystoreguard.msg_customers m
     WHERE m.loc_id IS NOT NULL OR m.profile_document_id IS NOT NULL
    ON CONFLICT (party_id) DO NOTHING;
    -- The keys pointing at the table go; the same columns point at Core Platform below.
    FOR c IN SELECT conrelid::regclass AS tbl, conname FROM pg_constraint WHERE confrelid = 'mystoreguard.msg_customers'::regclass LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.tbl, c.conname);
    END LOOP;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents('mystoreguard.msg_customers') d;
    ALTER TABLE mystoreguard.msg_customers RENAME TO msg_customers_legacy;
END $$;

-- ===================================================================== Invoicing's, in
DO $$
DECLARE c record;
BEGIN
    IF to_regclass('invoicing.inv_customers') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'invoicing.inv_customers'::regclass) <> 'r' THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, contact_name, email, phone, tax_number, address_line1, address_line2,
           city, region, postal_code, country, currency, payment_terms_days, notes, is_customer, is_supplier, source_app, archived_at,
           cdatetime, updated_at, created_by, updated_by)
    SELECT i.id, i.tenant_id, coalesce(i.org_id, b.org_id), i.bus_id, CASE WHEN i.kind = 'person' THEN 'person' ELSE 'company' END, i.name, i.contact_name,
           i.email, i.phone, i.tax_number, i.address_line1, i.address_line2, i.city, i.region, i.postal_code, i.country, i.currency, i.payment_terms_days,
           i.notes, i.role IN ('customer', 'both'), i.role IN ('supplier', 'both'), 'invoicing', i.archived_at, i.cdatetime, i.updated_at, i.created_by, i.updated_by
      FROM invoicing.inv_customers i JOIN core_platform.cp_businesses b ON b.id = i.bus_id
    ON CONFLICT (id) DO NOTHING;
    CREATE TABLE IF NOT EXISTS invoicing.inv_customer_settings (
        party_id       text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
        tenant_id      text NOT NULL,
        bus_id         text NOT NULL,
        cc_emails      text[] NOT NULL DEFAULT '{}',
        website        text NOT NULL DEFAULT '',
        locale         text,
        groups         text[] NOT NULL DEFAULT '{}',
        source_app     text,
        source_id      text,
        source_hash    text,
        source_removed boolean NOT NULL DEFAULT false,
        edited_locally boolean NOT NULL DEFAULT false,
        imported_at    timestamptz,
        no_reminders   boolean NOT NULL DEFAULT false,
        portal_token   text,
        no_late_fees   boolean NOT NULL DEFAULT false,
        autopay        boolean NOT NULL DEFAULT false,
        account_ref    text NOT NULL DEFAULT '',
        einvoice_id    text NOT NULL DEFAULT '',
        state_code     text NOT NULL DEFAULT '',
        template       text NOT NULL DEFAULT ''
    );
    INSERT INTO invoicing.inv_customer_settings (party_id, tenant_id, bus_id, cc_emails, website, locale, groups, source_app, source_id, source_hash,
           source_removed, edited_locally, imported_at, no_reminders, portal_token, no_late_fees, autopay, account_ref, einvoice_id, state_code, template)
    SELECT i.id, i.tenant_id, i.bus_id, i.cc_emails, i.website, i.locale, i.groups, i.source_app, i.source_id, i.source_hash, i.source_removed,
           i.edited_locally, i.imported_at, i.no_reminders, i.portal_token, i.no_late_fees, i.autopay, i.account_ref, i.einvoice_id, i.state_code, i.template
      FROM invoicing.inv_customers i
    ON CONFLICT (party_id) DO NOTHING;
    FOR c IN SELECT conrelid::regclass AS tbl, conname FROM pg_constraint WHERE confrelid = 'invoicing.inv_customers'::regclass LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.tbl, c.conname);
    END LOOP;
    INSERT INTO pg_temp.rebuild SELECT d.name, d.def FROM pg_temp.dependents('invoicing.inv_customers') d;
    ALTER TABLE invoicing.inv_customers RENAME TO inv_customers_legacy;
END $$;

DO $$
BEGIN
    IF to_regclass('invoicing.inv_customer_settings') IS NOT NULL THEN
        CREATE UNIQUE INDEX IF NOT EXISTS inv_customer_settings_source_uq ON invoicing.inv_customer_settings (bus_id, source_app, source_id) WHERE source_app IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS inv_customer_settings_portal_uq ON invoicing.inv_customer_settings (portal_token) WHERE portal_token IS NOT NULL;
    END IF;
END $$;

-- ===================================================================== what points at a customer
DO $$
BEGIN
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
        -- Uses: a customer with any of these is not deleted.
        ('mystoreguard.msg_sales', 'customer_id', false), ('mystoreguard.msg_invoices', 'customer_id', false),
        ('mystoreguard.msg_affiliate_referrals', 'customer_id', false), ('mystoreguard.msg_promo_code_usage', 'customer_id', false),
        ('mystoreguard.msg_tasks', 'customer_id', false), ('mystoreguard.msg_gift_cards', 'purchased_by_customer_id', false),
        ('invoicing.inv_invoices', 'customer_id', false), ('invoicing.inv_payments', 'customer_id', false),
        ('invoicing.inv_recurring', 'customer_id', false), ('invoicing.inv_contracts', 'customer_id', false),
        ('expenses.exp_expenses', 'billable_customer_id', false),
        -- Extensions: they move with a merge.
        ('mystoreguard.msg_customer_profiles', 'party_id', true), ('mystoreguard.msg_guarantors', 'customer_id', true),
        ('mystoreguard.msg_credit_scores', 'customer_id', true), ('mystoreguard.msg_appointments', 'customer_id', true),
        ('mystoreguard.msg_auction_bids', 'customer_id', true), ('mystoreguard.msg_auction_messages', 'customer_id', true),
        ('mystoreguard.msg_auction_reactions', 'customer_id', true), ('mystoreguard.msg_auction_watchers', 'customer_id', true),
        ('mystoreguard.msg_auctions', 'winner_customer_id', true), ('mystoreguard.msg_coin_ledger', 'customer_id', true),
        ('mystoreguard.msg_customer_attachments', 'customer_id', true), ('mystoreguard.msg_customer_contacts', 'customer_id', true),
        ('mystoreguard.msg_customer_points', 'customer_id', true), ('mystoreguard.msg_customer_segment_members', 'customer_id', true),
        ('mystoreguard.msg_customer_segment_rewards', 'customer_id', true), ('mystoreguard.msg_customer_store_credit', 'customer_id', true),
        ('mystoreguard.msg_customer_tier', 'customer_id', true), ('mystoreguard.msg_estimates', 'customer_id', true),
        ('mystoreguard.msg_installment_requests', 'customer_id', true), ('mystoreguard.msg_loyalty_transactions', 'customer_id', true),
        ('mystoreguard.msg_redemption_verifications', 'customer_id', true), ('mystoreguard.msg_returns', 'customer_id', true),
        ('mystoreguard.msg_segment_campaign_recipients', 'customer_id', true), ('mystoreguard.msg_store_credit_transactions', 'customer_id', true),
        ('mystoreguard.msg_storefront_login_codes', 'customer_id', true), ('mystoreguard.msg_storefront_sessions', 'customer_id', true),
        ('invoicing.inv_customer_settings', 'party_id', true), ('invoicing.inv_payment_methods', 'customer_id', true),
        ('invoicing.inv_tax_exemptions', 'customer_id', true), ('projects.prj_projects', 'inv_customer_id', true)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;
END $$;

-- Invoicing's copies of MyStoreGuard's customers and suppliers are those very records.
DO $$
DECLARE c record;
BEGIN
    IF to_regclass('invoicing.inv_customer_settings') IS NULL THEN
        RETURN;
    END IF;
    FOR c IN SELECT st.party_id AS copy_id, st.source_id AS original_id
               FROM invoicing.inv_customer_settings st
               JOIN core_platform.cp_parties cp ON cp.id = st.party_id AND cp.deleted_at IS NULL
               JOIN core_platform.cp_parties op ON op.id = st.source_id AND op.bus_id = cp.bus_id AND op.tenant_id = cp.tenant_id AND op.deleted_at IS NULL
              WHERE st.source_app = 'mystoreguard' AND st.source_id IS NOT NULL AND st.source_id <> st.party_id LOOP
        PERFORM core_platform.cp_party_merge(c.original_id, c.copy_id, 'migration:20261019-30');
    END LOOP;
END $$;

-- ===================================================================== the views
DO $$
DECLARE r record;
BEGIN
    IF to_regclass('mystoreguard.msg_customers_legacy') IS NOT NULL THEN
        CREATE TABLE IF NOT EXISTS mystoreguard.msg_customer_profiles (
            party_id            text PRIMARY KEY REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
            tenant_id           text NOT NULL,
            loc_id              text,
            profile_document_id text
        );
        EXECUTE $v$
        CREATE OR REPLACE VIEW mystoreguard.msg_customers AS
        SELECT p.tenant_id, p.id, p.org_id, p.bus_id, pr.loc_id, p.name AS fullname, nullif(p.email, '') AS email, nullif(p.phone, '') AS contact,
               nullif(p.address_line1, '') AS address,
               to_char(p.cdatetime, 'YYYY-MM-DD') AS cdate, to_char(p.cdatetime, 'HH24:MI:SS') AS ctime, p.cdatetime,
               p.created_by, p.updated_by, p.deleted_by,
               CASE WHEN p.deleted_at IS NULL THEN 'NOT_DELETED' ELSE 'DELETED' END AS delete_status,
               (p.archived_at IS NULL) AS is_active, nullif(p.notes, '') AS description, pr.profile_document_id, p.gender, p.date_of_birth
          FROM core_platform.cp_parties p
          LEFT JOIN mystoreguard.msg_customer_profiles pr ON pr.party_id = p.id
         -- A borrower Loandrift alone knows is not the shop's (merged with a shop customer, the
         -- record is the shop's, source_app mystoreguard).
         WHERE p.is_customer AND p.source_app <> 'loandrift'
        $v$;
        EXECUTE $t$
        CREATE OR REPLACE FUNCTION mystoreguard.msg_customers_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        BEGIN
            IF TG_OP = 'INSERT' THEN
                INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, email, phone, address_line1, notes, gender, date_of_birth,
                       is_customer, source_app, archived_at, cdatetime, updated_at, created_by)
                VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id, NEW.org_id, NEW.bus_id, 'person',
                       coalesce(nullif(btrim(NEW.fullname), ''), 'Customer'), coalesce(btrim(NEW.email), ''), coalesce(btrim(NEW.contact), ''),
                       coalesce(btrim(NEW.address), ''), coalesce(NEW.description, ''), NEW.gender, NEW.date_of_birth, true, 'mystoreguard',
                       CASE WHEN NEW.is_active IS FALSE THEN now() END, coalesce(NEW.cdatetime, now()), now(), NEW.created_by)
                ON CONFLICT (id) DO UPDATE SET is_customer = true, deleted_at = NULL
                RETURNING id INTO NEW.id;
                IF NEW.loc_id IS NOT NULL OR NEW.profile_document_id IS NOT NULL THEN
                    INSERT INTO mystoreguard.msg_customer_profiles (party_id, tenant_id, loc_id, profile_document_id)
                    VALUES (NEW.id, NEW.tenant_id, NEW.loc_id, NEW.profile_document_id)
                    ON CONFLICT (party_id) DO UPDATE SET loc_id = EXCLUDED.loc_id, profile_document_id = EXCLUDED.profile_document_id;
                END IF;
                NEW.delete_status := 'NOT_DELETED';
                NEW.is_active := coalesce(NEW.is_active, true);
                RETURN NEW;
            ELSIF TG_OP = 'UPDATE' THEN
                UPDATE core_platform.cp_parties
                   SET name = coalesce(nullif(btrim(NEW.fullname), ''), name), email = coalesce(btrim(NEW.email), ''), phone = coalesce(btrim(NEW.contact), ''),
                       address_line1 = coalesce(btrim(NEW.address), ''), notes = coalesce(NEW.description, ''), gender = NEW.gender,
                       date_of_birth = NEW.date_of_birth,
                       archived_at = CASE WHEN NEW.is_active IS FALSE THEN coalesce(archived_at, now()) ELSE NULL END,
                       deleted_at = CASE WHEN NEW.delete_status IS DISTINCT FROM 'NOT_DELETED' THEN coalesce(deleted_at, now()) ELSE NULL END,
                       deleted_by = NEW.deleted_by, updated_at = now(), updated_by = NEW.updated_by
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                IF NEW.loc_id IS DISTINCT FROM OLD.loc_id OR NEW.profile_document_id IS DISTINCT FROM OLD.profile_document_id THEN
                    INSERT INTO mystoreguard.msg_customer_profiles (party_id, tenant_id, loc_id, profile_document_id)
                    VALUES (OLD.id, OLD.tenant_id, NEW.loc_id, NEW.profile_document_id)
                    ON CONFLICT (party_id) DO UPDATE SET loc_id = EXCLUDED.loc_id, profile_document_id = EXCLUDED.profile_document_id;
                END IF;
                RETURN NEW;
            ELSE
                -- As the table did: guarantors and credit scores go with the customer; one with a
                -- sale, an invoice or another app's record is not deleted.
                DELETE FROM mystoreguard.msg_guarantors WHERE customer_id = OLD.id AND tenant_id = OLD.tenant_id;
                DELETE FROM mystoreguard.msg_credit_scores WHERE customer_id = OLD.id AND tenant_id = OLD.tenant_id;
                IF core_platform.cp_party_in_use(OLD.id) THEN
                    RAISE foreign_key_violation USING MESSAGE = 'This customer has sales or invoices and cannot be deleted';
                END IF;
                UPDATE core_platform.cp_parties
                   SET is_customer = false, deleted_at = CASE WHEN is_supplier THEN deleted_at ELSE coalesce(deleted_at, now()) END,
                       deleted_by = coalesce(OLD.deleted_by, deleted_by), updated_at = now()
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                RETURN OLD;
            END IF;
        END
        $f$
        $t$;
        DROP TRIGGER IF EXISTS msg_customers_write ON mystoreguard.msg_customers;
        CREATE TRIGGER msg_customers_write INSTEAD OF INSERT OR UPDATE OR DELETE ON mystoreguard.msg_customers
            FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_customers_write();
    END IF;

    IF to_regclass('invoicing.inv_customers_legacy') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW invoicing.inv_customers AS
        SELECT p.id, p.tenant_id, p.org_id, p.bus_id, CASE WHEN p.kind = 'person' THEN 'person' ELSE 'business' END AS kind, p.name, p.contact_name,
               p.email, coalesce(st.cc_emails, '{}'::text[]) AS cc_emails, p.phone, coalesce(st.website, '') AS website, p.tax_number,
               p.address_line1, p.address_line2, p.city, p.region, p.postal_code, p.country, p.currency, st.locale, p.payment_terms_days,
               coalesce(st.groups, '{}'::text[]) AS groups, p.notes, p.archived_at,
               coalesce(st.source_app, CASE WHEN p.source_app = 'mystoreguard' THEN 'mystoreguard' END) AS source_app,
               coalesce(st.source_id, CASE WHEN p.source_app = 'mystoreguard' THEN p.id END) AS source_id,
               st.source_hash, coalesce(st.source_removed, false) AS source_removed, coalesce(st.edited_locally, false) AS edited_locally, st.imported_at,
               p.cdatetime, p.updated_at, p.created_by, p.updated_by, coalesce(st.no_reminders, false) AS no_reminders, st.portal_token,
               coalesce(st.no_late_fees, false) AS no_late_fees, coalesce(st.autopay, false) AS autopay, coalesce(st.account_ref, '') AS account_ref,
               coalesce(st.einvoice_id, '') AS einvoice_id, coalesce(st.state_code, '') AS state_code, coalesce(st.template, '') AS template,
               CASE WHEN p.is_customer AND p.is_supplier THEN 'both' WHEN p.is_supplier THEN 'supplier' ELSE 'customer' END AS role
          FROM core_platform.cp_parties p
          LEFT JOIN invoicing.inv_customer_settings st ON st.party_id = p.id
         WHERE (p.is_customer OR p.is_supplier) AND p.deleted_at IS NULL
        $v$;
        EXECUTE $t$
        CREATE OR REPLACE FUNCTION invoicing.inv_customers_write() RETURNS trigger
        LANGUAGE plpgsql AS $f$
        DECLARE r text;
        BEGIN
            IF TG_OP = 'DELETE' THEN
                IF core_platform.cp_party_in_use(OLD.id) THEN
                    RAISE foreign_key_violation USING MESSAGE = 'This customer is used by invoices or sales and cannot be deleted';
                END IF;
                DELETE FROM invoicing.inv_payment_methods WHERE customer_id = OLD.id;
                UPDATE core_platform.cp_parties SET is_customer = false, is_supplier = false, deleted_at = coalesce(deleted_at, now()), updated_at = now()
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
                RETURN OLD;
            END IF;
            r := coalesce(NEW.role, CASE WHEN TG_OP = 'UPDATE' THEN OLD.role END, 'customer');
            IF TG_OP = 'INSERT' THEN
                INSERT INTO core_platform.cp_parties (id, tenant_id, org_id, bus_id, kind, name, contact_name, email, phone, tax_number, address_line1,
                       address_line2, city, region, postal_code, country, currency, payment_terms_days, notes, is_customer, is_supplier, source_app,
                       archived_at, cdatetime, updated_at, created_by, updated_by)
                VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id,
                       coalesce(NEW.org_id, (SELECT org_id FROM core_platform.cp_businesses WHERE id = NEW.bus_id)), NEW.bus_id,
                       CASE WHEN NEW.kind = 'person' THEN 'person' ELSE 'company' END, NEW.name, coalesce(NEW.contact_name, ''), coalesce(NEW.email, ''),
                       coalesce(NEW.phone, ''), coalesce(NEW.tax_number, ''), coalesce(NEW.address_line1, ''), coalesce(NEW.address_line2, ''),
                       coalesce(NEW.city, ''), coalesce(NEW.region, ''), coalesce(NEW.postal_code, ''), NEW.country, NEW.currency, NEW.payment_terms_days,
                       coalesce(NEW.notes, ''), r IN ('customer', 'both'), r IN ('supplier', 'both'), coalesce(NEW.source_app, 'invoicing'),
                       NEW.archived_at, coalesce(NEW.cdatetime, now()), coalesce(NEW.updated_at, now()), NEW.created_by, NEW.updated_by)
                RETURNING id INTO NEW.id;
            ELSE
                UPDATE core_platform.cp_parties
                   SET kind = CASE WHEN NEW.kind = 'person' THEN 'person' ELSE 'company' END, name = NEW.name, contact_name = coalesce(NEW.contact_name, ''),
                       email = coalesce(NEW.email, ''), phone = coalesce(NEW.phone, ''), tax_number = coalesce(NEW.tax_number, ''),
                       address_line1 = coalesce(NEW.address_line1, ''), address_line2 = coalesce(NEW.address_line2, ''), city = coalesce(NEW.city, ''),
                       region = coalesce(NEW.region, ''), postal_code = coalesce(NEW.postal_code, ''), country = NEW.country, currency = NEW.currency,
                       payment_terms_days = NEW.payment_terms_days, notes = coalesce(NEW.notes, ''),
                       is_customer = r IN ('customer', 'both'),
                       is_supplier = r IN ('supplier', 'both'),
                       archived_at = NEW.archived_at, updated_at = now(), updated_by = coalesce(NEW.updated_by, updated_by)
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            END IF;
            INSERT INTO invoicing.inv_customer_settings (party_id, tenant_id, bus_id, cc_emails, website, locale, groups, source_app, source_id, source_hash,
                   source_removed, edited_locally, imported_at, no_reminders, portal_token, no_late_fees, autopay, account_ref, einvoice_id, state_code, template)
            VALUES (NEW.id, NEW.tenant_id, NEW.bus_id, coalesce(NEW.cc_emails, '{}'), coalesce(NEW.website, ''), NEW.locale, coalesce(NEW.groups, '{}'),
                   NEW.source_app, NEW.source_id, NEW.source_hash, coalesce(NEW.source_removed, false), coalesce(NEW.edited_locally, false),
                   NEW.imported_at, coalesce(NEW.no_reminders, false), NEW.portal_token, coalesce(NEW.no_late_fees, false), coalesce(NEW.autopay, false),
                   coalesce(NEW.account_ref, ''), coalesce(NEW.einvoice_id, ''), coalesce(NEW.state_code, ''), coalesce(NEW.template, ''))
            ON CONFLICT (party_id) DO UPDATE SET cc_emails = EXCLUDED.cc_emails, website = EXCLUDED.website, locale = EXCLUDED.locale,
                   groups = EXCLUDED.groups, source_app = EXCLUDED.source_app, source_id = EXCLUDED.source_id, source_hash = EXCLUDED.source_hash,
                   source_removed = EXCLUDED.source_removed, edited_locally = EXCLUDED.edited_locally, imported_at = EXCLUDED.imported_at,
                   no_reminders = EXCLUDED.no_reminders, portal_token = EXCLUDED.portal_token, no_late_fees = EXCLUDED.no_late_fees,
                   autopay = EXCLUDED.autopay, account_ref = EXCLUDED.account_ref, einvoice_id = EXCLUDED.einvoice_id, state_code = EXCLUDED.state_code,
                   template = EXCLUDED.template;
            NEW.role := r;
            RETURN NEW;
        END
        $f$
        $t$;
        DROP TRIGGER IF EXISTS inv_customers_write ON invoicing.inv_customers;
        CREATE TRIGGER inv_customers_write INSTEAD OF INSERT OR UPDATE OR DELETE ON invoicing.inv_customers
            FOR EACH ROW EXECUTE FUNCTION invoicing.inv_customers_write();
    END IF;

    -- The views that read the old tables read the new ones.
    FOR r IN SELECT name, def FROM pg_temp.rebuild LOOP
        EXECUTE format('CREATE OR REPLACE VIEW %s AS %s', r.name,
                       replace(replace(r.def, 'msg_customers_legacy', 'msg_customers'), 'inv_customers_legacy', 'inv_customers'));
    END LOOP;
END $$;

-- ===================================================================== keys
-- The columns that pointed at the old tables point at Core Platform. NOT VALID: rows made
-- before (some apps never had a key) are not checked, new ones are.
DO $$
DECLARE k record;
BEGIN
    FOR k IN SELECT * FROM (VALUES
            ('mystoreguard.msg_sales', 'customer_id'), ('mystoreguard.msg_invoices', 'customer_id'),
            ('mystoreguard.msg_affiliate_referrals', 'customer_id'), ('mystoreguard.msg_promo_code_usage', 'customer_id'),
            ('mystoreguard.msg_tasks', 'customer_id'), ('mystoreguard.msg_gift_cards', 'purchased_by_customer_id'),
            ('invoicing.inv_invoices', 'customer_id'), ('invoicing.inv_recurring', 'customer_id'), ('invoicing.inv_contracts', 'customer_id'),
            ('invoicing.inv_payment_methods', 'customer_id')) AS v(tbl, col) LOOP
        IF to_regclass(k.tbl) IS NOT NULL AND NOT EXISTS (
               SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass(k.tbl) AND conname = replace(split_part(k.tbl, '.', 2), '_', '') || '_' || k.col || '_party_fk') THEN
            EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES core_platform.cp_parties (id) ON DELETE RESTRICT NOT VALID',
                           k.tbl, replace(split_part(k.tbl, '.', 2), '_', '') || '_' || k.col || '_party_fk', k.col);
        END IF;
    END LOOP;
END $$;

COMMIT;
