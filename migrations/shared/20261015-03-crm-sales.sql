-- CRM release 2: sales.
--
-- Leads, pipelines and their stages, deals moving through them, products and the
-- MyStoreGuard catalogue they can come from, quotes a customer opens from a link and can
-- accept and pay, won/lost reasons, and sales targets per person per month.
--
-- Money: every amount is stored with the currency it is in (a cp_currencies id of the
-- tenant). Nothing here converts; totals are reported per currency.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ======================================================================== pipelines
CREATE TABLE IF NOT EXISTS crm.crm_pipelines (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,
    name        text        NOT NULL,
    -- The pipeline new deals and converted leads go into when none is named.
    is_default  boolean     NOT NULL DEFAULT false,
    position    integer     NOT NULL DEFAULT 0,
    is_active   boolean     NOT NULL DEFAULT true,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_pipelines_scope ON crm.crm_pipelines (tenant_id, bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_pipelines_default ON crm.crm_pipelines (tenant_id, bus_id) WHERE is_default;

CREATE TABLE IF NOT EXISTS crm.crm_pipeline_stages (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    pipeline_id   text        NOT NULL REFERENCES crm.crm_pipelines(id) ON DELETE CASCADE,
    name          text        NOT NULL,
    position      integer     NOT NULL DEFAULT 0,
    -- How likely a deal here is to close, 0-100: what the weighted forecast multiplies by.
    probability   integer     NOT NULL DEFAULT 0,
    -- open | won | lost. A deal's status follows the kind of stage it is in.
    kind          text        NOT NULL DEFAULT 'open',
    -- A deal sitting here longer than this many days is flagged as going cold. NULL: never.
    rotting_days  integer,
    color         text,
    is_active     boolean     NOT NULL DEFAULT true,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_pipeline_stages_kind CHECK (kind IN ('open', 'won', 'lost')),
    CONSTRAINT ck_crm_pipeline_stages_probability CHECK (probability BETWEEN 0 AND 100),
    CONSTRAINT ck_crm_pipeline_stages_rotting CHECK (rotting_days IS NULL OR rotting_days > 0)
);
CREATE INDEX IF NOT EXISTS ix_crm_pipeline_stages_pipeline ON crm.crm_pipeline_stages (pipeline_id, position);

-- Why deals are won or lost: a business's own list, so reports group by something real.
CREATE TABLE IF NOT EXISTS crm.crm_close_reasons (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    bus_id      text        NOT NULL,
    -- won | lost
    kind        text        NOT NULL,
    name        text        NOT NULL,
    position    integer     NOT NULL DEFAULT 0,
    is_active   boolean     NOT NULL DEFAULT true,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_close_reasons_kind CHECK (kind IN ('won', 'lost'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_close_reasons_name ON crm.crm_close_reasons (tenant_id, bus_id, kind, lower(name));

-- ============================================================================ leads
CREATE TABLE IF NOT EXISTS crm.crm_leads (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    full_name           text        NOT NULL,
    company_name        text,
    job_title           text,
    email               text,
    phone               text,
    -- Digits-only phone and lower-cased email, for matching on conversion.
    phone_normalized    text,
    email_normalized    text,
    city                text,
    -- walk_in | referral | website | social | whatsapp | call | event | advert | import | other
    source              text        NOT NULL DEFAULT 'other',
    source_detail       text,
    -- new | contacted | qualified | disqualified | converted
    status              text        NOT NULL DEFAULT 'new',
    -- 0-100, worked out from what is known about the lead; see the backend's leadScore.
    score               integer     NOT NULL DEFAULT 0,
    -- hot | warm | cold, a person's own judgement, which the score does not override.
    rating              text,
    owner_user_id       text,
    estimated_value     numeric(18,2),
    currency_id         text,
    interest            text,
    notes               text,
    custom              jsonb       NOT NULL DEFAULT '{}'::jsonb,
    disqualify_reason   text,
    converted_contact_id text,
    converted_company_id text,
    converted_deal_id   text,
    converted_at        timestamptz,
    converted_by        text,
    last_contacted_at   timestamptz,
    is_active           boolean     NOT NULL DEFAULT true,
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by          text,
    updated_by          text,
    deleted_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_leads_status CHECK (status IN ('new', 'contacted', 'qualified', 'disqualified', 'converted')),
    CONSTRAINT ck_crm_leads_rating CHECK (rating IS NULL OR rating IN ('hot', 'warm', 'cold')),
    CONSTRAINT ck_crm_leads_score  CHECK (score BETWEEN 0 AND 100)
);
CREATE INDEX IF NOT EXISTS ix_crm_leads_scope  ON crm.crm_leads (tenant_id, bus_id, delete_status, status);
CREATE INDEX IF NOT EXISTS ix_crm_leads_owner  ON crm.crm_leads (tenant_id, owner_user_id);
CREATE INDEX IF NOT EXISTS ix_crm_leads_phone  ON crm.crm_leads (tenant_id, phone_normalized);
CREATE INDEX IF NOT EXISTS ix_crm_leads_email  ON crm.crm_leads (tenant_id, email_normalized);

-- Who gets the next unassigned lead: round-robin over these people, per business.
CREATE TABLE IF NOT EXISTS crm.crm_lead_assignment (
    tenant_id     text        NOT NULL,
    bus_id        text        NOT NULL,
    user_ids      text[]      NOT NULL DEFAULT ARRAY[]::text[],
    -- Index into user_ids of whoever got the last one.
    last_index    integer     NOT NULL DEFAULT -1,
    enabled       boolean     NOT NULL DEFAULT false,
    updated_by    text,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, bus_id)
);

-- ========================================================================= products
CREATE TABLE IF NOT EXISTS crm.crm_products (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,
    name          text        NOT NULL,
    sku           text,
    description   text,
    unit_price    numeric(18,2) NOT NULL DEFAULT 0,
    currency_id   text,
    -- Percent, e.g. 15 for VAT at 15%.
    tax_rate      numeric(6,3) NOT NULL DEFAULT 0,
    unit_name     text,
    category      text,
    -- manual | mystoreguard
    source        text        NOT NULL DEFAULT 'manual',
    source_id     text,
    source_hash   text,
    source_removed boolean    NOT NULL DEFAULT false,
    is_active     boolean     NOT NULL DEFAULT true,
    delete_status text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by    text,
    updated_by    text,
    deleted_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_products_price CHECK (unit_price >= 0),
    CONSTRAINT ck_crm_products_tax CHECK (tax_rate >= 0 AND tax_rate <= 100)
);
-- Only while it is a table (a view of Core Platform's products since 20261019-31).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('crm.crm_products')) = 'r' THEN
        CREATE INDEX IF NOT EXISTS ix_crm_products_scope ON crm.crm_products (tenant_id, bus_id, delete_status);
    END IF;
END $guard$;
-- Only while it is a table (a view of Core Platform's products since 20261019-31).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('crm.crm_products')) = 'r' THEN
        CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_products_source ON crm.crm_products (tenant_id, bus_id, source, source_id) WHERE source_id IS NOT NULL;
    END IF;
END $guard$;

-- ============================================================================ deals
CREATE TABLE IF NOT EXISTS crm.crm_deals (
    id                  text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text        NOT NULL,
    org_id              text        NOT NULL,
    bus_id              text        NOT NULL,
    title               text        NOT NULL,
    pipeline_id         text        NOT NULL REFERENCES crm.crm_pipelines(id),
    stage_id            text        NOT NULL REFERENCES crm.crm_pipeline_stages(id),
    -- open | won | lost: always the kind of stage_id.
    status              text        NOT NULL DEFAULT 'open',
    amount              numeric(18,2) NOT NULL DEFAULT 0,
    currency_id         text,
    -- A person's own estimate; NULL means the stage's probability applies.
    probability         integer,
    expected_close_date date,
    contact_id          text,
    company_id          text,
    lead_id             text,
    owner_user_id       text,
    source              text,
    close_reason_id     text,
    close_note          text,
    closed_at           timestamptz,
    -- When the deal entered its current stage: what "going cold" is measured from.
    stage_changed_at    timestamptz NOT NULL DEFAULT now(),
    -- Where on its stage's column the deal sits on the board.
    board_position      double precision NOT NULL DEFAULT 0,
    -- When true, the amount is the sum of the deal's product lines.
    amount_from_lines   boolean     NOT NULL DEFAULT false,
    notes               text,
    custom              jsonb       NOT NULL DEFAULT '{}'::jsonb,
    is_active           boolean     NOT NULL DEFAULT true,
    delete_status       text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by          text,
    updated_by          text,
    deleted_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_deals_status CHECK (status IN ('open', 'won', 'lost')),
    CONSTRAINT ck_crm_deals_amount CHECK (amount >= 0),
    CONSTRAINT ck_crm_deals_probability CHECK (probability IS NULL OR probability BETWEEN 0 AND 100)
);
CREATE INDEX IF NOT EXISTS ix_crm_deals_scope    ON crm.crm_deals (tenant_id, bus_id, delete_status, status);
CREATE INDEX IF NOT EXISTS ix_crm_deals_pipeline ON crm.crm_deals (pipeline_id, stage_id, board_position);
CREATE INDEX IF NOT EXISTS ix_crm_deals_contact  ON crm.crm_deals (contact_id);
CREATE INDEX IF NOT EXISTS ix_crm_deals_company  ON crm.crm_deals (company_id);
CREATE INDEX IF NOT EXISTS ix_crm_deals_owner    ON crm.crm_deals (tenant_id, owner_user_id);
CREATE INDEX IF NOT EXISTS ix_crm_deals_close    ON crm.crm_deals (tenant_id, bus_id, expected_close_date);

CREATE TABLE IF NOT EXISTS crm.crm_deal_lines (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    deal_id       text        NOT NULL REFERENCES crm.crm_deals(id) ON DELETE CASCADE,
    product_id    text,
    name          text        NOT NULL,
    description   text,
    quantity      numeric(18,3) NOT NULL DEFAULT 1,
    unit_price    numeric(18,2) NOT NULL DEFAULT 0,
    discount_pct  numeric(6,3) NOT NULL DEFAULT 0,
    tax_rate      numeric(6,3) NOT NULL DEFAULT 0,
    position      integer     NOT NULL DEFAULT 0,
    CONSTRAINT ck_crm_deal_lines_numbers CHECK (quantity > 0 AND unit_price >= 0 AND discount_pct BETWEEN 0 AND 100 AND tax_rate BETWEEN 0 AND 100)
);
CREATE INDEX IF NOT EXISTS ix_crm_deal_lines_deal ON crm.crm_deal_lines (deal_id, position);

-- Every move a deal makes: the raw material of conversion rates and time-in-stage.
CREATE TABLE IF NOT EXISTS crm.crm_deal_stage_history (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    bus_id         text        NOT NULL,
    deal_id        text        NOT NULL REFERENCES crm.crm_deals(id) ON DELETE CASCADE,
    pipeline_id    text        NOT NULL,
    from_stage_id  text,
    to_stage_id    text        NOT NULL,
    from_status    text,
    to_status      text        NOT NULL,
    amount         numeric(18,2),
    changed_by     text,
    changed_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_crm_deal_stage_history_deal ON crm.crm_deal_stage_history (deal_id, changed_at);
CREATE INDEX IF NOT EXISTS ix_crm_deal_stage_history_scope ON crm.crm_deal_stage_history (tenant_id, bus_id, changed_at);

-- =========================================================================== quotes
CREATE TABLE IF NOT EXISTS crm.crm_quote_counters (
    tenant_id   text    NOT NULL,
    bus_id      text    NOT NULL,
    last_number integer NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, bus_id)
);

CREATE TABLE IF NOT EXISTS crm.crm_quotes (
    id              text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    -- Q-000001, per business.
    number          text        NOT NULL,
    deal_id         text        REFERENCES crm.crm_deals(id),
    contact_id      text,
    company_id      text,
    title           text,
    -- draft | sent | accepted | declined | expired | paid
    status          text        NOT NULL DEFAULT 'draft',
    issue_date      date        NOT NULL DEFAULT CURRENT_DATE,
    valid_until     date,
    currency_id     text,
    -- The currency's code as the gateway needs it (GHS), kept with the quote.
    currency_code   text,
    subtotal        numeric(18,2) NOT NULL DEFAULT 0,
    discount_total  numeric(18,2) NOT NULL DEFAULT 0,
    tax_total       numeric(18,2) NOT NULL DEFAULT 0,
    total           numeric(18,2) NOT NULL DEFAULT 0,
    notes           text,
    terms           text,
    -- The customer's link: /q/<public_token>. Long and random; never an id.
    public_token    text        NOT NULL,
    sent_at         timestamptz,
    viewed_at       timestamptz,
    view_count      integer     NOT NULL DEFAULT 0,
    responded_at    timestamptz,
    customer_note   text,
    -- The payment the customer started from the quote (core platform's reference).
    payment_reference text,
    paid_at         timestamptz,
    paid_amount     numeric(18,2),
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    created_by      text,
    updated_by      text,
    deleted_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_quotes_status CHECK (status IN ('draft', 'sent', 'accepted', 'declined', 'expired', 'paid'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_quotes_number ON crm.crm_quotes (tenant_id, bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_quotes_token  ON crm.crm_quotes (public_token);
CREATE INDEX IF NOT EXISTS ix_crm_quotes_deal ON crm.crm_quotes (deal_id);
CREATE INDEX IF NOT EXISTS ix_crm_quotes_scope ON crm.crm_quotes (tenant_id, bus_id, delete_status, status);

CREATE TABLE IF NOT EXISTS crm.crm_quote_lines (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    quote_id      text        NOT NULL REFERENCES crm.crm_quotes(id) ON DELETE CASCADE,
    product_id    text,
    name          text        NOT NULL,
    description   text,
    quantity      numeric(18,3) NOT NULL DEFAULT 1,
    unit_price    numeric(18,2) NOT NULL DEFAULT 0,
    discount_pct  numeric(6,3) NOT NULL DEFAULT 0,
    tax_rate      numeric(6,3) NOT NULL DEFAULT 0,
    position      integer     NOT NULL DEFAULT 0,
    CONSTRAINT ck_crm_quote_lines_numbers CHECK (quantity > 0 AND unit_price >= 0 AND discount_pct BETWEEN 0 AND 100 AND tax_rate BETWEEN 0 AND 100)
);
CREATE INDEX IF NOT EXISTS ix_crm_quote_lines_quote ON crm.crm_quote_lines (quote_id, position);

-- ========================================================================== targets
-- What a person (or, with user_id NULL, the whole business) should win in a month.
CREATE TABLE IF NOT EXISTS crm.crm_targets (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    bus_id        text        NOT NULL,
    user_id       text,
    -- The first day of the month.
    period_month  date        NOT NULL,
    -- won_amount | won_deals | new_leads
    metric        text        NOT NULL,
    target        numeric(18,2) NOT NULL,
    currency_id   text,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_targets_metric CHECK (metric IN ('won_amount', 'won_deals', 'new_leads')),
    CONSTRAINT ck_crm_targets_month  CHECK (period_month = date_trunc('month', period_month)::date),
    CONSTRAINT ck_crm_targets_value  CHECK (target >= 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_targets_key
    ON crm.crm_targets (tenant_id, bus_id, coalesce(user_id, ''), period_month, metric);

-- ================================================== release 1 tables, widened for sales
-- The history also tells a deal's and a lead's story; a deal need not have a contact.
ALTER TABLE crm.crm_timeline_events ADD COLUMN IF NOT EXISTS deal_id text;
ALTER TABLE crm.crm_timeline_events ADD COLUMN IF NOT EXISTS lead_id text;
ALTER TABLE crm.crm_timeline_events ALTER COLUMN contact_id DROP NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_timeline_deal ON crm.crm_timeline_events (deal_id, occurred_at DESC) WHERE deal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_timeline_lead ON crm.crm_timeline_events (lead_id, occurred_at DESC) WHERE lead_id IS NOT NULL;

-- The catalogue sync has its own switch beside the customer syncs.
ALTER TABLE crm.crm_sync_settings DROP CONSTRAINT IF EXISTS ck_crm_sync_settings_app;
ALTER TABLE crm.crm_sync_settings ADD CONSTRAINT ck_crm_sync_settings_app
    CHECK (source_app IN ('mystoreguard', 'loandrift', 'mystoreguard-products'));

-- ======================================================= the MyStoreGuard catalogue
-- One row per product with the price a till would charge everywhere: the STORE channel's
-- GLOBAL price, a "stops other prices" one first, then the highest priority -- the same
-- order MyStoreGuard's own price calculator uses for a product with no location or SKU.
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_products') IS NOT NULL
       AND to_regclass('mystoreguard.msg_product_prices') IS NOT NULL THEN
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_mystoreguard_products AS
        SELECT p.tenant_id, p.org_id, p.bus_id, p.id AS source_id,
               btrim(p.name)                         AS name,
               NULLIF(btrim(p.sku), '')              AS sku,
               NULLIF(btrim(p.description), '')      AS description,
               pr.price                              AS unit_price,
               pr.currency                           AS currency_id,
               (p.delete_status <> 'NOT_DELETED' OR p.is_active IS FALSE OR p.retired_at IS NOT NULL) AS is_removed
          FROM mystoreguard.msg_products p
          LEFT JOIN LATERAL (
                SELECT x.price, x.currency
                  FROM mystoreguard.msg_product_prices x
                 WHERE x.product_id = p.id AND x.tenant_id = p.tenant_id
                   AND x.of_type = 'GLOBAL' AND coalesce(x.channel, 'STORE') = 'STORE'
                   AND x.deleted_by IS NULL
                 ORDER BY x.stops_other_prices DESC, x.priority DESC, x.cdatetime DESC
                 LIMIT 1) pr ON true
        $v$;
        EXECUTE $v$
        CREATE OR REPLACE VIEW crm.src_mystoreguard_products_hashed AS
        SELECT s.*, md5(row(s.name, s.sku, s.description, s.unit_price, s.currency_id, s.is_removed)::text) AS row_hash
          FROM crm.src_mystoreguard_products s
        $v$;
    END IF;
END $$;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('convert', 'Convert', false, false),
('send',    'Send',    false, false)
ON CONFLICT (action) DO NOTHING;

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-leads',     'CRM Leads',     'People who may buy but have not yet',          'rt-subscribed-app-crm'),
('rt-crm-deals',     'CRM Deals',     'Sales moving through a pipeline',              'rt-subscribed-app-crm'),
('rt-crm-pipelines', 'CRM Pipelines', 'Pipelines, their stages and won/lost reasons', 'rt-subscribed-app-crm'),
('rt-crm-products',  'CRM Products',  'What the business sells, for deals and quotes', 'rt-subscribed-app-crm'),
('rt-crm-quotes',    'CRM Quotes',    'Priced offers sent to customers',              'rt-subscribed-app-crm'),
('rt-crm-targets',   'CRM Targets',   'What each person should win each month',       'rt-subscribed-app-crm'),
('rt-crm-forecast',  'CRM Forecast',  'Expected sales and progress against targets',  'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('leads', 'rt-crm-leads', 'get',     'View leads'),
    ('leads', 'rt-crm-leads', 'create',  'Create leads'),
    ('leads', 'rt-crm-leads', 'update',  'Edit leads'),
    ('leads', 'rt-crm-leads', 'delete',  'Delete leads'),
    ('leads', 'rt-crm-leads', 'assign',  'Hand leads to someone else and set up auto-assignment'),
    ('leads', 'rt-crm-leads', 'convert', 'Turn a lead into a contact and a deal'),
    ('deals', 'rt-crm-deals', 'get',     'View deals'),
    ('deals', 'rt-crm-deals', 'create',  'Create deals'),
    ('deals', 'rt-crm-deals', 'update',  'Edit deals and move them between stages'),
    ('deals', 'rt-crm-deals', 'delete',  'Delete deals'),
    ('deals', 'rt-crm-deals', 'assign',  'Hand deals to someone else'),
    ('deals', 'rt-crm-deals', 'close',   'Mark deals won or lost, and reopen them'),
    ('pipelines', 'rt-crm-pipelines', 'get',    'View pipelines'),
    ('pipelines', 'rt-crm-pipelines', 'manage', 'Set up pipelines, stages and won/lost reasons'),
    ('products', 'rt-crm-products', 'get',    'View products'),
    ('products', 'rt-crm-products', 'manage', 'Add, edit and sync products'),
    ('quotes', 'rt-crm-quotes', 'get',    'View quotes'),
    ('quotes', 'rt-crm-quotes', 'create', 'Create quotes'),
    ('quotes', 'rt-crm-quotes', 'update', 'Edit quotes'),
    ('quotes', 'rt-crm-quotes', 'delete', 'Delete quotes'),
    ('quotes', 'rt-crm-quotes', 'send',   'Send quotes to customers'),
    ('targets', 'rt-crm-targets', 'get',    'View sales targets'),
    ('targets', 'rt-crm-targets', 'manage', 'Set sales targets'),
    ('forecast', 'rt-crm-forecast', 'get', 'View the sales forecast')
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
 WHERE p.id LIKE 'permission-crm-%'
   AND (p.app_prefix IS DISTINCT FROM 'crm' OR p.action IS NULL);

-- ========================================================================== roles
-- A sales manager runs the team: everything a user does, plus handing work out, deleting,
-- setting up pipelines, products and targets, imports and exports, and the audit trail.
INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-crm-sales-manager', 'system-tenant-id', 'CRM Sales Manager',
 'Runs the sales team: assigns leads and deals, sets up pipelines, products and targets, sees the forecast and audit trail',
 'rt-system-role', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET role_name = EXCLUDED.role_name, description = EXCLUDED.description,
                               resource_type_id = EXCLUDED.resource_type_id, is_system = EXCLUDED.is_system,
                               is_active = EXCLUDED.is_active;
UPDATE core_platform.cp_roles SET description = 'Works with customers and sales: contacts, companies, leads, deals and quotes'
 WHERE id = 'role-crm-user';
UPDATE core_platform.cp_roles SET description = 'Reads customers and sales; changes nothing'
 WHERE id = 'role-crm-viewer';

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (
    -- A user sells: works leads, deals and quotes, and closes their deals.
    SELECT 'role-crm-user' AS role_id, k AS resource_key, a AS action FROM (VALUES
        ('leads','get'), ('leads','create'), ('leads','update'), ('leads','convert'),
        ('deals','get'), ('deals','create'), ('deals','update'), ('deals','close'),
        ('pipelines','get'), ('products','get'),
        ('quotes','get'), ('quotes','create'), ('quotes','update'), ('quotes','send'),
        ('targets','get'), ('forecast','get')) v(k, a)
    UNION ALL
    SELECT 'role-crm-viewer', k, a FROM (VALUES
        ('leads','get'), ('deals','get'), ('pipelines','get'), ('products','get'),
        ('quotes','get'), ('targets','get'), ('forecast','get')) v(k, a)
    UNION ALL
    -- The manager: every CRM permission except deleting the audit trail (none exists) and
    -- running the customer sync switch, which stays with the CRM admin.
    SELECT 'role-crm-sales-manager', p2.resource_key, p2.action
      FROM core_platform.cp_permissions p2
     WHERE p2.app_prefix = 'crm' AND p2.delete_status = 'NOT_DELETED'
       AND NOT (p2.resource_key = 'sync' AND p2.action = 'manage')
  ) AS spec
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT 'system-tenant-id', r.id, p.id
  FROM core_platform.cp_roles r
  JOIN core_platform.cp_permissions p
    ON p.id IN ('permission-app-get', 'permission-business-get', 'permission-organization-get',
                'permission-business-app-get', 'permission-business-app-get-locations',
                'permission-user-get-locations')
 WHERE r.id = 'role-crm-sales-manager'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ===================================================================== invariants
DO $$
DECLARE missing int; unheld int; held int;
BEGIN
    SELECT count(*) INTO missing FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-crm-%' AND (app_prefix <> 'crm' OR resource_key IS NULL OR action IS NULL);
    IF missing > 0 THEN
        RAISE EXCEPTION '% CRM permission(s) have no pair; nothing would match them', missing;
    END IF;
    SELECT count(*) INTO unheld FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-crm-viewer' AND p.app_prefix = 'crm' AND NOT a.is_read_only;
    IF unheld > 0 THEN
        RAISE EXCEPTION 'role-crm-viewer holds % CRM permission(s) that change data', unheld;
    END IF;
    -- A user sells but does not delete or hand other people's work around.
    SELECT count(*) INTO held FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
     WHERE rp.role_id = 'role-crm-user' AND p.app_prefix = 'crm' AND p.resource_key IN ('leads', 'deals', 'quotes')
       AND p.action IN ('delete', 'assign');
    IF held > 0 THEN
        RAISE EXCEPTION 'role-crm-user holds % delete/assign permission(s) on sales', held;
    END IF;
    -- The manager holds every sales permission.
    SELECT count(*) INTO missing FROM core_platform.cp_permissions p
     WHERE p.app_prefix = 'crm' AND p.resource_key IN ('leads', 'deals', 'pipelines', 'products', 'quotes', 'targets', 'forecast')
       AND p.delete_status = 'NOT_DELETED'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                        WHERE rp.role_id = 'role-crm-sales-manager' AND rp.permission_id = p.id);
    IF missing > 0 THEN
        RAISE EXCEPTION 'role-crm-sales-manager lacks % sales permission(s)', missing;
    END IF;
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-crm-admin' AND permission_id LIKE 'permission-crm-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-crm-admin holds CRM permission rows';
    END IF;
END $$;

COMMIT;
