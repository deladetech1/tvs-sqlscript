-- 20260729-01-coreplatform-organization-apps-audit-logs.sql
-- Per-entity audit logs for CorePlatform, mirroring the MyStoreGuard audit-log
-- design (dedicated table per entity, separate from the unified
-- core_platform.cp_activity_logs trail). Each create/update/delete/restore on the
-- audited entity appends one row, written in the SAME transaction as the CRUD op
-- so it commits/rolls back atomically. old_data/new_data are JSONB snapshots with
-- reference ids already resolved to human-readable names by AuditLogService.
--
-- Rollout order: organizations first, then business apps.
--
-- Deliberately NO foreign keys to the audited entity: an audit trail must outlive
-- the row it describes (esp. permanent/hard delete), so history is never cascaded
-- or blocked away. Scope columns (org_id/bus_id) are nullable because an
-- organization is top-level (no parent org/business).
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- Organizations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_organization_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,                               -- scope; equals entity_id for organizations
    bus_id                 text,                               -- always NULL for organizations (no parent business)

    entity_id              text        NOT NULL,               -- organization id the action was performed on
    entity_name            text,                               -- snapshot of org_name for display/filter

    action                 text        NOT NULL,               -- 'create' | 'update' | 'delete' | 'restore' | 'permanent_delete'
    old_data               jsonb,                              -- state before the change (update/delete)
    new_data               jsonb,                              -- state after the change (create/update)
    description            text,

    performed_by           text,                               -- user id who performed the action
    performed_by_fullname  text,                               -- denormalised for display + person filter
    performed_by_email     text,
    performed_by_contact   text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_organization_audit_logs_scope
    ON core_platform.cp_organization_audit_logs (tenant_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_organization_audit_logs_entity
    ON core_platform.cp_organization_audit_logs (tenant_id, entity_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_organization_audit_logs_action
    ON core_platform.cp_organization_audit_logs (tenant_id, action);

CREATE INDEX IF NOT EXISTS idx_cp_organization_audit_logs_performed_by
    ON core_platform.cp_organization_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- Business Apps
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_business_apps_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,                               -- owning organization scope
    bus_id                 text,                               -- owning business scope

    entity_id              text        NOT NULL,               -- business_app id (or app id) the action was performed on
    entity_name            text,                               -- snapshot of the app name for display/filter

    action                 text        NOT NULL,               -- 'subscribe' | 'unsubscribe' | 'deploy' | 'remove' | 'create' | 'update' | 'delete'
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

CREATE INDEX IF NOT EXISTS idx_cp_business_apps_audit_logs_scope
    ON core_platform.cp_business_apps_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_business_apps_audit_logs_entity
    ON core_platform.cp_business_apps_audit_logs (tenant_id, entity_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS idx_cp_business_apps_audit_logs_action
    ON core_platform.cp_business_apps_audit_logs (tenant_id, action);

CREATE INDEX IF NOT EXISTS idx_cp_business_apps_audit_logs_performed_by
    ON core_platform.cp_business_apps_audit_logs (tenant_id, performed_by);
