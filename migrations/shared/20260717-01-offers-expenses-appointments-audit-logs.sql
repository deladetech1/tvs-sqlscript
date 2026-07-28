-- 20260717-01-offers-expenses-appointments-audit-logs.sql
-- Per-entity audit logs for the Offers & Rewards area (gift cards, promo codes,
-- affiliates), Expenses, and Appointments — mirroring the existing audit tables.
-- Idempotent; safe to re-run on every deploy.

-- ============================================================================
-- Gift cards
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_gift_card_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_gift_card_audit_logs_scope
    ON mystoreguard.msg_gift_card_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_gift_card_audit_logs_action
    ON mystoreguard.msg_gift_card_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_gift_card_audit_logs_performed_by
    ON mystoreguard.msg_gift_card_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- Promo codes
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_promo_code_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_promo_code_audit_logs_scope
    ON mystoreguard.msg_promo_code_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_promo_code_audit_logs_action
    ON mystoreguard.msg_promo_code_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_promo_code_audit_logs_performed_by
    ON mystoreguard.msg_promo_code_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- Affiliates
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_affiliate_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_affiliate_audit_logs_scope
    ON mystoreguard.msg_affiliate_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_affiliate_audit_logs_action
    ON mystoreguard.msg_affiliate_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_affiliate_audit_logs_performed_by
    ON mystoreguard.msg_affiliate_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- Expenses
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_expense_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_expense_audit_logs_scope
    ON mystoreguard.msg_expense_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_expense_audit_logs_action
    ON mystoreguard.msg_expense_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_expense_audit_logs_performed_by
    ON mystoreguard.msg_expense_audit_logs (tenant_id, org_id, bus_id, performed_by);

-- ============================================================================
-- Appointments
-- ============================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_appointment_audit_logs (
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
CREATE INDEX IF NOT EXISTS idx_msg_appointment_audit_logs_scope
    ON mystoreguard.msg_appointment_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_appointment_audit_logs_action
    ON mystoreguard.msg_appointment_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_appointment_audit_logs_performed_by
    ON mystoreguard.msg_appointment_audit_logs (tenant_id, org_id, bus_id, performed_by);
