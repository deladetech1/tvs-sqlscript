-- Help Desk R3: assets, the CMDB and vendors.
--
--   hd_asset_types          asset types and the fields each one carries (the R2 forms schema)
--   hd_assets               assets: tag, state, who has it, warranty, licence seats, its CI
--   hd_asset_events         append-only: an asset's lifecycle
--   hd_asset_maintenance    preventive, corrective and inspection work
--   hd_licence_assignments  who holds a seat of a software licence
--   hd_ticket_assets        assets a ticket is about
--   hd_cis                  configuration items
--   hd_ci_relations         typed edges between CIs (never to itself)
--   hd_ticket_cis, hd_problem_cis
--   hd_vendor_profiles      Help Desk's fields on a Core supplier (core_platform.cp_parties)
--   hd_vendor_contracts     contracts with a vendor
--
-- Also the FKs to hd_cis from 20261106-12 (hd_maintenance_windows.ci_id, hd_change_cis.ci_id).
--
-- Vendors are Core parties: core_platform.cp_parties (id, tenant_id, bus_id, name, is_supplier,
-- deleted_at...; checked 2026-11-06). Every party column here is registered in
-- core_platform.cp_party_references so a party merge re-points it. hd_vendor_profiles is an
-- extension (it moves with the party and does not stop it being deleted: FK ON DELETE CASCADE, as
-- Expenses' vendor settings); the others are not, so a party they name counts as in use.
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R3.md §3. Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= asset types
CREATE TABLE IF NOT EXISTS helpdesk.hd_asset_types (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    category      text NOT NULL
                  CONSTRAINT hd_asset_types_category_check CHECK (category IN ('computer', 'mobile', 'server', 'network',
                      'software_licence', 'cloud', 'peripheral', 'other')),
    field_schema  jsonb NOT NULL DEFAULT '{"fields":[]}',
    is_active     boolean NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE INDEX IF NOT EXISTS hd_asset_types_business_idx ON helpdesk.hd_asset_types (tenant_id, bus_id);

-- ============================================================================ assets
-- ci_id gets its FK below, once hd_cis exists (a CI may also name its asset).
CREATE TABLE IF NOT EXISTS helpdesk.hd_assets (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    asset_tag            text NOT NULL,
    type_id              text REFERENCES helpdesk.hd_asset_types (id),
    name                 text NOT NULL,
    serial_number        text,
    model                text,
    manufacturer         text,
    state                text NOT NULL DEFAULT 'in_stock'
                         CONSTRAINT hd_assets_state_check CHECK (state IN ('on_order', 'in_stock', 'assigned', 'in_maintenance',
                             'in_repair', 'retired', 'disposed')),
    assigned_user_id     text,
    owner_department_id  text REFERENCES helpdesk.hd_departments (id),
    loc_id               text,
    vendor_party_id      text,
    purchase_date        date,
    purchase_cost        numeric(14,2) CONSTRAINT hd_assets_purchase_cost_check CHECK (purchase_cost >= 0),
    currency             text CONSTRAINT hd_assets_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
    warranty_ends_on     date,
    licence_seats        int CONSTRAINT hd_assets_licence_seats_check CHECK (licence_seats > 0),
    attributes           jsonb NOT NULL DEFAULT '{}',
    ci_id                text,
    version              int NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    CONSTRAINT hd_assets_cost_check CHECK (purchase_cost IS NULL OR currency IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_assets_tag_uq ON helpdesk.hd_assets (tenant_id, bus_id, asset_tag);
CREATE INDEX IF NOT EXISTS hd_assets_business_idx ON helpdesk.hd_assets (tenant_id, bus_id, state);
CREATE INDEX IF NOT EXISTS hd_assets_assigned_idx ON helpdesk.hd_assets (tenant_id, bus_id, assigned_user_id);
-- The warranty reminder reads assets by warranty end.
CREATE INDEX IF NOT EXISTS hd_assets_warranty_idx ON helpdesk.hd_assets (warranty_ends_on) WHERE warranty_ends_on IS NOT NULL;

CREATE TABLE IF NOT EXISTS helpdesk.hd_asset_events (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    asset_id    text NOT NULL REFERENCES helpdesk.hd_assets (id),
    event       text NOT NULL
                CONSTRAINT hd_asset_events_event_check CHECK (event IN ('registered', 'received', 'assigned', 'unassigned', 'transferred',
                    'maintenance', 'repair', 'returned', 'retired', 'disposed', 'updated')),
    data        jsonb NOT NULL DEFAULT '{}',
    actor_id    text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE INDEX IF NOT EXISTS hd_asset_events_asset_idx ON helpdesk.hd_asset_events (asset_id, cdatetime);
DROP TRIGGER IF EXISTS hd_asset_events_append_only ON helpdesk.hd_asset_events;
CREATE TRIGGER hd_asset_events_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_asset_events
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

CREATE TABLE IF NOT EXISTS helpdesk.hd_asset_maintenance (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    asset_id         text NOT NULL REFERENCES helpdesk.hd_assets (id),
    kind             text NOT NULL CONSTRAINT hd_asset_maintenance_kind_check CHECK (kind IN ('preventive', 'corrective', 'inspection')),
    scheduled_on     date,
    done_on          date,
    notes            text,
    cost             numeric(14,2) CONSTRAINT hd_asset_maintenance_cost_amount_check CHECK (cost >= 0),
    currency         text CONSTRAINT hd_asset_maintenance_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
    vendor_party_id  text,
    ticket_id        text REFERENCES helpdesk.hd_tickets (id),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    CONSTRAINT hd_asset_maintenance_cost_check CHECK (cost IS NULL OR currency IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_asset_maintenance_asset_idx ON helpdesk.hd_asset_maintenance (asset_id, scheduled_on);

CREATE TABLE IF NOT EXISTS helpdesk.hd_licence_assignments (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    asset_id     text NOT NULL REFERENCES helpdesk.hd_assets (id),
    user_id      text NOT NULL,
    assigned_at  timestamptz NOT NULL DEFAULT now(),
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text,
    PRIMARY KEY (asset_id, user_id)
);
CREATE INDEX IF NOT EXISTS hd_licence_assignments_user_idx ON helpdesk.hd_licence_assignments (tenant_id, bus_id, user_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_assets (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    asset_id    text NOT NULL REFERENCES helpdesk.hd_assets (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (ticket_id, asset_id)
);
CREATE INDEX IF NOT EXISTS hd_ticket_assets_asset_idx ON helpdesk.hd_ticket_assets (asset_id);

-- ============================================================================== CMDB
CREATE TABLE IF NOT EXISTS helpdesk.hd_cis (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    ci_type        text NOT NULL
                   CONSTRAINT hd_cis_ci_type_check CHECK (ci_type IN ('application', 'server', 'database', 'network', 'cloud_service',
                       'business_service', 'infrastructure', 'other')),
    name           text NOT NULL,
    description    text,
    owner_user_id  text,
    team_id        text REFERENCES helpdesk.hd_teams (id),
    department_id  text REFERENCES helpdesk.hd_departments (id),
    state          text NOT NULL DEFAULT 'active'
                   CONSTRAINT hd_cis_state_check CHECK (state IN ('planned', 'active', 'maintenance', 'retired')),
    criticality    text NOT NULL DEFAULT 'medium'
                   CONSTRAINT hd_cis_criticality_check CHECK (criticality IN ('low', 'medium', 'high', 'critical')),
    attributes     jsonb NOT NULL DEFAULT '{}',
    asset_id       text REFERENCES helpdesk.hd_assets (id),
    version        int NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_cis_name_uq ON helpdesk.hd_cis (tenant_id, bus_id, lower(name), ci_type);

ALTER TABLE helpdesk.hd_assets DROP CONSTRAINT IF EXISTS hd_assets_ci_fk;
ALTER TABLE helpdesk.hd_assets ADD CONSTRAINT hd_assets_ci_fk FOREIGN KEY (ci_id) REFERENCES helpdesk.hd_cis (id);
ALTER TABLE helpdesk.hd_maintenance_windows DROP CONSTRAINT IF EXISTS hd_maintenance_windows_ci_fk;
ALTER TABLE helpdesk.hd_maintenance_windows ADD CONSTRAINT hd_maintenance_windows_ci_fk FOREIGN KEY (ci_id) REFERENCES helpdesk.hd_cis (id);
ALTER TABLE helpdesk.hd_change_cis DROP CONSTRAINT IF EXISTS hd_change_cis_ci_fk;
ALTER TABLE helpdesk.hd_change_cis ADD CONSTRAINT hd_change_cis_ci_fk FOREIGN KEY (ci_id) REFERENCES helpdesk.hd_cis (id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ci_relations (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    from_ci_id  text NOT NULL REFERENCES helpdesk.hd_cis (id),
    to_ci_id    text NOT NULL REFERENCES helpdesk.hd_cis (id),
    relation    text NOT NULL
                CONSTRAINT hd_ci_relations_relation_check CHECK (relation IN ('depends_on', 'runs_on', 'connects_to', 'hosts', 'part_of', 'uses')),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (from_ci_id, to_ci_id, relation),
    CONSTRAINT hd_ci_relations_not_self CHECK (from_ci_id <> to_ci_id)
);
-- Impact analysis walks the graph both ways.
CREATE INDEX IF NOT EXISTS hd_ci_relations_to_idx ON helpdesk.hd_ci_relations (to_ci_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_cis (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    ci_id       text NOT NULL REFERENCES helpdesk.hd_cis (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (ticket_id, ci_id)
);
CREATE INDEX IF NOT EXISTS hd_ticket_cis_ci_idx ON helpdesk.hd_ticket_cis (ci_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_problem_cis (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    problem_id  text NOT NULL REFERENCES helpdesk.hd_problems (id),
    ci_id       text NOT NULL REFERENCES helpdesk.hd_cis (id),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (problem_id, ci_id)
);
CREATE INDEX IF NOT EXISTS hd_problem_cis_ci_idx ON helpdesk.hd_problem_cis (ci_id);

-- =========================================================================== vendors
CREATE TABLE IF NOT EXISTS helpdesk.hd_vendor_profiles (
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    party_id         text NOT NULL REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
    category         text,
    account_manager  text,
    support_email    text,
    support_phone    text,
    notes            text,
    rating           int CONSTRAINT hd_vendor_profiles_rating_check CHECK (rating BETWEEN 1 AND 5),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    PRIMARY KEY (tenant_id, bus_id, party_id)
);
CREATE INDEX IF NOT EXISTS hd_vendor_profiles_party_idx ON helpdesk.hd_vendor_profiles (party_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_vendor_contracts (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    bus_id               text NOT NULL,
    party_id             text NOT NULL,
    title                text NOT NULL,
    contract_number      text,
    starts_on            date,
    ends_on              date,
    value                numeric(14,2) CONSTRAINT hd_vendor_contracts_value_check CHECK (value >= 0),
    currency             text CONSTRAINT hd_vendor_contracts_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
    renewal_notice_days  int CONSTRAINT hd_vendor_contracts_renewal_notice_check CHECK (renewal_notice_days >= 0),
    attachment_id        text REFERENCES helpdesk.hd_attachments (id),
    state                text NOT NULL DEFAULT 'draft'
                         CONSTRAINT hd_vendor_contracts_state_check CHECK (state IN ('draft', 'active', 'expired', 'terminated')),
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz,
    updated_by           text,
    CONSTRAINT hd_vendor_contracts_dates_check CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on),
    CONSTRAINT hd_vendor_contracts_value_currency_check CHECK (value IS NULL OR currency IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_vendor_contracts_party_idx ON helpdesk.hd_vendor_contracts (tenant_id, bus_id, party_id);
-- The renewal reminder reads contracts by end date.
CREATE INDEX IF NOT EXISTS hd_vendor_contracts_ends_idx ON helpdesk.hd_vendor_contracts (ends_on) WHERE state = 'active';

-- Party columns, so a party merge re-points them (20261019-29).
INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('helpdesk.hd_assets',            'vendor_party_id', false),
    ('helpdesk.hd_asset_maintenance', 'vendor_party_id', false),
    ('helpdesk.hd_vendor_contracts',  'party_id',        false),
    ('helpdesk.hd_vendor_profiles',   'party_id',        true)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_asset_events'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_asset_events is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    -- Every helpdesk column holding a party, by any name ending in party_id, is registered.
    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO missing
      FROM information_schema.columns c
     WHERE c.table_schema = 'helpdesk' AND c.column_name LIKE '%party_id'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references r
                        WHERE r.table_name = 'helpdesk.' || c.table_name AND r.column_name = c.column_name);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Help Desk party column(s) not in cp_party_references: %', missing;
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_vendor_profiles v JOIN core_platform.cp_parties p ON p.id = v.party_id
                WHERE p.tenant_id <> v.tenant_id OR p.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk vendor profile is on a party of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_vendor_contracts v JOIN core_platform.cp_parties p ON p.id = v.party_id
                WHERE p.tenant_id <> v.tenant_id OR p.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk vendor contract is with a party of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_assets a JOIN helpdesk.hd_asset_types t ON t.id = a.type_id
                WHERE t.tenant_id <> a.tenant_id OR t.bus_id <> a.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk asset has a type of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_asset_events e JOIN helpdesk.hd_assets a ON a.id = e.asset_id
                WHERE a.tenant_id <> e.tenant_id OR a.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk asset event belongs to an asset of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_cis c JOIN helpdesk.hd_assets a ON a.id = c.asset_id
                WHERE a.tenant_id <> c.tenant_id OR a.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk CI names an asset of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ci_relations r
                 JOIN helpdesk.hd_cis f ON f.id = r.from_ci_id
                 JOIN helpdesk.hd_cis t ON t.id = r.to_ci_id
                WHERE f.tenant_id <> r.tenant_id OR f.bus_id <> r.bus_id OR t.tenant_id <> r.tenant_id OR t.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk CI relation crosses businesses';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_cis l
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                 JOIN helpdesk.hd_cis c ON c.id = l.ci_id
                WHERE t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id OR c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket links a CI of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_change_cis l
                 JOIN helpdesk.hd_changes x ON x.id = l.change_id
                 JOIN helpdesk.hd_cis c ON c.id = l.ci_id
                WHERE x.tenant_id <> l.tenant_id OR x.bus_id <> l.bus_id OR c.tenant_id <> l.tenant_id OR c.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk change links a CI of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_assets l
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                 JOIN helpdesk.hd_assets a ON a.id = l.asset_id
                WHERE t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id OR a.tenant_id <> l.tenant_id OR a.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket links an asset of another business';
    END IF;
END $$;

COMMIT;
