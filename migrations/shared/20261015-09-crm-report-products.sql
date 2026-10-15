-- CRM: the Products report can be emailed like the others.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE crm.crm_report_subscriptions DROP CONSTRAINT IF EXISTS ck_crm_report_subscriptions_key;
ALTER TABLE crm.crm_report_subscriptions ADD CONSTRAINT ck_crm_report_subscriptions_key
    CHECK (report_key IN ('sales', 'products', 'customers', 'activities', 'service', 'messaging'));

COMMIT;
