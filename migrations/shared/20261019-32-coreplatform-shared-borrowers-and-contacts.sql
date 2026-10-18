-- =====================================================================
-- Loandrift's clients and the CRM's contacts point at the business's customers
-- ---------------------------------------------------------------------
-- The business's customers are kept once in Core Platform (core_platform.cp_parties,
-- 20261019-29/30). Two more apps hold people the business deals with:
--
--   * loandrift.ld_clients   a borrower, with Loandrift's KYC (ids, next of kin, ...).
--     Each client now has party_id, its customer record: made when the client is
--     registered, and kept up to date with the client's name, phone, email,
--     address, gender and date of birth. Loandrift owns the KYC; the customer
--     record carries who they are to every other app (MyStoreGuard, Invoicing).
--     A customer Invoicing had brought in from Loandrift is that client's record.
--   * crm.crm_contacts       a person the sales team works with. A contact that came
--     from MyStoreGuard or Loandrift (crm_contact_sources) points at that customer
--     (party_id); a contact made in the CRM alone has none.
--
-- Both are in core_platform.cp_party_references, so merging two customers moves them.
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

-- ===================================================================== Loandrift
DO $$
BEGIN
    IF to_regclass('loandrift.ld_clients') IS NULL THEN
        RETURN;
    END IF;
    ALTER TABLE loandrift.ld_clients ADD COLUMN IF NOT EXISTS party_id text;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ld_clients_party_fk') THEN
        ALTER TABLE loandrift.ld_clients ADD CONSTRAINT ld_clients_party_fk FOREIGN KEY (party_id)
            REFERENCES core_platform.cp_parties (id) ON DELETE SET NULL;
    END IF;
    CREATE INDEX IF NOT EXISTS ld_clients_party_idx ON loandrift.ld_clients (party_id);
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension)
    VALUES ('loandrift.ld_clients', 'party_id', false)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = false;
END $$;

-- A date of birth as Loandrift keeps it (text): a date, or nothing.
CREATE OR REPLACE FUNCTION core_platform.cp_try_date(p text) RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $f$
BEGIN
    RETURN nullif(btrim(p), '')::date;
EXCEPTION WHEN others THEN
    RETURN NULL;
END
$f$;

DO $$
BEGIN
    IF to_regclass('loandrift.ld_clients') IS NULL THEN
        RETURN;
    END IF;
    -- The client's record, for clients that have none: the one Invoicing brought in from
    -- Loandrift when there is one, else a new one.
    UPDATE loandrift.ld_clients c SET party_id = st.party_id
      FROM invoicing.inv_customer_settings st
      JOIN core_platform.cp_parties p ON p.id = st.party_id AND p.deleted_at IS NULL
     WHERE c.party_id IS NULL AND st.source_app = 'loandrift' AND st.source_id = c.id AND p.bus_id = c.bus_id
       AND to_regclass('invoicing.inv_customer_settings') IS NOT NULL;
EXCEPTION WHEN undefined_table THEN
    NULL; -- no Invoicing here
END $$;

CREATE OR REPLACE FUNCTION loandrift.ld_clients_party() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF NEW.party_id IS NULL THEN
        INSERT INTO core_platform.cp_parties (tenant_id, org_id, bus_id, kind, name, email, phone, address_line1, gender, date_of_birth, is_customer,
               source_app, archived_at, deleted_at, cdatetime, created_by)
        VALUES (NEW.tenant_id, NEW.org_id, NEW.bus_id, 'person', coalesce(nullif(btrim(NEW.fullname), ''), 'Client'), coalesce(btrim(NEW.email), ''),
               coalesce(btrim(NEW.contact), ''), coalesce(btrim(NEW.residential_address), ''), NEW.gender, core_platform.cp_try_date(NEW.dob), true,
               'loandrift', CASE WHEN NEW.is_active IS FALSE THEN now() END,
               CASE WHEN coalesce(NEW.delete_status, 'NOT_DELETED') <> 'NOT_DELETED' THEN now() END, coalesce(NEW.cdatetime, now()), NEW.created_by)
        RETURNING id INTO NEW.party_id;
    ELSIF TG_OP = 'UPDATE' AND (NEW.fullname, NEW.email, NEW.contact, NEW.residential_address, NEW.gender, NEW.dob, NEW.is_active, NEW.delete_status)
                                IS DISTINCT FROM
                                (OLD.fullname, OLD.email, OLD.contact, OLD.residential_address, OLD.gender, OLD.dob, OLD.is_active, OLD.delete_status) THEN
        UPDATE core_platform.cp_parties
           SET name = coalesce(nullif(btrim(NEW.fullname), ''), name), email = coalesce(btrim(NEW.email), ''), phone = coalesce(btrim(NEW.contact), ''),
               address_line1 = coalesce(btrim(NEW.residential_address), ''), gender = NEW.gender,
               date_of_birth = coalesce(core_platform.cp_try_date(NEW.dob), date_of_birth), is_customer = true,
               archived_at = CASE WHEN NEW.is_active IS FALSE THEN coalesce(archived_at, now()) ELSE NULL END,
               deleted_at = CASE WHEN coalesce(NEW.delete_status, 'NOT_DELETED') <> 'NOT_DELETED' THEN coalesce(deleted_at, now()) ELSE NULL END,
               updated_at = now(), updated_by = NEW.updated_by
         WHERE id = NEW.party_id;
    END IF;
    RETURN NEW;
