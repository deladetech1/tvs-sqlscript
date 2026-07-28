-- 20260714-12-loyalty-audit-logs.sql
-- Per-entity audit logs for MyStoreGuard loyalty configuration, mirroring the
-- customer/supplier audit tables (20260714-11). One dedicated table per audited
-- loyalty entity: segments, point rules and tiers. Every create/update/delete on
-- those entities appends one row (written in the same transaction as the CRUD op,
-- so it commits/rolls back atomically). old_data/new_data are kept as JSONB purely
-- to render a clean before/after diff in the UI.
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_segment_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- segment id the action was performed on
    entity_name            text,                               -- snapshot of the segment name for display/filter

    action                 text        NOT NULL,               -- 'create' | 'update' | 'delete'
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

CREATE INDEX IF NOT EXISTS idx_msg_segment_audit_logs_scope
    ON mystoreguard.msg_segment_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_segment_audit_logs_action
    ON mystoreguard.msg_segment_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_segment_audit_logs_performed_by
    ON mystoreguard.msg_segment_audit_logs (tenant_id, org_id, bus_id, performed_by);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_point_rule_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- point rule id
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

CREATE INDEX IF NOT EXISTS idx_msg_point_rule_audit_logs_scope
    ON mystoreguard.msg_point_rule_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_point_rule_audit_logs_action
    ON mystoreguard.msg_point_rule_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_point_rule_audit_logs_performed_by
    ON mystoreguard.msg_point_rule_audit_logs (tenant_id, org_id, bus_id, performed_by);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_tier_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,

    entity_id              text        NOT NULL,               -- tier id
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

CREATE INDEX IF NOT EXISTS idx_msg_tier_audit_logs_scope
    ON mystoreguard.msg_tier_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_msg_tier_audit_logs_action
    ON mystoreguard.msg_tier_audit_logs (tenant_id, org_id, bus_id, action);
CREATE INDEX IF NOT EXISTS idx_msg_tier_audit_logs_performed_by
    ON mystoreguard.msg_tier_audit_logs (tenant_id, org_id, bus_id, performed_by);
