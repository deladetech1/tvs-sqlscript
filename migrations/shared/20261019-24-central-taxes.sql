-- =====================================================================
-- Taxes, set up once in Core Platform and used by every app
-- ---------------------------------------------------------------------
-- A business used to type the same taxes into MyStoreGuard and again into
-- Invoicing; when a rate changed, one was updated and the other forgotten, and
-- the two charged different tax on the same sale. WHAT the taxes are now lives
-- in Core Platform, once per business:
--
--   core_platform.cp_tax_rates          a tax: percentage or fixed amount, its
--                                       treatment, who it is paid to, and whether
--                                       a shop's prices already include it
--   core_platform.cp_tax_rate_versions  its value, each from a date -- a change
--                                       is scheduled, old documents keep the old rate
--   core_platform.cp_tax_groups(+members) several taxes charged together, in
--                                       order; a compound member is charged on
--                                       the price plus the taxes before it
--
-- WHEN a tax applies stays in each app, because that is the app's own world:
-- MyStoreGuard's rules by location, product or category (msg_tax_rule), and
-- Invoicing's by customer, country and amount, its exemptions and withholding
-- (inv_tax_rules, inv_tax_exemptions). Those rules now point at the central
-- taxes. Payroll taxes stay in ZelosHR: income-tax bands are another kind.
--
-- The columns are Invoicing's (the fuller model), plus included_in_price for
-- MyStoreGuard. Ids are kept, so every rule, item and exemption still points at
-- the same tax.
--
--   * Invoicing's rates and groups are copied in (every run: ON CONFLICT DO
--     NOTHING), and its rules, exemptions and items repointed. Its own tables
--     are left in place, unused, because earlier migrations recreate them.
--   * MyStoreGuard's msg_taxes table becomes a VIEW of the central taxes with
--     the columns MyStoreGuard reads, so its calculators, estimates and the
--     price functions in Invoicing and the CRM read the central taxes unchanged.
--     Done once (while msg_taxes is still a table); the old table is kept as
--     msg_taxes_legacy.
--
-- Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_tax_rates (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    name              text NOT NULL CHECK (btrim(name) <> ''),
    -- What a document prints beside the amount: "VAT", "GST", "NHIL".
    short_name        text NOT NULL DEFAULT '',
    kind              text NOT NULL DEFAULT 'percent' CHECK (kind IN ('percent', 'fixed')),
    treatment         text NOT NULL DEFAULT 'standard'
                      CHECK (treatment IN ('standard', 'zero_rated', 'exempt', 'reverse_charge', 'withholding')),
    -- A fixed amount is charged per unit, per line or once per document, in this currency.
    fixed_basis       text CHECK (fixed_basis IS NULL OR fixed_basis IN ('unit', 'line', 'document')),
    fixed_currency    char(3) CHECK (fixed_currency IS NULL OR fixed_currency ~ '^[A-Z]{3}$'),
    country           char(2) CHECK (country IS NULL OR country ~ '^[A-Z]{2}$'),
    region            text,
    -- Who it is paid to, and the code an accountant files it under.
    authority         text NOT NULL DEFAULT '',
    report_code       text NOT NULL DEFAULT '',
    description       text NOT NULL DEFAULT '',
    -- A shop's prices already include it (MyStoreGuard takes it out rather than adding it).
    included_in_price boolean NOT NULL DEFAULT false,
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    CHECK ((kind = 'fixed') = (fixed_basis IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS cp_tax_rates_bus_idx ON core_platform.cp_tax_rates (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS cp_tax_rates_name_uq ON core_platform.cp_tax_rates (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_tax_rate_versions (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    rate_id     text NOT NULL REFERENCES core_platform.cp_tax_rates (id) ON DELETE CASCADE,
    tenant_id   text NOT NULL,
    valid_from  date NOT NULL,
    -- A percentage (17.5 = 17.5 %) or, for a fixed rate, the amount.
    value       numeric(18, 6) NOT NULL CHECK (value >= 0),
    note        text NOT NULL DEFAULT '',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS cp_tax_rate_versions_uq ON core_platform.cp_tax_rate_versions (rate_id, valid_from);

CREATE TABLE IF NOT EXISTS core_platform.cp_tax_groups (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    name         text NOT NULL CHECK (btrim(name) <> ''),
    description  text NOT NULL DEFAULT '',
    archived_at  timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text
);
CREATE INDEX IF NOT EXISTS cp_tax_groups_bus_idx ON core_platform.cp_tax_groups (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS cp_tax_groups_name_uq ON core_platform.cp_tax_groups (bus_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS core_platform.cp_tax_group_members (
    group_id   text NOT NULL REFERENCES core_platform.cp_tax_groups (id) ON DELETE CASCADE,
    rate_id    text NOT NULL REFERENCES core_platform.cp_tax_rates (id) ON DELETE RESTRICT,
    tenant_id  text NOT NULL,
    position   integer NOT NULL DEFAULT 0,
    -- Charged on the price plus the taxes before it in the group.
    compound   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (group_id, rate_id)
);

-- What a tax is worth on a day: the version in force then (none: NULL).
CREATE OR REPLACE FUNCTION core_platform.cp_tax_rate_value(p_rate text, p_on date DEFAULT CURRENT_DATE)
RETURNS numeric LANGUAGE sql STABLE AS $f$
    SELECT v.value FROM core_platform.cp_tax_rate_versions v
     WHERE v.rate_id = p_rate AND v.valid_from <= p_on
     ORDER BY v.valid_from DESC LIMIT 1
$f$;

-- ===================================================================== Invoicing's
DO $$
BEGIN
    IF to_regclass('invoicing.inv_tax_rates') IS NULL THEN
        RETURN;
    END IF;
    INSERT INTO core_platform.cp_tax_rates (id, tenant_id, org_id, bus_id, name, short_name, kind, treatment, fixed_basis, fixed_currency,
           country, region, authority, report_code, description, archived_at, cdatetime, created_by)
    SELECT id, tenant_id, org_id, bus_id, name, short_name, kind, treatment, fixed_basis, fixed_currency,
           country, region, authority, report_code, description, archived_at, cdatetime, created_by
      FROM invoicing.inv_tax_rates
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_tax_rate_versions (id, rate_id, tenant_id, valid_from, value, note, cdatetime, created_by)
    SELECT v.id, v.rate_id, v.tenant_id, v.valid_from, v.value, v.note, v.cdatetime, v.created_by
      FROM invoicing.inv_tax_rate_versions v
      JOIN core_platform.cp_tax_rates r ON r.id = v.rate_id
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_tax_groups (id, tenant_id, org_id, bus_id, name, description, archived_at, cdatetime, created_by)
    SELECT id, tenant_id, org_id, bus_id, name, description, archived_at, cdatetime, created_by
      FROM invoicing.inv_tax_groups
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_tax_group_members (group_id, rate_id, tenant_id, position, compound)
    SELECT m.group_id, m.rate_id, m.tenant_id, m.position, m.compound
      FROM invoicing.inv_tax_group_members m
      JOIN core_platform.cp_tax_groups g ON g.id = m.group_id
      JOIN core_platform.cp_tax_rates r ON r.id = m.rate_id
    ON CONFLICT DO NOTHING;
END $$;

-- Repoint a column's foreign key at a central table: drop any key on it that points
-- elsewhere, and add the central one if it is missing.
CREATE OR REPLACE FUNCTION pg_temp.repoint_fk(p_table regclass, p_column text, p_target text, p_action text, p_name text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c record;
BEGIN
    FOR c IN SELECT con.conname FROM pg_constraint con
              WHERE con.contype = 'f' AND con.conrelid = p_table
                AND con.confrelid <> p_target::regclass
                AND array_length(con.conkey, 1) = 1
                AND (SELECT attname FROM pg_attribute WHERE attrelid = con.conrelid AND attnum = con.conkey[1]) = p_column LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', p_table, c.conname);
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = p_table AND conname = p_name) THEN
        EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %s (id) ON DELETE %s',
                       p_table, p_name, p_column, p_target, p_action);
    END IF;
END
$f$;

DO $$
BEGIN
    IF to_regclass('invoicing.inv_tax_rules') IS NOT NULL THEN
        PERFORM pg_temp.repoint_fk('invoicing.inv_tax_rules', 'rate_id', 'core_platform.cp_tax_rates', 'RESTRICT', 'inv_tax_rules_cp_rate_fk');
        PERFORM pg_temp.repoint_fk('invoicing.inv_tax_rules', 'group_id', 'core_platform.cp_tax_groups', 'RESTRICT', 'inv_tax_rules_cp_group_fk');
    END IF;
    IF to_regclass('invoicing.inv_tax_exemptions') IS NOT NULL THEN
        PERFORM pg_temp.repoint_fk('invoicing.inv_tax_exemptions', 'rate_id', 'core_platform.cp_tax_rates', 'CASCADE', 'inv_tax_exemptions_cp_rate_fk');
        PERFORM pg_temp.repoint_fk('invoicing.inv_tax_exemptions', 'group_id', 'core_platform.cp_tax_groups', 'CASCADE', 'inv_tax_exemptions_cp_group_fk');
    END IF;
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_items')) = 'r' THEN
        PERFORM pg_temp.repoint_fk('invoicing.inv_items', 'tax_rate_id', 'core_platform.cp_tax_rates', 'SET NULL', 'inv_items_cp_rate_fk');
        PERFORM pg_temp.repoint_fk('invoicing.inv_items', 'tax_group_id', 'core_platform.cp_tax_groups', 'SET NULL', 'inv_items_cp_group_fk');
    END IF;
END $$;

-- ===================================================================== MyStoreGuard's
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_taxes') IS NULL
       OR (SELECT relkind FROM pg_class WHERE oid = 'mystoreguard.msg_taxes'::regclass) <> 'r' THEN
        RETURN;  -- already a view, or no MyStoreGuard here
    END IF;
    -- Its taxes, in. A second live tax of the same name in a business takes its rate in
    -- its name, so the names stay unique.
    INSERT INTO core_platform.cp_tax_rates (id, tenant_id, org_id, bus_id, name, short_name, kind, description, included_in_price,
           archived_at, cdatetime, created_by)
    SELECT t.id, t.tenant_id, t.org_id, t.bus_id,
           CASE WHEN EXISTS (SELECT 1 FROM core_platform.cp_tax_rates c WHERE c.bus_id = t.bus_id AND lower(c.name) = lower(btrim(t.name)) AND c.archived_at IS NULL)
                THEN btrim(t.name) || ' (MyStoreGuard)'
                WHEN row_number() OVER (PARTITION BY t.bus_id, lower(btrim(t.name)), (t.is_active AND t.deleted_by IS NULL) ORDER BY t.cdatetime, t.id) = 1
                THEN btrim(t.name) ELSE btrim(t.name) || ' ' || trim_scale(t.rate)::text || '%' END,
           left(btrim(t.name), 12), 'percent', coalesce(t.description, ''), t.is_inclusive,
           CASE WHEN t.is_active AND t.deleted_by IS NULL THEN NULL ELSE coalesce(t.cdatetime, now()) END,
           coalesce(t.cdatetime, now()), t.created_by
      FROM mystoreguard.msg_taxes t
    ON CONFLICT DO NOTHING;
    INSERT INTO core_platform.cp_tax_rate_versions (rate_id, tenant_id, valid_from, value, note)
    SELECT t.id, t.tenant_id, DATE '2000-01-01', t.rate, 'From MyStoreGuard'
      FROM mystoreguard.msg_taxes t
      JOIN core_platform.cp_tax_rates r ON r.id = t.id
    ON CONFLICT DO NOTHING;
    -- The rules point at the central taxes from now on.
    ALTER TABLE mystoreguard.msg_tax_rule DROP CONSTRAINT IF EXISTS fk_msg_tax_rule_msg_taxes_tenant_id_org_id_bus_id_tax_id;
    ALTER TABLE mystoreguard.tax_rule_conditions DROP CONSTRAINT IF EXISTS fk_tax_rule_conditions_msg_taxes_tenant_id_org_id_bus_id_tax_id;
    ALTER TABLE mystoreguard.msg_taxes RENAME TO msg_taxes_legacy;
END $$;

DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_tax_rule') IS NULL THEN
        RETURN;
    END IF;
    -- The view: the columns MyStoreGuard reads. Percentage taxes a shop charges (not
    -- reverse charge or withholding, which are an invoice's), at today's rate.
    EXECUTE $v$
    CREATE OR REPLACE VIEW mystoreguard.msg_taxes AS
    SELECT r.id, r.tenant_id, coalesce(r.org_id, b.org_id) AS org_id, r.bus_id, r.name,
           NULLIF(r.description, '') AS description,
           coalesce(core_platform.cp_tax_rate_value(r.id, CURRENT_DATE), 0)::numeric(18, 2) AS rate,
           r.included_in_price AS is_inclusive,
           (r.archived_at IS NULL) AS is_active,
           to_char(r.cdatetime, 'YYYY-MM-DD') AS cdate, to_char(r.cdatetime, 'HH24:MI:SS') AS ctime, r.cdatetime,
           r.created_by, r.updated_by, NULL::text AS deleted_by
      FROM core_platform.cp_tax_rates r
      LEFT JOIN core_platform.cp_businesses b ON b.id = r.bus_id AND b.tenant_id = r.tenant_id
     WHERE r.kind = 'percent' AND r.treatment IN ('standard', 'zero_rated', 'exempt')
    $v$;
    -- MyStoreGuard's tax screens write through the view, into the central taxes.
    EXECUTE $t$
    CREATE OR REPLACE FUNCTION mystoreguard.msg_taxes_write() RETURNS trigger
    LANGUAGE plpgsql AS $f$
    BEGIN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO core_platform.cp_tax_rates (id, tenant_id, org_id, bus_id, name, short_name, description, included_in_price,
                   archived_at, cdatetime, created_by)
            VALUES (coalesce(NEW.id, gen_random_uuid()::text), NEW.tenant_id, NEW.org_id, NEW.bus_id, btrim(NEW.name), left(btrim(NEW.name), 12),
                   coalesce(NEW.description, ''), coalesce(NEW.is_inclusive, false),
                   CASE WHEN coalesce(NEW.is_active, true) THEN NULL ELSE now() END, coalesce(NEW.cdatetime, now()), NEW.created_by)
            RETURNING id INTO NEW.id;
            -- MyStoreGuard has no dates on a rate: it applies from the start.
            INSERT INTO core_platform.cp_tax_rate_versions (rate_id, tenant_id, valid_from, value, created_by)
            VALUES (NEW.id, NEW.tenant_id, DATE '2000-01-01', coalesce(NEW.rate, 0), NEW.created_by);
            RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
            UPDATE core_platform.cp_tax_rates
               SET name = btrim(NEW.name), description = coalesce(NEW.description, ''), included_in_price = coalesce(NEW.is_inclusive, false),
                   archived_at = CASE WHEN coalesce(NEW.is_active, true) THEN NULL ELSE coalesce(archived_at, now()) END,
                   updated_at = now(), updated_by = NEW.updated_by
             WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            -- A new rate is a new version from today; the old one stays for what came before.
            IF NEW.rate IS DISTINCT FROM OLD.rate THEN
                INSERT INTO core_platform.cp_tax_rate_versions (rate_id, tenant_id, valid_from, value, created_by)
                VALUES (OLD.id, OLD.tenant_id, CURRENT_DATE, coalesce(NEW.rate, 0), NEW.updated_by)
                ON CONFLICT (rate_id, valid_from) DO UPDATE SET value = EXCLUDED.value;
            END IF;
            RETURN NEW;
        ELSE
            -- As before, its rules go with it; the tax itself is deleted, or archived when
            -- another app still uses it.
            DELETE FROM mystoreguard.tax_rule_conditions WHERE tax_id = OLD.id AND tenant_id = OLD.tenant_id;
            DELETE FROM mystoreguard.msg_tax_rule WHERE tax_id = OLD.id AND tenant_id = OLD.tenant_id;
            BEGIN
                DELETE FROM core_platform.cp_tax_rates WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            EXCEPTION WHEN foreign_key_violation THEN
                UPDATE core_platform.cp_tax_rates SET archived_at = coalesce(archived_at, now()), updated_at = now()
                 WHERE id = OLD.id AND tenant_id = OLD.tenant_id;
            END;
            RETURN OLD;
        END IF;
    END
    $f$
    $t$;
    DROP TRIGGER IF EXISTS msg_taxes_write ON mystoreguard.msg_taxes;
    CREATE TRIGGER msg_taxes_write INSTEAD OF INSERT OR UPDATE OR DELETE ON mystoreguard.msg_taxes
        FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_taxes_write();
    PERFORM pg_temp.repoint_fk('mystoreguard.msg_tax_rule', 'tax_id', 'core_platform.cp_tax_rates', 'RESTRICT', 'msg_tax_rule_cp_rate_fk');
    PERFORM pg_temp.repoint_fk('mystoreguard.tax_rule_conditions', 'tax_id', 'core_platform.cp_tax_rates', 'RESTRICT', 'tax_rule_conditions_cp_rate_fk');
END $$;

COMMIT;
