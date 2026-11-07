-- Help Desk R4: a business's SMS settings (the R4 contract left them out).
--
--   hd_sms_settings  one row per business: whether Help Desk sends SMS, and the sender ID shown on
--                    the phone (1 to 11 letters or digits; NULL uses the provider's default)
--
-- SMS is outbound only, through Core's sms-providers/messages/send-for-service route (owner decision
-- D7, provisional). No grants. Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §3, §6.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_sms_settings (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    is_enabled  boolean NOT NULL DEFAULT true,
    sender_id   text CONSTRAINT hd_sms_settings_sender_id_check
                CHECK (sender_id ~ '^[A-Za-z0-9]+$' AND length(sender_id) BETWEEN 1 AND 11),
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (tenant_id, bus_id)
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_sms_settings'::regclass AND conname = 'hd_sms_settings_sender_id_check') THEN
        RAISE EXCEPTION 'hd_sms_settings has no sender_id check';
    END IF;
END $$;

COMMIT;
