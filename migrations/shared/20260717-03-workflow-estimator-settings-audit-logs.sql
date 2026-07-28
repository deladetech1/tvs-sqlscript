-- 20260717-03-workflow-estimator-settings-audit-logs.sql
-- Per-entity audit logs for the Workflow (templates, tasks), Estimator (estimate
-- templates, estimates) and Settings (product metadata, product prices, pricing
-- rules, tax, tax rules, return policy) areas. Mirrors the existing audit tables.
-- Idempotent; safe to re-run on every deploy.

-- ============================================================================
-- msg_workflow_template_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_workflow_template_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_workflow_template_audit_logs_scope
    ON mystoreguard.msg_workflow_template_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_workflow_template_audit_logs_action
    ON mystoreguard.msg_workflow_template_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_workflow_template_audit_logs_performed_by
    ON mystoreguard.msg_workflow_template_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_task_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_task_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_task_audit_logs_scope
    ON mystoreguard.msg_task_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_task_audit_logs_action
    ON mystoreguard.msg_task_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_task_audit_logs_performed_by
    ON mystoreguard.msg_task_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_estimate_template_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_estimate_template_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_template_audit_logs_scope
    ON mystoreguard.msg_estimate_template_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_template_audit_logs_action
    ON mystoreguard.msg_estimate_template_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_template_audit_logs_performed_by
    ON mystoreguard.msg_estimate_template_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_estimate_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_estimate_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_audit_logs_scope
    ON mystoreguard.msg_estimate_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_audit_logs_action
    ON mystoreguard.msg_estimate_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_estimate_audit_logs_performed_by
    ON mystoreguard.msg_estimate_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_product_metadata_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_metadata_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_product_metadata_audit_logs_scope
    ON mystoreguard.msg_product_metadata_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_product_metadata_audit_logs_action
    ON mystoreguard.msg_product_metadata_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_product_metadata_audit_logs_performed_by
    ON mystoreguard.msg_product_metadata_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_product_price_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_product_price_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_product_price_audit_logs_scope
    ON mystoreguard.msg_product_price_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_product_price_audit_logs_action
    ON mystoreguard.msg_product_price_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_product_price_audit_logs_performed_by
    ON mystoreguard.msg_product_price_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_pricing_rule_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_pricing_rule_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_pricing_rule_audit_logs_scope
    ON mystoreguard.msg_pricing_rule_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_pricing_rule_audit_logs_action
    ON mystoreguard.msg_pricing_rule_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_pricing_rule_audit_logs_performed_by
    ON mystoreguard.msg_pricing_rule_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_tax_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_tax_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_tax_audit_logs_scope
    ON mystoreguard.msg_tax_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_tax_audit_logs_action
    ON mystoreguard.msg_tax_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_tax_audit_logs_performed_by
    ON mystoreguard.msg_tax_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_tax_rule_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_tax_rule_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_tax_rule_audit_logs_scope
    ON mystoreguard.msg_tax_rule_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_tax_rule_audit_logs_action
    ON mystoreguard.msg_tax_rule_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_tax_rule_audit_logs_performed_by
    ON mystoreguard.msg_tax_rule_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- msg_return_policy_audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_return_policy_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_msg_return_policy_audit_logs_scope
    ON mystoreguard.msg_return_policy_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_return_policy_audit_logs_action
    ON mystoreguard.msg_return_policy_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_return_policy_audit_logs_performed_by
    ON mystoreguard.msg_return_policy_audit_logs (tenant_id, org_id, bus_id, performed_by);
