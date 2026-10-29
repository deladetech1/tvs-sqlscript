-- Manufacturing: the lists of workflow (20261031-15), imports (20261031-16) and buy orders
-- (20261031-17). The lists live only here: to change one, edit this file.
--
--   rule status             draft | tested | published | retired
--   rule run status         running | waiting_approval | completed | failed | cancelled
--   rule step status        started | succeeded | failed | skipped | waiting
--   approval decision       approved | rejected (NULL while pending; the API's input is approve | reject)
--   notification channel    in_app | email
--   notification status     unread | read
--   notification email      pending | sent | failed | skipped (NULL when no email was asked)
--   import entity           items | boms | routings | work_centers | assets | demands
--   import status           previewed | committed | failed
--   import row action       create | update | skip | error
--   buy-order status        draft | placed | partially_received | received | closed | cancelled
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_rules DROP CONSTRAINT IF EXISTS mfg_rules_status_check;
ALTER TABLE mfg.mfg_rules ADD CONSTRAINT mfg_rules_status_check CHECK (status IN
    ('draft', 'tested', 'published', 'retired'));

ALTER TABLE mfg.mfg_rule_runs DROP CONSTRAINT IF EXISTS mfg_rule_runs_status_check;
ALTER TABLE mfg.mfg_rule_runs ADD CONSTRAINT mfg_rule_runs_status_check CHECK (status IN
    ('running', 'waiting_approval', 'completed', 'failed', 'cancelled'));

ALTER TABLE mfg.mfg_rule_steps DROP CONSTRAINT IF EXISTS mfg_rule_steps_status_check;
ALTER TABLE mfg.mfg_rule_steps ADD CONSTRAINT mfg_rule_steps_status_check CHECK (status IN
    ('started', 'succeeded', 'failed', 'skipped', 'waiting'));

ALTER TABLE mfg.mfg_approvals DROP CONSTRAINT IF EXISTS mfg_approvals_decision_check;
ALTER TABLE mfg.mfg_approvals ADD CONSTRAINT mfg_approvals_decision_check CHECK (decision IN
    ('approved', 'rejected'));

ALTER TABLE mfg.mfg_notifications DROP CONSTRAINT IF EXISTS mfg_notifications_channel_check;
ALTER TABLE mfg.mfg_notifications ADD CONSTRAINT mfg_notifications_channel_check CHECK (channel IN
    ('in_app', 'email'));

ALTER TABLE mfg.mfg_notifications DROP CONSTRAINT IF EXISTS mfg_notifications_status_check;
ALTER TABLE mfg.mfg_notifications ADD CONSTRAINT mfg_notifications_status_check CHECK (status IN
    ('unread', 'read'));

ALTER TABLE mfg.mfg_notifications DROP CONSTRAINT IF EXISTS mfg_notifications_email_status_check;
ALTER TABLE mfg.mfg_notifications ADD CONSTRAINT mfg_notifications_email_status_check CHECK (email_status IN
    ('pending', 'sent', 'failed', 'skipped'));

ALTER TABLE mfg.mfg_imports DROP CONSTRAINT IF EXISTS mfg_imports_entity_check;
ALTER TABLE mfg.mfg_imports ADD CONSTRAINT mfg_imports_entity_check CHECK (entity IN
    ('items', 'boms', 'routings', 'work_centers', 'assets', 'demands'));

ALTER TABLE mfg.mfg_imports DROP CONSTRAINT IF EXISTS mfg_imports_status_check;
ALTER TABLE mfg.mfg_imports ADD CONSTRAINT mfg_imports_status_check CHECK (status IN
    ('previewed', 'committed', 'failed'));

ALTER TABLE mfg.mfg_import_rows DROP CONSTRAINT IF EXISTS mfg_import_rows_action_check;
ALTER TABLE mfg.mfg_import_rows ADD CONSTRAINT mfg_import_rows_action_check CHECK (action IN
    ('create', 'update', 'skip', 'error'));

ALTER TABLE mfg.mfg_buy_orders DROP CONSTRAINT IF EXISTS mfg_buy_orders_status_check;
ALTER TABLE mfg.mfg_buy_orders ADD CONSTRAINT mfg_buy_orders_status_check CHECK (status IN
    ('draft', 'placed', 'partially_received', 'received', 'closed', 'cancelled'));

COMMIT;