END
$f$;

-- A client deleted in Loandrift: their customer record goes too when no other app uses it.
CREATE OR REPLACE FUNCTION loandrift.ld_clients_party_gone() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF OLD.party_id IS NOT NULL AND NOT core_platform.cp_party_in_use(OLD.party_id) THEN
        UPDATE core_platform.cp_parties SET is_customer = is_customer AND source_app <> 'loandrift',
               deleted_at = CASE WHEN source_app = 'loandrift' THEN coalesce(deleted_at, now()) ELSE deleted_at END, updated_at = now()
         WHERE id = OLD.party_id;
    END IF;
    RETURN OLD;
END
$f$;

DO $$
BEGIN
    IF to_regclass('loandrift.ld_clients') IS NULL THEN
        RETURN;
    END IF;
    DROP TRIGGER IF EXISTS ld_clients_party ON loandrift.ld_clients;
    CREATE TRIGGER ld_clients_party BEFORE INSERT OR UPDATE ON loandrift.ld_clients
        FOR EACH ROW EXECUTE FUNCTION loandrift.ld_clients_party();
    DROP TRIGGER IF EXISTS ld_clients_party_gone ON loandrift.ld_clients;
    CREATE TRIGGER ld_clients_party_gone AFTER DELETE ON loandrift.ld_clients
        FOR EACH ROW EXECUTE FUNCTION loandrift.ld_clients_party_gone();
    -- Always, replica or not: a client is never without their customer record.
    ALTER TABLE loandrift.ld_clients ENABLE ALWAYS TRIGGER ld_clients_party;
    ALTER TABLE loandrift.ld_clients ENABLE ALWAYS TRIGGER ld_clients_party_gone;
    -- The rest get theirs (the BEFORE trigger makes it).
    UPDATE loandrift.ld_clients SET party_id = NULL WHERE party_id IS NULL;
END $$;

-- ===================================================================== the CRM
DO $$
BEGIN
    IF to_regclass('crm.crm_contacts') IS NULL THEN
        RETURN;
    END IF;
    ALTER TABLE crm.crm_contacts ADD COLUMN IF NOT EXISTS party_id text;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'crm_contacts_party_fk') THEN
        ALTER TABLE crm.crm_contacts ADD CONSTRAINT crm_contacts_party_fk FOREIGN KEY (party_id)
            REFERENCES core_platform.cp_parties (id) ON DELETE SET NULL;
    END IF;
    CREATE INDEX IF NOT EXISTS crm_contacts_party_idx ON crm.crm_contacts (party_id);
    INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension)
    VALUES ('crm.crm_contacts', 'party_id', true)
    ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = true;
END $$;

-- The customer a CRM contact's source is: MyStoreGuard's customer is a record of its own id;
-- Loandrift's client points at one.
CREATE OR REPLACE FUNCTION crm.crm_source_party(p_app text, p_source_id text, p_bus text) RETURNS text
LANGUAGE plpgsql STABLE AS $f$
DECLARE pid text;
BEGIN
    IF p_app = 'mystoreguard' THEN
        SELECT id INTO pid FROM core_platform.cp_parties WHERE id = p_source_id AND bus_id = p_bus AND deleted_at IS NULL;
    ELSIF p_app = 'loandrift' AND to_regclass('loandrift.ld_clients') IS NOT NULL THEN
        EXECUTE 'SELECT party_id FROM loandrift.ld_clients WHERE id = $1 AND bus_id = $2 LIMIT 1' INTO pid USING p_source_id, p_bus;
    END IF;
    RETURN pid;
END
$f$;

CREATE OR REPLACE FUNCTION crm.crm_contact_sources_party() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE pid text;
BEGIN
    pid := crm.crm_source_party(NEW.source_app, NEW.source_id, NEW.bus_id);
    IF pid IS NOT NULL THEN
        UPDATE crm.crm_contacts SET party_id = pid WHERE id = NEW.contact_id AND party_id IS NULL;
    END IF;
    RETURN NEW;
END
$f$;

DO $$
BEGIN
    IF to_regclass('crm.crm_contact_sources') IS NULL THEN
        RETURN;
    END IF;
    DROP TRIGGER IF EXISTS crm_contact_sources_party ON crm.crm_contact_sources;
    CREATE TRIGGER crm_contact_sources_party AFTER INSERT OR UPDATE OF source_app, source_id ON crm.crm_contact_sources
        FOR EACH ROW EXECUTE FUNCTION crm.crm_contact_sources_party();
    ALTER TABLE crm.crm_contact_sources ENABLE ALWAYS TRIGGER crm_contact_sources_party;
    UPDATE crm.crm_contacts c SET party_id = crm.crm_source_party(s.source_app, s.source_id, s.bus_id)
      FROM crm.crm_contact_sources s
     WHERE s.contact_id = c.id AND c.party_id IS NULL AND crm.crm_source_party(s.source_app, s.source_id, s.bus_id) IS NOT NULL;
END $$;

COMMIT;
