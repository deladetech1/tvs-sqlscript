-- 20260829-03-loandrift-sms-settings.sql
-- Whether this lender texts its borrowers, and under what name.
--
-- The gateway itself — which provider, whose credentials — belongs to the
-- TENANT and lives in core_platform.cp_tenant_sms_providers. This table holds
-- only the part a lender decides for itself: is SMS on, what should the
-- recipient see it come from, and which events are worth a message.
--
-- Business-wide, with no loc_ids, unlike ld_online_payment_settings next door.
-- That one is per-branch because a branch either takes online repayment or does
-- not, and that genuinely differs branch to branch. A text message has no
-- counter: it goes out from the lender, the borrower receives one message, and
-- nobody asks which branch a repayment confirmation came from. Mirrors
-- mystoreguard.msg_sms_settings, which reached the same conclusion.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_sms_settings (
    id          text        PRIMARY KEY,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,

    is_enabled  boolean     NOT NULL DEFAULT false,

    -- What recipients see. Optional: left empty, the tenant's gateway sender is
    -- used, which is the sensible default for a tenant running one business.
    -- Set, it lets two businesses under one tenant sign their messages
    -- differently without configuring two gateways.
    --
    -- Still has to be a sender the provider has approved — this decides which
    -- registered name is used, it cannot invent one.
    sender_id   text,

    -- Which events send. Separate from is_enabled because a lender turning SMS
    -- on for reminders has not thereby agreed to text every borrower every time
    -- a clerk records a payment — that is a per-message cost they should choose.
    --
    -- Defaults true: switching SMS on at all, today, can only mean this, since
    -- it is the one event that sends. A lender who does not want it turns this
    -- off on the same screen where they turned SMS on.
    notify_on_repayment boolean NOT NULL DEFAULT true,

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text
);

-- Added separately as well as in the CREATE, so a database that already has an
-- earlier version of this table gains the column on redeploy.
ALTER TABLE loandrift.ld_sms_settings
    ADD COLUMN IF NOT EXISTS notify_on_repayment boolean NOT NULL DEFAULT true;

-- One row per business. The service upserts on this.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_sms_settings_business
    ON loandrift.ld_sms_settings (tenant_id, org_id, bus_id);
