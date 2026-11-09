-- Manufacturing: the lists of webhooks (20261101-13). The lists live only here: to change one, edit
-- this file.
--
--   subscription status     active | paused | archived
--   delivery status         pending | delivered | failed | dead
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE mfg.mfg_webhook_subscriptions DROP CONSTRAINT IF EXISTS mfg_webhook_subscriptions_status_check;
ALTER TABLE mfg.mfg_webhook_subscriptions ADD CONSTRAINT mfg_webhook_subscriptions_status_check CHECK (status IN
    ('active', 'paused', 'archived'));

ALTER TABLE mfg.mfg_webhook_deliveries DROP CONSTRAINT IF EXISTS mfg_webhook_deliveries_status_check;
ALTER TABLE mfg.mfg_webhook_deliveries ADD CONSTRAINT mfg_webhook_deliveries_status_check CHECK (status IN
    ('pending', 'delivered', 'failed', 'dead'));

COMMIT;
