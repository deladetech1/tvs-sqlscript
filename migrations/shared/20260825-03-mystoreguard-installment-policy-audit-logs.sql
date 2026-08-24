-- =====================================================================
-- Audit trail for installment policies
-- ---------------------------------------------------------------------
-- An installment policy decides who may buy on credit and what the finance
-- charge is, so "who changed the interest rate, and when" is a question that
-- will be asked. Same shape as every other msg_*_audit_logs table
-- (20260717-03) so the audit-log reader and the retention purge both pick it
-- up without changes.
--
-- Retention is by convention, not registration: the purge walks every table in
-- a schema named in core_platform.cp_app_schemas and deletes by tenant_id +
-- cdatetime. Both columns are here, and MyStoreGuard already has its row, so
-- nothing further is needed for this table to age out with the rest.
--
-- The policy's child rows (locations, plan options, variables, approvers) are
-- deliberately NOT audited separately. They are edited only as part of the
-- policy they hang off, and the service snapshots the whole policy — parent and
-- children — into new_data, so a per-child trail would duplicate the parent's
-- entry without adding a fact.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_installment_policy_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_msg_installment_policy_audit_logs_scope
    ON mystoreguard.msg_installment_policy_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_installment_policy_audit_logs_action
    ON mystoreguard.msg_installment_policy_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_installment_policy_audit_logs_performed_by
    ON mystoreguard.msg_installment_policy_audit_logs (tenant_id, org_id, bus_id, performed_by);
CREATE INDEX IF NOT EXISTS idx_msg_installment_policy_audit_logs_entity
    ON mystoreguard.msg_installment_policy_audit_logs (tenant_id, org_id, bus_id, entity_id, cdatetime DESC);
