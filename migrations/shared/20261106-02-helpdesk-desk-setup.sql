-- Help Desk R1: how a business sets up its service desk.
--
--   hd_settings            one row per business: timezone, ticket numbering, the default department,
--                          whether the portal is on, how long a requester may reopen
--   hd_departments         IT, HR, finance, facilities... (one level of parent allowed by the app)
--   hd_teams               service teams inside a department, and how they assign work
--   hd_team_members        agents and leads of a team
--   hd_statuses            the business's statuses, each in one fixed category
--   hd_status_transitions  allowed moves; no rows for a business means every move is allowed
--   hd_categories          categories and one level of subcategory, business-wide or per department
--   hd_field_defs          custom ticket fields
--
-- Also the append-only trigger function the ticket and SLA files use (hd_refuse_change): it refuses
-- UPDATE and DELETE, except the unsubscribe purge (20261028-60) of a business that no longer has
-- Help Desk, so fate PURGE (20261106-01) still works.
--
-- The rows a business starts with (Service Desk department and team, the ten statuses, a calendar
-- and an SLA policy) are created by the backend's ensureDefaults, not here: SQL does not know which
-- businesses exist. CHECK lists are defined here, inline; a later change goes in a newer file.
-- No grants: default privileges and the IaC app group handle access.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R1.md §1, §2. Idempotent; safe to re-run.

BEGIN;

CREATE SCHEMA IF NOT EXISTS helpdesk;

-- ================================================================= trigger functions
-- The business no longer has Help Desk, so the unsubscribe purge may delete its rows. With no Core
-- subscription table at all (a database without the CorePlatform module) nothing may be deleted.
CREATE OR REPLACE FUNCTION helpdesk.hd_purge_allowed(p_tenant text, p_bus text) RETURNS boolean
LANGUAGE plpgsql STABLE AS $f$
BEGIN
    IF to_regclass('core_platform.cp_business_apps') IS NULL THEN
        RETURN false;
    END IF;
    RETURN NOT EXISTS (SELECT 1 FROM core_platform.cp_business_apps
                        WHERE tenant_id = p_tenant AND bus_id = p_bus AND app_id = 'app-helpdesk'
                          AND delete_status = 'NOT_DELETED');
END
$f$;

-- Append-only: a correction is a new row.
CREATE OR REPLACE FUNCTION helpdesk.hd_refuse_change() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF TG_OP = 'DELETE' AND helpdesk.hd_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION '%.% is append-only: % is not allowed; write a new row instead',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END
$f$;

