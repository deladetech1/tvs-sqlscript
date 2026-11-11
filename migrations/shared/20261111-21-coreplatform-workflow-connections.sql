-- Core Platform: workflow CONNECTIONS -- an organisation's saved sign-in to an outside service
-- (Settings > Workflows > Connections), used by the Connector step and the "When <service> sends"
-- triggers (tvs-coreplatform-bk docs/workflows/CONNECTORS.md).
--
--   cp_workflow_connections   one row per connection: which connector (slack, paystack...), a name,
--                             the settings that are not secret (a subdomain, a region, a self-hosted
--                             address) as JSON in config, and every secret field (API keys, tokens,
--                             client secrets, webhook signing secrets) together in secrets_enc,
--                             Fernet-encrypted by Core ("enc::..."), never returned by the API.
--                             status / last_test_*: the last "Test connection".
--
-- Idempotent; re-runs on every deploy. The backend tolerates the table being missing.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_connections (
    tenant_id          text        NOT NULL,
    id                 text        NOT NULL,
    connector          text        NOT NULL,
    name               text        NOT NULL,
    config             jsonb       NOT NULL DEFAULT '{}'::jsonb,
    secrets_enc        text,
    status             text        NOT NULL DEFAULT 'UNTESTED',
    last_tested_at     timestamptz,
    last_test_ok       boolean,
    last_test_message  text,
    created_by         text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    CONSTRAINT cp_workflow_connections_connector_ck CHECK (connector ~ '^[a-z][a-z0-9_]{1,40}$'),
    CONSTRAINT cp_workflow_connections_name_ck CHECK (length(name) BETWEEN 1 AND 80),
    CONSTRAINT cp_workflow_connections_status_ck CHECK (status IN ('UNTESTED', 'OK', 'FAILED')),
    -- Secrets are never stored in the clear.
    CONSTRAINT cp_workflow_connections_secret_ck CHECK (secrets_enc IS NULL OR secrets_enc LIKE 'enc::%')
);
CREATE UNIQUE INDEX IF NOT EXISTS cp_workflow_connections_name_uq
    ON core_platform.cp_workflow_connections (tenant_id, lower(name));
CREATE INDEX IF NOT EXISTS cp_workflow_connections_connector_idx
    ON core_platform.cp_workflow_connections (tenant_id, connector);

COMMIT;
