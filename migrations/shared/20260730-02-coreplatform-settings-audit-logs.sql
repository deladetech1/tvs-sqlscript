-- 20260730-02-coreplatform-settings-audit-logs.sql
-- Per-sub-entity audit logs for CorePlatform Settings, extending the design of
-- 20260729-01 / 20260730-01. Each settings sub-entity (currency, unit of
-- measure, password policy, change-password policy, MFA settings, email
-- credentials) gets its own dedicated table so its history is listed under its
-- own tab on the Settings audit page (mirrors MyStoreGuard's settings audit UI).
--
-- No FKs to the audited row (an audit trail must outlive it). Scope columns
-- (org_id/bus_id) nullable — settings are tenant-scoped. Idempotent.

-- ---------------------------------------------------------------------------
-- cp_currency_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_currency_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- currency id
    entity_name            text,                               -- currency name

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

CREATE INDEX IF NOT EXISTS idx_cp_currency_audit_logs_scope
    ON core_platform.cp_currency_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_currency_audit_logs_entity
    ON core_platform.cp_currency_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_currency_audit_logs_action
    ON core_platform.cp_currency_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_currency_audit_logs_performed_by
    ON core_platform.cp_currency_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- cp_unit_of_measure_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_unit_of_measure_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- unit-of-measure id
    entity_name            text,                               -- uom name

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

CREATE INDEX IF NOT EXISTS idx_cp_unit_of_measure_audit_logs_scope
    ON core_platform.cp_unit_of_measure_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_unit_of_measure_audit_logs_entity
    ON core_platform.cp_unit_of_measure_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_unit_of_measure_audit_logs_action
    ON core_platform.cp_unit_of_measure_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_unit_of_measure_audit_logs_performed_by
    ON core_platform.cp_unit_of_measure_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- cp_password_policy_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_password_policy_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- password-policy id
    entity_name            text,                               -- 'Password Policy' label

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

CREATE INDEX IF NOT EXISTS idx_cp_password_policy_audit_logs_scope
    ON core_platform.cp_password_policy_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_password_policy_audit_logs_entity
    ON core_platform.cp_password_policy_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_password_policy_audit_logs_action
    ON core_platform.cp_password_policy_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_password_policy_audit_logs_performed_by
    ON core_platform.cp_password_policy_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- cp_change_password_policy_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_change_password_policy_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- change-password-policy id
    entity_name            text,                               -- 'Change Password Policy' label

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

CREATE INDEX IF NOT EXISTS idx_cp_change_password_policy_audit_logs_scope
    ON core_platform.cp_change_password_policy_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_change_password_policy_audit_logs_entity
    ON core_platform.cp_change_password_policy_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_change_password_policy_audit_logs_action
    ON core_platform.cp_change_password_policy_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_change_password_policy_audit_logs_performed_by
    ON core_platform.cp_change_password_policy_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- cp_mfa_settings_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_mfa_settings_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- mfa-settings id
    entity_name            text,                               -- 'Multi-Factor Settings' label

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

CREATE INDEX IF NOT EXISTS idx_cp_mfa_settings_audit_logs_scope
    ON core_platform.cp_mfa_settings_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_mfa_settings_audit_logs_entity
    ON core_platform.cp_mfa_settings_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_mfa_settings_audit_logs_action
    ON core_platform.cp_mfa_settings_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_mfa_settings_audit_logs_performed_by
    ON core_platform.cp_mfa_settings_audit_logs (tenant_id, performed_by);


-- ---------------------------------------------------------------------------
-- cp_email_credentials_audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core_platform.cp_email_credentials_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,

    entity_id              text        NOT NULL,               -- email-credentials id
    entity_name            text,                               -- 'Email Credentials' label

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

CREATE INDEX IF NOT EXISTS idx_cp_email_credentials_audit_logs_scope
    ON core_platform.cp_email_credentials_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_email_credentials_audit_logs_entity
    ON core_platform.cp_email_credentials_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_email_credentials_audit_logs_action
    ON core_platform.cp_email_credentials_audit_logs (tenant_id, action);
CREATE INDEX IF NOT EXISTS idx_cp_email_credentials_audit_logs_performed_by
    ON core_platform.cp_email_credentials_audit_logs (tenant_id, performed_by);


