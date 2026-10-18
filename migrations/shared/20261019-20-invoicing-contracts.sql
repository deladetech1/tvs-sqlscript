-- Invoicing: contracts with electronic signatures, and proposals.
--
-- A contract is text the business writes (from a template or its own) for a customer, sent as a
-- link: the customer reads it and signs -- drawing their signature or typing their name -- and
-- the business countersigns. Each signature keeps who, when, from where (IP and browser) and an
-- image; the text signed is fixed by its SHA-256 at the first signature, so what was agreed can
-- be shown later, with every event (made, sent, opened, signed, declined, cancelled) in
-- inv_contract_events. A contract may go with a quote: accepting the quote is then signing it.
--
-- A quote can be a proposal: inv_invoices.intro is the cover text (who we are, the scope, the
-- plan) shown above the prices, and its acceptance can carry a drawn signature too.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_contracts (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    org_id              text,
    bus_id              text NOT NULL,
    customer_id         text NOT NULL REFERENCES invoicing.inv_customers(id) ON DELETE RESTRICT,
    customer_snapshot   jsonb NOT NULL DEFAULT '{}'::jsonb,
    quote_id            text REFERENCES invoicing.inv_invoices(id) ON DELETE SET NULL,
    number              text,
    title               text NOT NULL CHECK (btrim(title) <> '' AND length(title) <= 200),
    body                text NOT NULL DEFAULT '' CHECK (length(body) <= 200000),
    template_key        text NOT NULL DEFAULT '',
    -- draft, sent (to sign), signed (by the customer), completed (both), declined, void
    status              text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'signed', 'completed', 'declined', 'void')),
    -- Whether the business signs too (countersigns), and whether it must before the customer.
    business_signs      boolean NOT NULL DEFAULT true,
    expires_on          date,
    public_token        text UNIQUE,
    content_hash        text,
    sent_at             timestamptz,
    viewed_at           timestamptz,
    view_count          integer NOT NULL DEFAULT 0,
    -- The customer's signature.
    signer_name         text,
    signer_email        text,
    signer_ip           text,
    signer_agent        text,
    signer_method       text CHECK (signer_method IS NULL OR signer_method IN ('drawn', 'typed')),
    signer_image        bytea,
    signed_at           timestamptz,
    -- The business's.
    business_signer_id    text,
    business_signer_name  text,
    business_signer_ip    text,
    business_signer_method text CHECK (business_signer_method IS NULL OR business_signer_method IN ('drawn', 'typed')),
    business_signer_image bytea,
    business_signed_at    timestamptz,
    declined_at         timestamptz,
    decline_reason      text NOT NULL DEFAULT '',
    voided_at           timestamptz,
    void_reason         text NOT NULL DEFAULT '',
    created_by          text,
    updated_by          text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT inv_contracts_number_ck CHECK ((status = 'draft') = (number IS NULL))
);
CREATE INDEX IF NOT EXISTS inv_contracts_bus_idx ON invoicing.inv_contracts (tenant_id, bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS inv_contracts_customer_idx ON invoicing.inv_contracts (customer_id);
CREATE INDEX IF NOT EXISTS inv_contracts_quote_idx ON invoicing.inv_contracts (quote_id) WHERE quote_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS inv_contracts_number_uq ON invoicing.inv_contracts (bus_id, number) WHERE number IS NOT NULL;

CREATE TABLE IF NOT EXISTS invoicing.inv_contract_events (
    id           bigserial PRIMARY KEY,
    tenant_id    text NOT NULL,
    contract_id  text NOT NULL REFERENCES invoicing.inv_contracts(id) ON DELETE CASCADE,
    -- created, sent, viewed, signed, countersigned, declined, void, edited
    event        text NOT NULL,
    who          text NOT NULL DEFAULT '',
    ip           text NOT NULL DEFAULT '',
    agent        text NOT NULL DEFAULT '',
    detail       jsonb NOT NULL DEFAULT '{}'::jsonb,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_contract_events_contract_idx ON invoicing.inv_contract_events (contract_id, id);

-- Contracts number in their own series.
DO $$
DECLARE c text;
BEGIN
    SELECT conname INTO c FROM pg_constraint WHERE conrelid = 'invoicing.inv_number_series'::regclass AND conname = 'inv_number_series_kind_check'
       AND pg_get_constraintdef(oid) NOT LIKE '%contract%';
    IF c IS NOT NULL THEN
        ALTER TABLE invoicing.inv_number_series DROP CONSTRAINT inv_number_series_kind_check;
        ALTER TABLE invoicing.inv_number_series ADD CONSTRAINT inv_number_series_kind_check
            CHECK (kind IN ('invoice', 'quote', 'credit_note', 'receipt', 'purchase_order', 'contract'));
    END IF;
END $$;

-- Proposals: a quote's cover text, and the signature its acceptance may carry.
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS intro text NOT NULL DEFAULT '';
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS accepted_signature bytea;
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS accepted_ip text;

-- Audit trails are purged by convention: the events keep tenant_id and cdatetime (see
-- inv_audit_logs); a contract's own events go with it.

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-invoicing-contracts', 'Invoicing Contracts', 'Contracts and their signatures', 'rt-subscribed-app-invoicing')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, action, label) AS (VALUES
    ('contracts', 'get',    'View contracts'),
    ('contracts', 'create', 'Create contracts'),
    ('contracts', 'update', 'Edit contracts'),
    ('contracts', 'delete', 'Delete draft contracts'),
    ('contracts', 'send',   'Send contracts to sign'),
    ('contracts', 'sign',   'Sign contracts for the business'),
    ('contracts', 'void',   'Cancel contracts')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime, app_prefix, resource_key, action, target, scope)
SELECT 'permission-invoicing-' || spec.resource_key || '-' || spec.action,
       'Invoicing Contracts ' || initcap(spec.action), 'rt-invoicing-contracts', spec.label,
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP, 'invoicing', spec.resource_key, spec.action, '', 'any'
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description,
                               app_prefix = EXCLUDED.app_prefix, resource_key = EXCLUDED.resource_key,
                               action = EXCLUDED.action, target = EXCLUDED.target, scope = EXCLUDED.scope;

-- The manager everything; the clerk drafts and sends (signing for the business, deleting and
-- cancelling are the manager's); the accountant and the viewer read.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-invoicing-manager', 'get'), ('role-invoicing-manager', 'create'), ('role-invoicing-manager', 'update'),
        ('role-invoicing-manager', 'delete'), ('role-invoicing-manager', 'send'), ('role-invoicing-manager', 'sign'),
        ('role-invoicing-manager', 'void'),
        ('role-invoicing-clerk', 'get'), ('role-invoicing-clerk', 'create'), ('role-invoicing-clerk', 'update'), ('role-invoicing-clerk', 'send'),
        ('role-invoicing-accountant', 'get'),
        ('role-invoicing-viewer', 'get')) AS spec(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.id = 'permission-invoicing-contracts-' || spec.action
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

COMMIT;
