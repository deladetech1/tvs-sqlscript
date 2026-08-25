-- =====================================================================
-- Audit trail for installment plans
-- ---------------------------------------------------------------------
-- A plan decides what a customer owes and for how long, so "who approved
-- this", "who waived that penalty" and "who wrote off the balance" are all
-- questions that get asked. The policy trail (20260825-03) covers the rules;
-- this covers what was done under them.
--
-- Same shape as every other msg_*_audit_logs table, so the audit-log reader
-- and the retention purge both pick it up without changes. Retention is by
-- convention — the purge walks every table in a schema named in
-- core_platform.cp_app_schemas and deletes by tenant_id + cdatetime — and
-- both columns are here.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_installment_plan_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_msg_installment_plan_audit_logs_scope
    ON mystoreguard.msg_installment_plan_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_installment_plan_audit_logs_action
    ON mystoreguard.msg_installment_plan_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_installment_plan_audit_logs_performed_by
    ON mystoreguard.msg_installment_plan_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_msg_installment_plan_audit_logs_entity
    ON mystoreguard.msg_installment_plan_audit_logs (tenant_id, org_id, bus_id, entity_id, cdatetime DESC);
