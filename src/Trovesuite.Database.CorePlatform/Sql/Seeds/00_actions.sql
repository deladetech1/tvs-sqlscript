-- =====================================================================================
-- The verbs, seeded before anything else in core_platform.
--
-- This has to run before 03_roles.sql, and therefore before every other module's seed. The
-- role triggers decide what an Admin or a Viewer Admin receives by reading cp_actions:
-- "everything except a verb that CHANGES logs" for Admin, "the read-only verbs" for a Viewer
-- Admin. Triggers are installed before any seed runs, so if cp_actions does not exist by the
-- time the first role is inserted, those functions bail out and a fresh install ends up
-- disagreeing with every migrated database -- Admin holding log deletion, viewers missing
-- their statistics.
--
-- Kept deliberately small: just the vocabulary. The resources that use it stay in each
-- module's own 02_permissions.sql, because a module's resource types do not exist until that
-- module is seeded. migrations/shared/20260928-05 carries the same rows for databases that
-- were created before this file existed.
-- =====================================================================================

SET search_path TO core_platform;

-- The same columns migrations/shared/20260928-05 adds, created here too so they exist before
-- the first permission or role is inserted. The permission trigger reads NEW.action to decide
-- whether a verb modifies logs, and a row trigger cannot reference a column that is not there
-- yet. Guarded, so running both this and 05 is harmless.
ALTER TABLE core_platform.cp_permissions
    ADD COLUMN IF NOT EXISTS app_prefix   TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS resource_key TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS action       TEXT,
    ADD COLUMN IF NOT EXISTS target       TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS scope        TEXT NOT NULL DEFAULT 'any';

CREATE TABLE IF NOT EXISTS core_platform.cp_actions (
    action         TEXT PRIMARY KEY,
    label          TEXT      NOT NULL,
    is_read_only   BOOLEAN   NOT NULL DEFAULT false,
    viewer_default BOOLEAN   NOT NULL DEFAULT false,
    cdatetime      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('add', 'Add', false, false),
('adjust', 'Adjust', false, false),
('approve', 'Approve', false, false),
('assign', 'Assign', false, false),
('backdate', 'Backdate', false, false),
('calculate', 'Calculate', false, false),
('cancel', 'Cancel', false, false),
('change', 'Change', false, false),
('close', 'Close', false, false),
('complete', 'Complete', false, false),
('create', 'Create', false, false),
('delete', 'Delete', false, false),
('deploy', 'Deploy', false, false),
('disburse', 'Disburse', false, false),
('get', 'Get', true, true),
('grant', 'Grant', false, false),
('list', 'List', true, true),
('manage', 'Manage', false, false),
('move', 'Move', false, false),
('pay', 'Pay', false, false),
('permanent-delete', 'Permanent Delete', false, false),
('reconcile', 'Reconcile', false, false),
('refund', 'Refund', false, false),
('reject', 'Reject', false, false),
('release', 'Release', false, false),
('remove', 'Remove', false, false),
('request', 'Request', false, false),
('reset', 'Reset', false, false),
('resolve', 'Resolve', false, false),
('restore', 'Restore', false, false),
('restructure', 'Restructure', false, false),
('reveal', 'Reveal', true, false),
('reverse', 'Reverse', false, false),
('revoke', 'Revoke', false, false),
('share', 'Share', false, false),
('sign', 'Sign', false, false),
('split', 'Split', false, false),
('statistics', 'Statistics', true, true),
('subscribe', 'Subscribe', false, false),
('terminate', 'Terminate', false, false),
('transact', 'Transact', false, false),
('unsubscribe', 'Unsubscribe', false, false),
('update', 'Update', false, false),
('upload', 'Upload', false, false),
('void', 'Void', false, false),
('waive', 'Waive', false, false),
('write-off', 'Write Off', false, false)
ON CONFLICT (action) DO UPDATE SET
    label          = EXCLUDED.label,
    is_read_only   = EXCLUDED.is_read_only,
    viewer_default = EXCLUDED.viewer_default;
