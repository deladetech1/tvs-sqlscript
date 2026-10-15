-- CRM release 1: customers.
--
-- Contacts and companies, their phones and emails, tags, a business's own custom
-- fields, consent per channel, saved segments, an audit trail, and the sync that
-- brings MyStoreGuard customers and LoanDrift clients in.
--
-- Scope: every row carries tenant_id, org_id and bus_id. A CRM belongs to a business,
-- the same unit MyStoreGuard customers and LoanDrift clients belong to.
--
-- The sync (shared apps backend, every five minutes, per business that turned it on)
-- reads crm.src_mystoreguard_customers and crm.src_loandrift_clients -- views, so the
-- CRM's contract with the other apps is a few named columns here, and a change to
-- their tables that breaks it fails this migration on deploy rather than the sync at
-- three in the morning. Neither source table records when a row last changed, so the
-- views carry a fingerprint (row_hash) and the sync rewrites only rows whose
-- fingerprint moved since crm_contact_sources.source_hash.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE SCHEMA IF NOT EXISTS crm;

-- ============================================================================ contacts
CREATE TABLE IF NOT EXISTS crm.crm_contacts (
    id              text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    first_name      text,
    middle_names    text,
    last_name       text,
    -- Always set: what lists, search and messages call the person.
    full_name       text        NOT NULL,
    title           text,
    gender          text,
    date_of_birth   date,
    job_title       text,
    -- The company the person is mainly associated with (crm_contact_companies has all).
    company_id      text,

    -- Mirrors of the primary crm_contact_points rows, so lists and search do not
    -- join for every row. The points table is the record.
    primary_email   text,
    primary_phone   text,

    address_line    text,
    city            text,
    region          text,
    country         text,

    -- manual | import | mystoreguard | loandrift | web_form | ...
    source          text        NOT NULL DEFAULT 'manual',
    owner_user_id   text,
    -- active | archived
    status          text        NOT NULL DEFAULT 'active',
    notes           text,
    -- Values of the business's custom fields, keyed by crm_custom_fields.field_key.
    custom          jsonb       NOT NULL DEFAULT '{}'::jsonb,

    -- Set when this contact was merged into another; the survivor holds the data.
    merged_into_id  text,

    is_active       boolean     NOT NULL DEFAULT true,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by      text,
    updated_by      text,
    deleted_by      text,
    cdate           text        DEFAULT CURRENT_DATE::text,
    ctime           text        DEFAULT CURRENT_TIME::text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_contacts_scope   ON crm.crm_contacts (tenant_id, bus_id, delete_status);
CREATE INDEX IF NOT EXISTS ix_crm_contacts_owner   ON crm.crm_contacts (tenant_id, owner_user_id);
CREATE INDEX IF NOT EXISTS ix_crm_contacts_email   ON crm.crm_contacts (tenant_id, lower(primary_email));
CREATE INDEX IF NOT EXISTS ix_crm_contacts_phone   ON crm.crm_contacts (tenant_id, primary_phone);
CREATE INDEX IF NOT EXISTS ix_crm_contacts_name    ON crm.crm_contacts (tenant_id, lower(full_name));
CREATE INDEX IF NOT EXISTS ix_crm_contacts_company ON crm.crm_contacts (company_id);

-- Every phone, email and WhatsApp number a contact has.
CREATE TABLE IF NOT EXISTS crm.crm_contact_points (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    contact_id  text        NOT NULL REFERENCES crm.crm_contacts(id) ON DELETE CASCADE,
    -- phone | email | whatsapp
    kind        text        NOT NULL,
    value       text        NOT NULL,
    -- Lower-cased email, or digits-only phone, for matching duplicates and syncs.
    normalized  text        NOT NULL,
    -- mobile | work | home | other
    label       text,
    is_primary  boolean     NOT NULL DEFAULT false,
    source      text        NOT NULL DEFAULT 'manual',
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_contact_points_kind CHECK (kind IN ('phone', 'email', 'whatsapp'))
);
CREATE INDEX IF NOT EXISTS ix_crm_contact_points_contact ON crm.crm_contact_points (contact_id);
CREATE INDEX IF NOT EXISTS ix_crm_contact_points_match   ON crm.crm_contact_points (tenant_id, kind, normalized);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_contact_points_value ON crm.crm_contact_points (contact_id, kind, normalized);

-- =========================================================================== companies
CREATE TABLE IF NOT EXISTS crm.crm_companies (
    id              text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    name            text        NOT NULL,
    industry        text,
    website         text,
    email           text,
    phone           text,
    address_line    text,
    city            text,
    region          text,
    country         text,
    -- micro | small | medium | large
    size            text,
    owner_user_id   text,
    status          text        NOT NULL DEFAULT 'active',
    notes           text,
    custom          jsonb       NOT NULL DEFAULT '{}'::jsonb,
    is_active       boolean     NOT NULL DEFAULT true,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by      text,
    updated_by      text,
    deleted_by      text,
    cdate           text        DEFAULT CURRENT_DATE::text,
    ctime           text        DEFAULT CURRENT_TIME::text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_companies_scope ON crm.crm_companies (tenant_id, bus_id, delete_status);
CREATE INDEX IF NOT EXISTS ix_crm_companies_name  ON crm.crm_companies (tenant_id, lower(name));

CREATE TABLE IF NOT EXISTS crm.crm_contact_companies (
    tenant_id   text        NOT NULL,
    contact_id  text        NOT NULL REFERENCES crm.crm_contacts(id) ON DELETE CASCADE,
    company_id  text        NOT NULL REFERENCES crm.crm_companies(id) ON DELETE CASCADE,
    role        text,
    is_primary  boolean     NOT NULL DEFAULT false,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (contact_id, company_id)
);
CREATE INDEX IF NOT EXISTS ix_crm_contact_companies_company ON crm.crm_contact_companies (company_id);

-- ================================================================================ tags
CREATE TABLE IF NOT EXISTS crm.crm_tags (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    bus_id      text        NOT NULL,
    name        text        NOT NULL,
    color       text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_tags_name ON crm.crm_tags (tenant_id, bus_id, lower(name));

CREATE TABLE IF NOT EXISTS crm.crm_entity_tags (
    tenant_id    text        NOT NULL,
    tag_id       text        NOT NULL REFERENCES crm.crm_tags(id) ON DELETE CASCADE,
    -- contact | company
    entity_type  text        NOT NULL,
    entity_id    text        NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tag_id, entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS ix_crm_entity_tags_entity ON crm.crm_entity_tags (entity_type, entity_id);

-- ======================================================================= custom fields
CREATE TABLE IF NOT EXISTS crm.crm_custom_fields (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    bus_id       text        NOT NULL,
    -- contact | company
    entity_type  text        NOT NULL,
    -- Stable key the values are stored under in <entity>.custom. Never reused.
    field_key    text        NOT NULL,
    label        text        NOT NULL,
    -- text | long_text | number | date | boolean | select | multi_select | phone | email | url
    field_type   text        NOT NULL,
    -- Choices for select and multi_select: ["Gold", "Silver"].
    options      jsonb       NOT NULL DEFAULT '[]'::jsonb,
    is_required  boolean     NOT NULL DEFAULT false,
    position     integer     NOT NULL DEFAULT 0,
    is_active    boolean     NOT NULL DEFAULT true,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    CONSTRAINT ck_crm_custom_fields_type CHECK (field_type IN
        ('text', 'long_text', 'number', 'date', 'boolean', 'select', 'multi_select', 'phone', 'email', 'url'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_custom_fields_key ON crm.crm_custom_fields (tenant_id, bus_id, entity_type, field_key);

-- ============================================================================= consent
-- A history, not a flag: the current answer per channel is the latest row. The Data
-- Protection Act question is "when did they agree, and how", which a boolean cannot answer.
CREATE TABLE IF NOT EXISTS crm.crm_consents (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    contact_id   text        NOT NULL REFERENCES crm.crm_contacts(id) ON DELETE CASCADE,
    -- sms | email | whatsapp | call
    channel      text        NOT NULL,
    -- opted_in | opted_out
    status       text        NOT NULL,
    -- How it was given: form, verbal, import, reply_stop, ...
    method       text,
    note         text,
    recorded_by  text,
    recorded_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_consents_channel CHECK (channel IN ('sms', 'email', 'whatsapp', 'call')),
    CONSTRAINT ck_crm_consents_status  CHECK (status IN ('opted_in', 'opted_out'))
);
CREATE INDEX IF NOT EXISTS ix_crm_consents_latest ON crm.crm_consents (contact_id, channel, recorded_at DESC);

-- ============================================================================ segments
CREATE TABLE IF NOT EXISTS crm.crm_segments (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    bus_id       text        NOT NULL,
    name         text        NOT NULL,
    description  text,
    -- The saved filter; members are computed when the segment is read, so they never go stale.
    filters      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    is_shared    boolean     NOT NULL DEFAULT true,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_segments_scope ON crm.crm_segments (tenant_id, bus_id);

-- ============================================================================ timeline
CREATE TABLE IF NOT EXISTS crm.crm_timeline_events (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    bus_id       text        NOT NULL,
    contact_id   text        NOT NULL,
    -- created | updated | merged | synced | note | consent | tag | ...
    kind         text        NOT NULL,
    title        text        NOT NULL,
    detail       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    actor_id     text,
    occurred_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_timeline_contact ON crm.crm_timeline_events (contact_id, occurred_at DESC);

-- ========================================================================== audit logs
-- Named *_audit_logs with tenant_id and cdatetime so activity-log retention finds it.
CREATE TABLE IF NOT EXISTS crm.crm_audit_logs (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    org_id       text,
    bus_id       text,
    entity_type  text        NOT NULL,
    entity_id    text        NOT NULL,
    action       text        NOT NULL,
    changes      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    actor_id     text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_audit_logs_entity ON crm.crm_audit_logs (tenant_id, entity_type, entity_id, cdatetime DESC);

-- ================================================================================ sync
-- Which source record each contact came from. One contact may have several (a shop
-- customer who is also a borrower, merged), and one source record maps to one contact.
CREATE TABLE IF NOT EXISTS crm.crm_contact_sources (
    id              text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text        NOT NULL,
    bus_id          text        NOT NULL,
    contact_id      text        NOT NULL REFERENCES crm.crm_contacts(id) ON DELETE CASCADE,
    -- mystoreguard | loandrift
    source_app      text        NOT NULL,
    source_id       text        NOT NULL,
    -- The source row's fingerprint at the last sync; a different one means it changed.
    source_hash     text,
    -- The values last copied from the source. A field is overwritten by the next sync
    -- only while the contact still holds this value -- an edit made in the CRM wins.
    last_synced     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    last_synced_at  timestamptz,
    -- The source deleted or deactivated it. The CRM contact is kept; only the link is marked.
    source_removed  boolean     NOT NULL DEFAULT false,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_contact_sources_app CHECK (source_app IN ('mystoreguard', 'loandrift'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_contact_sources_record ON crm.crm_contact_sources (tenant_id, source_app, source_id);
CREATE INDEX IF NOT EXISTS ix_crm_contact_sources_contact ON crm.crm_contact_sources (contact_id);

-- A business's switch per source, and how the last run went.
CREATE TABLE IF NOT EXISTS crm.crm_sync_settings (
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    source_app      text        NOT NULL,
    enabled         boolean     NOT NULL DEFAULT false,
    -- Who to make the owner of contacts the sync creates; NULL leaves them unowned.
    default_owner_user_id text,
    last_run_at     timestamptz,
    -- ok | error | running
    last_status     text,
    last_error      text,
    last_created    integer     NOT NULL DEFAULT 0,
    last_updated    integer     NOT NULL DEFAULT 0,
    last_removed    integer     NOT NULL DEFAULT 0,
    total_linked    integer     NOT NULL DEFAULT 0,
    updated_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id, source_app),
    CONSTRAINT ck_crm_sync_settings_app CHECK (source_app IN ('mystoreguard', 'loandrift'))
);

-- ======================================================================== import jobs
CREATE TABLE IF NOT EXISTS crm.crm_imports (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    org_id       text        NOT NULL,
    bus_id       text        NOT NULL,
    entity_type  text        NOT NULL DEFAULT 'contact',
    file_name    text,
    -- pending | running | completed | failed
    status       text        NOT NULL DEFAULT 'pending',
    total_rows   integer     NOT NULL DEFAULT 0,
    created_rows integer     NOT NULL DEFAULT 0,
    updated_rows integer     NOT NULL DEFAULT 0,
    skipped_rows integer     NOT NULL DEFAULT 0,
    errors       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    created_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    finished_at  timestamptz
);

-- A date from free text, or NULL. LoanDrift's dob is text; a cast that fails on one row
-- ("2023-02-30") would fail the whole view, and with it the sync for every client.
CREATE OR REPLACE FUNCTION crm.try_date(value text) RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $f$
BEGIN
    IF value IS NULL OR value !~ '^\d{4}-\d{2}-\d{2}' THEN
        RETURN NULL;
    END IF;
    RETURN left(value, 10)::date;
EXCEPTION WHEN others THEN
    RETURN NULL;
END $f$;

-- =================================================================== sync source views
-- Only created where the source app's tables exist: an enterprise or silo database
-- without one simply has no view, and the sync skips that source there.
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_customers') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_mystoreguard_customers AS
        SELECT c.tenant_id, c.org_id, c.bus_id,
               c.id                                         AS source_id,
               c.fullname                                   AS full_name,
               NULLIF(btrim(c.contact), '')                 AS phone,
               NULLIF(lower(btrim(c.email)), '')            AS email,
               NULLIF(btrim(c.address), '')                 AS address_line,
               NULLIF(btrim(c.gender), '')                  AS gender,
               c.date_of_birth                              AS date_of_birth,
               COALESCE((SELECT array_agg(DISTINCT cc.value ORDER BY cc.value)
                           FROM mystoreguard.msg_customer_contacts cc
                          WHERE cc.customer_id = c.id AND cc.tenant_id = c.tenant_id AND cc.kind = 'phone'),
                        ARRAY[]::text[])                    AS extra_phones,
               COALESCE((SELECT array_agg(DISTINCT lower(cc.value) ORDER BY lower(cc.value))
                           FROM mystoreguard.msg_customer_contacts cc
                          WHERE cc.customer_id = c.id AND cc.tenant_id = c.tenant_id AND cc.kind = 'email'),
                        ARRAY[]::text[])                    AS extra_emails,
               (c.delete_status <> 'NOT_DELETED' OR c.is_active IS FALSE) AS is_removed
          FROM mystoreguard.msg_customers c
        $v$;
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_mystoreguard_customers_hashed AS
        SELECT s.*, md5(row(s.full_name, s.phone, s.email, s.address_line, s.gender, s.date_of_birth,
                            s.extra_phones, s.extra_emails, s.is_removed)::text) AS row_hash
          FROM crm.src_mystoreguard_customers s
        $v$;
    END IF;

    IF to_regclass('loandrift.ld_clients') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_loandrift_clients AS
        SELECT c.tenant_id, c.org_id, c.bus_id,
               c.id                                         AS source_id,
               c.fullname                                   AS full_name,
               NULLIF(btrim(c.first_name), '')              AS first_name,
               NULLIF(btrim(c.middle_names), '')            AS middle_names,
               NULLIF(btrim(c.surname), '')                 AS last_name,
               NULLIF(btrim(c.title), '')                   AS title,
               NULLIF(btrim(c.contact), '')                 AS phone,
               NULLIF(lower(btrim(c.email)), '')            AS email,
               NULLIF(btrim(c.residential_address), '')     AS address_line,
               NULLIF(btrim(c.gender), '')                  AS gender,
               -- dob is free text in LoanDrift; only an ISO date is carried over.
               crm.try_date(c.dob)                          AS date_of_birth,
               NULLIF(btrim(c.occupation), '')              AS job_title,
               COALESCE(c.contacts, ARRAY[]::text[])        AS extra_phones,
               ARRAY[]::text[]                              AS extra_emails,
               (c.delete_status <> 'NOT_DELETED' OR c.is_active IS FALSE) AS is_removed
          FROM loandrift.ld_clients c
        $v$;
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_loandrift_clients_hashed AS
        SELECT s.*, md5(row(s.full_name, s.first_name, s.middle_names, s.last_name, s.title, s.phone,
                            s.email, s.address_line, s.gender, s.date_of_birth, s.job_title,
                            s.extra_phones, s.is_removed)::text) AS row_hash
          FROM crm.src_loandrift_clients s
        $v$;
    END IF;
END $$;

-- ===================================================================== permissions
-- Verbs the CRM needs that the catalogue did not have. Read-only where they change nothing;
-- export is a read, but not a default for viewers: a whole customer list leaving the building
-- is a decision, not a glance.
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('export', 'Export', true,  false),
('import', 'Import', false, false),
('merge',  'Merge',  false, false)
ON CONFLICT (action) DO NOTHING;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-contacts',      'CRM Contacts',      'People the business deals with',             'rt-subscribed-app-crm'),
('rt-crm-companies',     'CRM Companies',     'Businesses the contacts work for',           'rt-subscribed-app-crm'),
('rt-crm-tags',          'CRM Tags',          'Labels on contacts and companies',           'rt-subscribed-app-crm'),
('rt-crm-custom-fields', 'CRM Custom Fields', 'The business''s own fields',                 'rt-subscribed-app-crm'),
('rt-crm-segments',      'CRM Segments',      'Saved groups of contacts',                   'rt-subscribed-app-crm'),
('rt-crm-sync',          'CRM Sync',          'Bringing in MyStoreGuard and LoanDrift customers', 'rt-subscribed-app-crm'),
('rt-crm-logs',          'CRM Logs',          'The CRM''s audit trail',                     'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('contacts', 'rt-crm-contacts', 'get',    'View contacts'),
    ('contacts', 'rt-crm-contacts', 'create', 'Create contacts'),
    ('contacts', 'rt-crm-contacts', 'update', 'Edit contacts'),
    ('contacts', 'rt-crm-contacts', 'delete', 'Delete contacts'),
    ('contacts', 'rt-crm-contacts', 'import', 'Import contacts'),
    ('contacts', 'rt-crm-contacts', 'export', 'Export contacts'),
    ('contacts', 'rt-crm-contacts', 'merge',  'Merge duplicate contacts'),
    ('contacts', 'rt-crm-contacts', 'assign', 'Change who owns a contact'),
    ('companies', 'rt-crm-companies', 'get',    'View companies'),
    ('companies', 'rt-crm-companies', 'create', 'Create companies'),
    ('companies', 'rt-crm-companies', 'update', 'Edit companies'),
    ('companies', 'rt-crm-companies', 'delete', 'Delete companies'),
    ('tags', 'rt-crm-tags', 'get',    'View tags'),
    ('tags', 'rt-crm-tags', 'manage', 'Create, rename and delete tags'),
    ('custom-fields', 'rt-crm-custom-fields', 'get',    'View custom fields'),
    ('custom-fields', 'rt-crm-custom-fields', 'manage', 'Define custom fields'),
    ('segments', 'rt-crm-segments', 'get',    'View segments'),
    ('segments', 'rt-crm-segments', 'create', 'Create segments'),
    ('segments', 'rt-crm-segments', 'update', 'Edit segments'),
    ('segments', 'rt-crm-segments', 'delete', 'Delete segments'),
    ('sync', 'rt-crm-sync', 'get',    'View customer sync'),
    ('sync', 'rt-crm-sync', 'manage', 'Turn customer sync on or off'),
    ('logs', 'rt-crm-logs', 'get',    'View the CRM audit trail')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-crm-' || spec.resource_key || '-' || spec.action,
       'CRM ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair every package checks: crm|<resource>|<action>||any.
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'crm',
       resource_key = substring(p.id FROM '^permission-crm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-crm-%'
   AND (p.app_prefix IS DISTINCT FROM 'crm' OR p.action IS NULL);

-- ========================================================================== roles
-- Allowed by being the role: CRM Admin (20261015-01). These two carry explicit grants.
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-crm-user',   'system-tenant-id', 'CRM User',   'Works with contacts and companies: view, create, edit, tag, segment', 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-crm-viewer', 'system-tenant-id', 'CRM Viewer', 'Reads contacts, companies and segments; changes nothing',            'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system,
                               is_active = EXCLUDED.is_active;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
    ('role-crm-user', 'contacts', 'get'), ('role-crm-user', 'contacts', 'create'), ('role-crm-user', 'contacts', 'update'),
    ('role-crm-user', 'contacts', 'merge'), ('role-crm-user', 'companies', 'get'), ('role-crm-user', 'companies', 'create'),
    ('role-crm-user', 'companies', 'update'), ('role-crm-user', 'tags', 'get'), ('role-crm-user', 'tags', 'manage'),
    ('role-crm-user', 'custom-fields', 'get'), ('role-crm-user', 'segments', 'get'), ('role-crm-user', 'segments', 'create'),
    ('role-crm-user', 'segments', 'update'), ('role-crm-user', 'sync', 'get'),
    ('role-crm-viewer', 'contacts', 'get'), ('role-crm-viewer', 'companies', 'get'), ('role-crm-viewer', 'tags', 'get'),
    ('role-crm-viewer', 'custom-fields', 'get'), ('role-crm-viewer', 'segments', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- The core-platform navigation block every app role seeds for itself.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id IN ('role-crm-user', 'role-crm-viewer')
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE missing int; unheld int;
BEGIN
    -- Every CRM permission is named by its pair (what the packages check).
    SELECT count(*) INTO missing FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-crm-%' AND (app_prefix <> 'crm' OR resource_key IS NULL OR action IS NULL);
    IF missing > 0 THEN
        RAISE EXCEPTION '% CRM permission(s) have no pair; nothing would match them', missing;
    END IF;
    -- A viewer changes nothing.
    SELECT count(*) INTO unheld FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-crm-viewer' AND p.app_prefix = 'crm' AND NOT a.is_read_only;
    IF unheld > 0 THEN
        RAISE EXCEPTION 'role-crm-viewer holds % CRM permission(s) that change data', unheld;
    END IF;
    -- CRM Admin is allowed by being the role and must hold no CRM rows.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-crm-admin' AND permission_id LIKE 'permission-crm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-crm-admin holds CRM permission rows';
    END IF;
END $$;

COMMIT;