-- ===================================================================== departments
CREATE TABLE IF NOT EXISTS helpdesk.hd_departments (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    parent_id        text REFERENCES helpdesk.hd_departments (id),
    name             text NOT NULL,
    kind             text NOT NULL DEFAULT 'custom'
                     CONSTRAINT hd_departments_kind_check CHECK (kind IN ('it', 'hr', 'finance', 'procurement', 'facilities',
                         'administration', 'legal', 'security', 'customer_support', 'operations', 'custom')),
    description      text,
    manager_user_id  text,
    accepts_portal   boolean NOT NULL DEFAULT true,
    is_active        boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    CONSTRAINT hd_departments_not_own_parent CHECK (parent_id IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_departments_name_uq
    ON helpdesk.hd_departments (tenant_id, bus_id, lower(name)) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hd_departments_business_idx ON helpdesk.hd_departments (tenant_id, bus_id);

-- ========================================================================== settings
CREATE TABLE IF NOT EXISTS helpdesk.hd_settings (
    tenant_id              text NOT NULL,
    org_id                 text,
    bus_id                 text NOT NULL,
    timezone               text NOT NULL DEFAULT 'UTC',
    ticket_prefix          text NOT NULL DEFAULT 'HD',
    next_number            bigint NOT NULL DEFAULT 1 CONSTRAINT hd_settings_next_number_check CHECK (next_number >= 1),
    default_department_id  text REFERENCES helpdesk.hd_departments (id),
    portal_enabled         boolean NOT NULL DEFAULT true,
    reopen_days            int NOT NULL DEFAULT 7 CONSTRAINT hd_settings_reopen_days_check CHECK (reopen_days >= 0),
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz,
    updated_by             text,
    PRIMARY KEY (tenant_id, bus_id)
);

-- ============================================================================= teams
CREATE TABLE IF NOT EXISTS helpdesk.hd_teams (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    department_id    text NOT NULL REFERENCES helpdesk.hd_departments (id),
    name             text NOT NULL,
    description      text,
    assignment_mode  text NOT NULL DEFAULT 'manual'
                     CONSTRAINT hd_teams_assignment_mode_check CHECK (assignment_mode IN ('manual', 'round_robin', 'load_balanced')),
    is_active        boolean NOT NULL DEFAULT true,
    archived_at      timestamptz,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_teams_name_uq
    ON helpdesk.hd_teams (tenant_id, bus_id, department_id, lower(name)) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS helpdesk.hd_team_members (
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    team_id           text NOT NULL REFERENCES helpdesk.hd_teams (id),
    user_id           text NOT NULL,
    member_role       text NOT NULL DEFAULT 'agent'
                      CONSTRAINT hd_team_members_member_role_check CHECK (member_role IN ('agent', 'lead')),
    last_assigned_at  timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text,
    PRIMARY KEY (team_id, user_id)
);
CREATE INDEX IF NOT EXISTS hd_team_members_user_idx ON helpdesk.hd_team_members (tenant_id, bus_id, user_id);

-- ========================================================================== statuses
CREATE TABLE IF NOT EXISTS helpdesk.hd_statuses (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL,
    category    text NOT NULL
                CONSTRAINT hd_statuses_category_check CHECK (category IN ('new', 'open', 'pending', 'on_hold', 'resolved', 'closed', 'cancelled')),
    position    int NOT NULL DEFAULT 0,
    is_default  boolean NOT NULL DEFAULT false,
    pauses_sla  boolean NOT NULL DEFAULT false,
    is_active   boolean NOT NULL DEFAULT true,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_statuses_name_uq ON helpdesk.hd_statuses (tenant_id, bus_id, lower(name));
-- At most one default status per category per business (R1 §1 invariant), enforced on every write.
CREATE UNIQUE INDEX IF NOT EXISTS hd_statuses_one_default_uq
    ON helpdesk.hd_statuses (tenant_id, bus_id, category) WHERE is_default;

CREATE TABLE IF NOT EXISTS helpdesk.hd_status_transitions (
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    from_status_id  text NOT NULL REFERENCES helpdesk.hd_statuses (id),
    to_status_id    text NOT NULL REFERENCES helpdesk.hd_statuses (id),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz,
    updated_by      text,
    PRIMARY KEY (tenant_id, bus_id, from_status_id, to_status_id)
);

-- ======================================================================== categories
CREATE TABLE IF NOT EXISTS helpdesk.hd_categories (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    department_id  text REFERENCES helpdesk.hd_departments (id),
    parent_id      text REFERENCES helpdesk.hd_categories (id),
    name           text NOT NULL,
    position       int NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text,
    CONSTRAINT hd_categories_not_own_parent CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS hd_categories_business_idx ON helpdesk.hd_categories (tenant_id, bus_id, department_id);

-- A subcategory is one level deep: its parent has no parent, and a category with children gets none.
CREATE OR REPLACE FUNCTION helpdesk.hd_categories_one_level() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM helpdesk.hd_categories c WHERE c.id = NEW.parent_id AND c.parent_id IS NOT NULL) THEN
            RAISE EXCEPTION 'hd_categories: a subcategory cannot have subcategories' USING ERRCODE = 'check_violation';
        END IF;
        IF EXISTS (SELECT 1 FROM helpdesk.hd_categories c WHERE c.parent_id = NEW.id) THEN
            RAISE EXCEPTION 'hd_categories: a category with subcategories cannot become one' USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END
$f$;
DROP TRIGGER IF EXISTS hd_categories_one_level ON helpdesk.hd_categories;
CREATE TRIGGER hd_categories_one_level BEFORE INSERT OR UPDATE OF parent_id ON helpdesk.hd_categories
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_categories_one_level();

-- ===================================================================== custom fields
CREATE TABLE IF NOT EXISTS helpdesk.hd_field_defs (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    bus_id                text NOT NULL,
    department_id         text REFERENCES helpdesk.hd_departments (id),
    key                   text NOT NULL CONSTRAINT hd_field_defs_key_check CHECK (key ~ '^[a-z][a-z0-9_]{1,40}$'),
    label                 text NOT NULL,
    field_type            text NOT NULL
                          CONSTRAINT hd_field_defs_field_type_check CHECK (field_type IN ('text', 'textarea', 'number', 'date',
                              'datetime', 'select', 'multiselect', 'checkbox', 'user')),
    options               jsonb NOT NULL DEFAULT '[]',
    is_required           boolean NOT NULL DEFAULT false,
    visible_to_requester  boolean NOT NULL DEFAULT false,
    position              int NOT NULL DEFAULT 0,
    is_active             boolean NOT NULL DEFAULT true,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz,
    updated_by            text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_field_defs_key_uq ON helpdesk.hd_field_defs (tenant_id, bus_id, key);

-- ===================================================================== invariants
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_statuses_one_default_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_statuses has no one-default-per-category index';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_statuses WHERE is_default
                GROUP BY tenant_id, bus_id, category HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a business has more than one default Help Desk status in a category';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_teams t JOIN helpdesk.hd_departments d ON d.id = t.department_id
                WHERE d.tenant_id <> t.tenant_id OR d.bus_id <> t.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk team belongs to a department of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_team_members m JOIN helpdesk.hd_teams t ON t.id = m.team_id
                WHERE t.tenant_id <> m.tenant_id OR t.bus_id <> m.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk team member row names a team of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_categories c JOIN helpdesk.hd_categories p ON p.id = c.parent_id
                WHERE p.parent_id IS NOT NULL) THEN
        RAISE EXCEPTION 'a Help Desk subcategory has subcategories';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'helpdesk' AND table_name IN ('hd_settings', 'hd_team_members', 'hd_status_transitions')
                  AND column_name = 'id') THEN
        RAISE EXCEPTION 'a Help Desk table keyed by its natural key has grown an id column';
    END IF;
END $$;

COMMIT;
