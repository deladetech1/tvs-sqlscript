-- Core Platform: automation accounts and the generic "App action" workflow step
-- (tvs-coreplatform-bk docs/workflows/AUTOMATION-ACCOUNTS.md).
--
-- 1. AUTOMATION ACCOUNTS. A non-human user ("Finance bot") is a real cp_users row flagged
--    is_automation, so every app's existing permission checks apply to it unchanged: its roles,
--    groups and location access are ordinary rows. What makes it non-human is enforced HERE, in
--    the database, not only in Core's code:
--      * it can never sign in: can_login is forced false, is_owner false, on every write
--        (cp_users_automation_guard);
--      * a person can never be turned into one, and one can never be turned back into a person;
--      * it is not a seat: cp_tenant_platform_usage.users_used no longer counts it.
--    cp_automation_accounts holds what only an automation account has: its name, status
--    (ACTIVE / DISABLED, with who and why) and last activity.
--
-- 2. THE CALL LOG. Every HTTP call an App action step makes is a cp_workflow_calls row: the
--    account it ran as, the endpoint, the status, and a REDACTED summary of the request and the
--    answer (secrets and personal-data fields are blanked by Core before writing). Kept with the
--    run (90 days after it finishes; the workflow runtime purges them together).
--
-- 3. SENSITIVE SIGN-OFF. An owner may sign a workflow's sensitive App actions off (money, deletes,
--    payroll, bulk) instead of putting an approval step before each: who, when, and a hash of
--    exactly what they signed. Editing those steps changes the hash and the sign-off lapses.
--    Frozen into each published version (cp_workflow_versions.signoff).
--
-- Idempotent; re-runs on every deploy. Nothing is narrowed.

BEGIN;

-- ===================================================================== 1. accounts
ALTER TABLE core_platform.cp_users ADD COLUMN IF NOT EXISTS is_automation boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS cp_users_automation_idx ON core_platform.cp_users (tenant_id) WHERE is_automation;

CREATE TABLE IF NOT EXISTS core_platform.cp_automation_accounts (
    tenant_id        text        NOT NULL,
    user_id          text        NOT NULL,
    name             text        NOT NULL,
    description      text        NOT NULL DEFAULT '',
    status           text        NOT NULL DEFAULT 'ACTIVE',
    created_by       text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    disabled_by      text,
    disabled_at      timestamptz,
    disabled_reason  text,
    last_used_at     timestamptz,
    last_run_id      text,
    last_workflow_id text,
    PRIMARY KEY (tenant_id, user_id),
    CONSTRAINT cp_automation_accounts_status_ck CHECK (status IN ('ACTIVE', 'DISABLED'))
);
CREATE UNIQUE INDEX IF NOT EXISTS cp_automation_accounts_name_uq
    ON core_platform.cp_automation_accounts (tenant_id, lower(name));

-- The invariant, whoever writes the row: Core's screens, a migration, a console, SCIM.
CREATE OR REPLACE FUNCTION core_platform.cp_users_automation_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF OLD.is_automation AND NOT NEW.is_automation THEN
            RAISE EXCEPTION 'An automation account cannot be turned into a person (user %)', OLD.id
                USING ERRCODE = 'check_violation';
        END IF;
        IF NEW.is_automation AND NOT OLD.is_automation THEN
            RAISE EXCEPTION 'A person cannot be turned into an automation account (user %)', OLD.id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    IF NEW.is_automation THEN
        NEW.can_login := false;   -- never signs in: password, OTP, passkey and SSO all read this
        NEW.is_owner := false;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS cp_users_automation_guard ON core_platform.cp_users;
CREATE TRIGGER cp_users_automation_guard
    BEFORE INSERT OR UPDATE OF is_automation, can_login, is_owner ON core_platform.cp_users
    FOR EACH ROW EXECUTE FUNCTION core_platform.cp_users_automation_guard();

-- Not a seat. The one definition of this view otherwise lives in 20260821-01, which runs first on
-- every deploy; this later file is the one that wins, so change the view HERE from now on.
CREATE OR REPLACE VIEW core_platform.cp_tenant_platform_usage AS
SELECT t.id AS tenant_id,
       (SELECT count(*) FROM core_platform.cp_organizations o
         WHERE o.tenant_id = t.id AND o.delete_status = 'NOT_DELETED')          AS organizations_used,
       (SELECT count(*) FROM core_platform.cp_businesses b
         WHERE b.tenant_id = t.id AND b.delete_status = 'NOT_DELETED')          AS businesses_used,
       (SELECT count(*) FROM core_platform.cp_users u
         WHERE u.tenant_id = t.id AND u.delete_status = 'NOT_DELETED'
           AND NOT u.is_automation)                                             AS users_used,
       (SELECT count(*) FROM core_platform.cp_locations l
         WHERE l.tenant_id = t.id AND l.delete_status = 'NOT_DELETED')          AS locations_used,
       (SELECT count(*) FROM core_platform.cp_groups g
         WHERE g.tenant_id = t.id AND g.delete_status = 'NOT_DELETED'
           AND (g.is_system = false OR g.is_system IS NULL))                    AS groups_used
FROM core_platform.cp_tenants t;

-- ===================================================================== 2. the call log
CREATE TABLE IF NOT EXISTS core_platform.cp_workflow_calls (
    id              bigserial   PRIMARY KEY,
    tenant_id       text        NOT NULL,
    run_id          text        NOT NULL,
    node_id         text        NOT NULL,
    attempt         integer     NOT NULL DEFAULT 1,
    workflow_id     text        NOT NULL,
    bus_id          text,
    account_id      text        NOT NULL,
    app_id          text        NOT NULL,
    method          text        NOT NULL,
    path            text        NOT NULL,
    host            text        NOT NULL DEFAULT '',
    status_code     integer,
    outcome         text        NOT NULL,           -- SUCCEEDED | FAILED | RETRYING | REFUSED
    idempotency_key text,
    duration_ms     integer,
    request         jsonb       NOT NULL DEFAULT '{}'::jsonb,   -- redacted
    response        jsonb       NOT NULL DEFAULT '{}'::jsonb,   -- redacted, trimmed
    error           text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cp_workflow_calls_run_idx ON core_platform.cp_workflow_calls (tenant_id, run_id, id);
CREATE INDEX IF NOT EXISTS cp_workflow_calls_month_idx ON core_platform.cp_workflow_calls (tenant_id, cdatetime);
CREATE INDEX IF NOT EXISTS cp_workflow_calls_account_idx ON core_platform.cp_workflow_calls (tenant_id, account_id, id);

-- ===================================================================== 3. sensitive sign-off
DO $$
BEGIN
    IF to_regclass('core_platform.cp_workflows') IS NULL THEN
        RAISE NOTICE 'automation-accounts: no cp_workflows here (20261109-81 not applied); skipping the sign-off columns';
        RETURN;
    END IF;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS sensitive_signoff_by text;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS sensitive_signoff_at timestamptz;
    ALTER TABLE core_platform.cp_workflows ADD COLUMN IF NOT EXISTS sensitive_signoff_hash text;
    ALTER TABLE core_platform.cp_workflow_versions ADD COLUMN IF NOT EXISTS signoff jsonb;
END $$;

COMMIT;
