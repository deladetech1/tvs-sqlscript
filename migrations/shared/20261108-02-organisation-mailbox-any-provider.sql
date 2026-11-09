-- Core Platform: an organisation's own mailbox may be on any provider.
--
-- cp_notification_email_credentials (the organisation's mailbox, used for its email when a
-- business has none of its own, and for its security email) gains the server: provider
-- (gmail | microsoft365 | outlook | zoho | yahoo | custom), smtp_host, smtp_port,
-- smtp_security (ssl | starttls) and username. All nullable: a row without them is Gmail on
-- 465/SSL signing in as the address, which is what every row meant until now.
--
-- notification_password is unchanged here. core-platform writes it encrypted ("enc::" +
-- Fernet) once every reader goes through core or trovesuite >= 1.0.66; plain values stay
-- readable.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE core_platform.cp_notification_email_credentials ADD COLUMN IF NOT EXISTS provider      text;
ALTER TABLE core_platform.cp_notification_email_credentials ADD COLUMN IF NOT EXISTS smtp_host     text;
ALTER TABLE core_platform.cp_notification_email_credentials ADD COLUMN IF NOT EXISTS smtp_port     integer;
ALTER TABLE core_platform.cp_notification_email_credentials ADD COLUMN IF NOT EXISTS smtp_security text;
ALTER TABLE core_platform.cp_notification_email_credentials ADD COLUMN IF NOT EXISTS username      text;

ALTER TABLE core_platform.cp_notification_email_credentials DROP CONSTRAINT IF EXISTS cp_notification_email_credentials_server_check;
ALTER TABLE core_platform.cp_notification_email_credentials ADD CONSTRAINT cp_notification_email_credentials_server_check CHECK (
    (provider IS NULL OR provider IN ('gmail', 'microsoft365', 'outlook', 'zoho', 'yahoo', 'custom'))
    AND (smtp_port IS NULL OR smtp_port IN (25, 465, 587, 2525))
    AND (smtp_security IS NULL OR smtp_security IN ('ssl', 'starttls')));

COMMIT;
