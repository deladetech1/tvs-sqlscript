-- Core Platform: a business may send its own email.
--
-- When an app sends email for a business (invoices, receipts, statements, reminders, CRM),
-- Core tries, in order: the business's own mailbox (this table), then the organisation's
-- (cp_notification_email_credentials), then TroveSuite's. Security email (sign-in codes,
-- password resets, invitations) never uses a business mailbox: organisation, then TroveSuite.
--
--   provider        gmail | microsoft365 | outlook | zoho | yahoo | custom (presets the server)
--   smtp_*          the server; security is ssl (implicit TLS, usually 465) or starttls (587)
--   username        usually the address itself
--   password_enc    Fernet-encrypted by core-platform ("enc::" + token); never stored in clear
--   last_test_*     the last "Send test email" result
--   last_error / last_failed_at   the last real send that failed (it then went out through
--                   the next mailbox); last_alert_at keeps the admin alert to once a day
--
-- One live row per business. Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_business_email_senders (
    tenant_id       text        NOT NULL,
    id              text        NOT NULL,
    bus_id          text        NOT NULL,
    provider        text        NOT NULL DEFAULT 'custom'
                    CHECK (provider IN ('gmail', 'microsoft365', 'outlook', 'zoho', 'yahoo', 'custom')),
    from_email      text        NOT NULL,
    from_name       text,
    smtp_host       text        NOT NULL,
    smtp_port       integer     NOT NULL CHECK (smtp_port IN (25, 465, 587, 2525)),
    smtp_security   text        NOT NULL DEFAULT 'ssl' CHECK (smtp_security IN ('ssl', 'starttls')),
    username        text        NOT NULL,
    password_enc    text        NOT NULL,
    is_active       boolean     NOT NULL DEFAULT true,
    last_test_at    timestamptz,
    last_test_ok    boolean,
    last_test_error text,
    last_error      text,
    last_failed_at  timestamptz,
    last_alert_at   timestamptz,
    last_sent_at    timestamptz,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text,
    PRIMARY KEY (tenant_id, id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_business_email_senders_live
    ON core_platform.cp_business_email_senders (tenant_id, bus_id)
    WHERE delete_status = 'NOT_DELETED';

COMMIT;
