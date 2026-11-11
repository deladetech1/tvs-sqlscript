-- Core Platform: Workflows API tokens may be limited to some projects.
--
--   cp_workflow_api_tokens.project_ids   NULL = every project of the token's business (as before);
--                                        a JSON array of project ids = only those. A project deleted
--                                        later is taken out of the array by the backend, and one that
--                                        is restricted later stays reachable only while the token's
--                                        creator can still see it (checked on every request).
--
-- Idempotent; re-runs every deploy. The backend tolerates the column missing (no token is scoped).

BEGIN;

DO $$
BEGIN
    IF to_regclass('core_platform.cp_workflow_api_tokens') IS NOT NULL THEN
        ALTER TABLE core_platform.cp_workflow_api_tokens ADD COLUMN IF NOT EXISTS project_ids jsonb;
    END IF;
END $$;

COMMIT;
