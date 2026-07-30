-- 20260730-01-coreplatform-core-entity-audit-logs.sql
-- Per-entity audit logs for the remaining CorePlatform management entities,
-- extending the design established in 20260729-01 (organizations, business apps).
-- One dedicated table per entity, separate from the unified
-- core_platform.cp_activity_logs trail. Each create/update/delete/restore/
-- permanent_delete appends one row; old_data/new_data are JSONB snapshots with
-- reference ids already resolved to human-readable names by AuditLogService.
--
-- Entities: groups, users, roles, locations (permissions intentionally excluded).
--
-- Deliberately NO foreign keys to the audited entity: an audit trail must outlive
-- the row it describes (esp. permanent/hard delete). Scope columns (org_id/bus_id)
-- are nullable — several of these entities are tenant- or org-scoped, not
-- business-scoped.
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- Groups
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_group_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- group id the action was performed on
    entity_name            text,                               -- snapshot of group_name for display/filter

    action                 text        NOT NULL,               -- 'create' | 'update' | 'delete' | 'restore' | 'permanent_delete'
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

CREATE INDEX IF NOT EXISTS idx_cp_group_audit_logs_scope
    ON core_platform.cp_group_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_group_audit_logs_entity
    ON core_platform.cp_group_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_group_audit_logs_action
    ON core_platform.cp_group_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_group_audit_logs_performed_by
    ON core_platform.cp_group_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_user_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- user id the action was performed on
    entity_name            text,                               -- snapshot of fullname for display/filter

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

CREATE INDEX IF NOT EXISTS idx_cp_user_audit_logs_scope
    ON core_platform.cp_user_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_user_audit_logs_entity
    ON core_platform.cp_user_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_user_audit_logs_action
    ON core_platform.cp_user_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_user_audit_logs_performed_by
    ON core_platform.cp_user_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_role_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- role id the action was performed on
    entity_name            text,                               -- snapshot of role_name for display/filter

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

CREATE INDEX IF NOT EXISTS idx_cp_role_audit_logs_scope
    ON core_platform.cp_role_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_role_audit_logs_entity
    ON core_platform.cp_role_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_role_audit_logs_action
    ON core_platform.cp_role_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_role_audit_logs_performed_by
    ON core_platform.cp_role_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_location_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- location id the action was performed on
    entity_name            text,                               -- snapshot of loc_name for display/filter

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

CREATE INDEX IF NOT EXISTS idx_cp_location_audit_logs_scope
    ON core_platform.cp_location_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_location_audit_logs_entity
    ON core_platform.cp_location_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_location_audit_logs_action
    ON core_platform.cp_location_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_location_audit_logs_performed_by
    ON core_platform.cp_location_audit_logs (tenant_id, performed_by);
