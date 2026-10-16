-- CRM: companies become Accounts, in the Zoho sense -- the organisations the business sells to,
-- with a type, a head office above its branches, and billing and shipping addresses.
-- The existing address columns are the billing address.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE crm.crm_companies
    ADD COLUMN IF NOT EXISTS parent_id              text REFERENCES crm.crm_companies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS account_type           text,
    ADD COLUMN IF NOT EXISTS account_number         text,
    ADD COLUMN IF NOT EXISTS rating                 text,
    ADD COLUMN IF NOT EXISTS ownership              text,
    ADD COLUMN IF NOT EXISTS annual_revenue         numeric(18,2),
    ADD COLUMN IF NOT EXISTS employees              integer,
    ADD COLUMN IF NOT EXISTS ticker                 text,
    ADD COLUMN IF NOT EXISTS site                   text,
    ADD COLUMN IF NOT EXISTS shipping_address_line  text,
    ADD COLUMN IF NOT EXISTS shipping_city          text,
    ADD COLUMN IF NOT EXISTS shipping_region        text,
    ADD COLUMN IF NOT EXISTS shipping_country       text;

ALTER TABLE crm.crm_companies DROP CONSTRAINT IF EXISTS ck_crm_companies_account_type;
ALTER TABLE crm.crm_companies ADD CONSTRAINT ck_crm_companies_account_type
    CHECK (account_type IS NULL OR account_type IN ('customer', 'prospect', 'partner', 'reseller', 'vendor', 'competitor', 'investor', 'other'));
ALTER TABLE crm.crm_companies DROP CONSTRAINT IF EXISTS ck_crm_companies_rating;
ALTER TABLE crm.crm_companies ADD CONSTRAINT ck_crm_companies_rating
    CHECK (rating IS NULL OR rating IN ('hot', 'warm', 'cold'));
ALTER TABLE crm.crm_companies DROP CONSTRAINT IF EXISTS ck_crm_companies_ownership;
ALTER TABLE crm.crm_companies ADD CONSTRAINT ck_crm_companies_ownership
    CHECK (ownership IS NULL OR ownership IN ('private', 'public', 'subsidiary', 'government', 'non_profit', 'partnership', 'sole_proprietor', 'other'));
ALTER TABLE crm.crm_companies DROP CONSTRAINT IF EXISTS ck_crm_companies_not_own_parent;
ALTER TABLE crm.crm_companies ADD CONSTRAINT ck_crm_companies_not_own_parent CHECK (parent_id IS NULL OR parent_id <> id);
ALTER TABLE crm.crm_companies DROP CONSTRAINT IF EXISTS ck_crm_companies_figures;
ALTER TABLE crm.crm_companies ADD CONSTRAINT ck_crm_companies_figures
    CHECK ((annual_revenue IS NULL OR annual_revenue >= 0) AND (employees IS NULL OR employees >= 0));

CREATE INDEX IF NOT EXISTS ix_crm_companies_parent ON crm.crm_companies (parent_id) WHERE parent_id IS NOT NULL;

COMMIT;

-- Importing accounts, deals and activities, each its own permission as importing contacts is.
-- Held by CRM Admin by being the role, and by the Sales Manager, who holds every deal and
-- activity permission (20261015-03 and -05 check that on every deploy).
BEGIN;

UPDATE core_platform.cp_resource_types SET resource_type_name = 'CRM Accounts',
       description = 'The organisations the business sells to: customers, prospects, partners, their branches'
 WHERE id = 'rt-crm-companies';

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('companies',  'rt-crm-companies',  'import', 'Import accounts'),
    ('deals',      'rt-crm-deals',      'import', 'Import deals'),
    ('activities', 'rt-crm-activities', 'import', 'Import calls, meetings and tasks')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-crm-' || spec.resource_key || '-' || spec.action,
       'CRM ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'crm',
       resource_key = substring(p.id FROM '^permission-crm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id IN ('permission-crm-companies-import', 'permission-crm-deals-import', 'permission-crm-activities-import')
   AND (p.app_prefix IS DISTINCT FROM 'crm' OR p.action IS NULL);

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', r.id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p ON p.id IN ('permission-crm-deals-import', 'permission-crm-activities-import')
 WHERE r.id = 'role-crm-sales-manager'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

COMMIT;
