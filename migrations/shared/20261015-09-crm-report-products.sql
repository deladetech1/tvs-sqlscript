-- CRM: any report can be emailed. The list of reports lives in the app (it grows with every
-- release, and the app refuses a key it does not know), so the database only checks the shape.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE crm.crm_report_subscriptions DROP CONSTRAINT IF EXISTS ck_crm_report_subscriptions_key;
ALTER TABLE crm.crm_report_subscriptions ADD CONSTRAINT ck_crm_report_subscriptions_key
    CHECK (report_key ~ '^[a-z][a-z0-9-]{1,40}$');

COMMIT;
