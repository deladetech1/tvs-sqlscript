-- 20260828-02-mystoreguard-sms-settings.sql
-- Whether this business sends SMS, and under what name.
--
-- The gateway itself — which provider, whose credentials — belongs to the
-- TENANT and lives in core_platform.cp_tenant_sms_providers. This table holds
-- only the part a shop decides for itself: is SMS on, and what should the
-- recipient see it come from.
--
-- Business-wide, with no loc_ids, unlike msg_online_payment_settings next door.
-- That one is per-location because a till either takes cards or does not, and
-- that genuinely differs branch to branch. A text message has no till: it goes
-- out from the business, the customer receives one message, and nobody asks
-- which branch a reminder came from. A location column here would be a filter
-- nothing filters on, which is how msg_online_payment_settings' own history
-- went — it started business-wide and grew the column when a real per-location
-- question appeared. There isn't one here.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_sms_settings (
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

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text
);

-- One row per business. The service upserts on this.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_sms_settings_business
    ON mystoreguard.msg_sms_settings (tenant_id, org_id, bus_id);
