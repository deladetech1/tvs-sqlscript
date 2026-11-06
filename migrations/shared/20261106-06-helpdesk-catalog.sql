-- Help Desk R2: the service catalogue.
--
--   hd_catalog_sections     how the catalogue is grouped, business-wide or per department
--   hd_catalog_items        what can be requested: its department, fulfilment team, ticket defaults,
--                           cost, approval policy, who may see it, and its current form version
--   hd_catalog_eligibility  who may request an item; any matching rule makes the caller eligible
--   hd_form_versions        the request form of an item, versioned. Immutable: a change is a new
--                           version (its own trigger; see below)
--   hd_ticket_requests      a ticket raised from the catalogue: the item, the form version answered,
--                           the answers, the cost and where its approval stands
--   hd_cost_centres         cost centres a ticket can be charged to
--   hd_tickets.cost_centre_id
--
-- The FK from hd_catalog_items.approval_policy_id is added in 20261106-07, which creates the
-- policies. CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R2.md §3. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== sections
CREATE TABLE IF NOT EXISTS helpdesk.hd_catalog_sections (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    department_id  text REFERENCES helpdesk.hd_departments (id),
    name           text NOT NULL,
    description    text,
    position       int NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE INDEX IF NOT EXISTS hd_catalog_sections_business_idx ON helpdesk.hd_catalog_sections (tenant_id, bus_id, position);

-- ============================================================================= items
CREATE TABLE IF NOT EXISTS helpdesk.hd_catalog_items (
    id                       text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                text NOT NULL,
    bus_id                   text NOT NULL,
    department_id            text NOT NULL REFERENCES helpdesk.hd_departments (id),
    section_id               text REFERENCES helpdesk.hd_catalog_sections (id),
    name                     text NOT NULL,
    short_description        text,
    description              text,
    icon                     text,
    owner_user_id            text,
    team_id                  text REFERENCES helpdesk.hd_teams (id),
    ticket_type              text NOT NULL DEFAULT 'request'
                             CONSTRAINT hd_catalog_items_ticket_type_check CHECK (ticket_type IN ('request', 'incident', 'question')),
    category_id              text REFERENCES helpdesk.hd_categories (id),
    default_priority         text NOT NULL DEFAULT 'medium'
                             CONSTRAINT hd_catalog_items_default_priority_check CHECK (default_priority IN ('low', 'medium', 'high', 'urgent')),
    expected_minutes         int CONSTRAINT hd_catalog_items_expected_minutes_check CHECK (expected_minutes > 0),
    cost_amount              numeric(14,2) CONSTRAINT hd_catalog_items_cost_amount_check CHECK (cost_amount >= 0),
    cost_currency            text CONSTRAINT hd_catalog_items_cost_currency_check CHECK (cost_currency ~ '^[A-Z][A-Z][A-Z]$'),
    approval_policy_id       text,
    visibility               text NOT NULL DEFAULT 'everyone'
                             CONSTRAINT hd_catalog_items_visibility_check CHECK (visibility IN ('everyone', 'eligible', 'agents_only')),
    current_form_version_id  text,
    is_active                boolean NOT NULL DEFAULT true,
    archived_at              timestamptz,
    cdatetime                timestamptz NOT NULL DEFAULT now(),
    created_by               text,
    updated_at               timestamptz,
    updated_by               text,
    CONSTRAINT hd_catalog_items_cost_check CHECK (cost_amount IS NULL OR cost_currency IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_catalog_items_business_idx ON helpdesk.hd_catalog_items (tenant_id, bus_id, department_id);
CREATE INDEX IF NOT EXISTS hd_catalog_items_section_idx ON helpdesk.hd_catalog_items (section_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_catalog_eligibility (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    item_id     text NOT NULL REFERENCES helpdesk.hd_catalog_items (id),
    rule_type   text NOT NULL
                CONSTRAINT hd_catalog_eligibility_rule_type_check CHECK (rule_type IN ('location', 'group', 'department_member', 'role')),
    ref_id      text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (item_id, rule_type, ref_id)
);

-- ===================================================================== form versions
CREATE TABLE IF NOT EXISTS helpdesk.hd_form_versions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    item_id       text NOT NULL REFERENCES helpdesk.hd_catalog_items (id),
    version       int NOT NULL CONSTRAINT hd_form_versions_version_check CHECK (version >= 1),
    schema        jsonb NOT NULL,
    published_at  timestamptz,
    published_by  text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,
    updated_at    timestamptz,
    updated_by    text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_form_versions_version_uq ON helpdesk.hd_form_versions (item_id, version);

-- Immutable, with two exceptions: the unsubscribe purge may delete (hd_purge_allowed), and a version
-- written without publication may be published once (published_at and published_by go from NULL to
-- a value; updated_at and updated_by may move with them). Nothing else ever changes.
CREATE OR REPLACE FUNCTION helpdesk.hd_form_versions_immutable() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF helpdesk.hd_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
            RETURN OLD;
        END IF;
    ELSIF OLD.published_at IS NULL AND NEW.published_at IS NOT NULL
          AND row(NEW.id, NEW.tenant_id, NEW.bus_id, NEW.item_id, NEW.version, NEW.schema, NEW.cdatetime, NEW.created_by)
              IS NOT DISTINCT FROM
              row(OLD.id, OLD.tenant_id, OLD.bus_id, OLD.item_id, OLD.version, OLD.schema, OLD.cdatetime, OLD.created_by) THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'hd_form_versions is immutable: % is not allowed; write a new version instead', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;
DROP TRIGGER IF EXISTS hd_form_versions_immutable ON helpdesk.hd_form_versions;
CREATE TRIGGER hd_form_versions_immutable BEFORE UPDATE OR DELETE ON helpdesk.hd_form_versions
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_form_versions_immutable();

-- The item table came first; its current form is tied here, where the versions exist.
ALTER TABLE helpdesk.hd_catalog_items DROP CONSTRAINT IF EXISTS hd_catalog_items_current_form_version_fk;
ALTER TABLE helpdesk.hd_catalog_items ADD CONSTRAINT hd_catalog_items_current_form_version_fk
    FOREIGN KEY (current_form_version_id) REFERENCES helpdesk.hd_form_versions (id);

-- ===================================================================== cost centres
CREATE TABLE IF NOT EXISTS helpdesk.hd_cost_centres (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    code           text NOT NULL,
    name           text NOT NULL,
    department_id  text REFERENCES helpdesk.hd_departments (id),
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_cost_centres_code_uq ON helpdesk.hd_cost_centres (tenant_id, bus_id, lower(code));

ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS cost_centre_id text REFERENCES helpdesk.hd_cost_centres (id);

-- =================================================================== ticket requests
CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_requests (
    ticket_id        text PRIMARY KEY REFERENCES helpdesk.hd_tickets (id),
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    item_id          text NOT NULL REFERENCES helpdesk.hd_catalog_items (id),
    form_version_id  text REFERENCES helpdesk.hd_form_versions (id),
    answers          jsonb NOT NULL DEFAULT '{}',
    cost_amount      numeric(14,2) CONSTRAINT hd_ticket_requests_cost_amount_check CHECK (cost_amount >= 0),
    cost_currency    text CONSTRAINT hd_ticket_requests_cost_currency_check CHECK (cost_currency ~ '^[A-Z][A-Z][A-Z]$'),
    approval_state   text NOT NULL DEFAULT 'not_required'
                     CONSTRAINT hd_ticket_requests_approval_state_check CHECK (approval_state IN ('not_required', 'pending', 'approved', 'rejected', 'cancelled')),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    CONSTRAINT hd_ticket_requests_cost_check CHECK (cost_amount IS NULL OR cost_currency IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_ticket_requests_item_idx ON helpdesk.hd_ticket_requests (tenant_id, bus_id, item_id);

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_form_versions'::regclass AND p.proname = 'hd_form_versions_immutable'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_form_versions is not immutable: its trigger on UPDATE and DELETE is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_catalog_items i JOIN helpdesk.hd_departments d ON d.id = i.department_id
                WHERE d.tenant_id <> i.tenant_id OR d.bus_id <> i.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk catalogue item belongs to a department of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_catalog_items i JOIN helpdesk.hd_form_versions v ON v.id = i.current_form_version_id
                WHERE v.item_id <> i.id) THEN
        RAISE EXCEPTION 'a Help Desk catalogue item points at a form version of another item';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_form_versions v JOIN helpdesk.hd_catalog_items i ON i.id = v.item_id
                WHERE i.tenant_id <> v.tenant_id OR i.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk form version belongs to an item of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_catalog_eligibility e JOIN helpdesk.hd_catalog_items i ON i.id = e.item_id
                WHERE i.tenant_id <> e.tenant_id OR i.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk eligibility rule belongs to an item of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_requests r
                 JOIN helpdesk.hd_tickets t ON t.id = r.ticket_id
                 JOIN helpdesk.hd_catalog_items i ON i.id = r.item_id
                WHERE t.tenant_id <> r.tenant_id OR t.bus_id <> r.bus_id OR i.tenant_id <> r.tenant_id OR i.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket request mixes a ticket or item of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tickets t JOIN helpdesk.hd_cost_centres c ON c.id = t.cost_centre_id
                WHERE c.tenant_id <> t.tenant_id OR c.bus_id <> t.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket is charged to a cost centre of another business';
    END IF;
END $$;

COMMIT;
