-- =====================================================================
-- Which locations take online payment
-- ---------------------------------------------------------------------
-- CorePlatform holds the gateway credentials (Paystack, Hubtel, expressPay,
-- Stripe) for the whole tenant. This says where MyStoreGuard should offer
-- paying that way — a tenant may have a gateway connected for one app and not
-- want it on every shop floor, and turning it off here should not mean deleting
-- credentials another app is using.
--
-- One row per business holding the list of locations, rather than a row per
-- location, because the screen sets them together: a switch for the business
-- and a multi-select of the branches it applies to. Saving is then one
-- statement and cannot half-apply, and reading the whole picture is one row.
-- Same shape as msg_price_edit_settings, which already keeps its group and
-- user lists as text[].
--
--   is_enabled = false  ->  off everywhere, whatever loc_ids holds
--   is_enabled = true   ->  on at exactly the locations in loc_ids
--
-- Keeping loc_ids while switched off is deliberate: a business that pauses
-- online payment for a week should not have to reassemble the list afterwards.
--
-- Absent row means off. Nothing changes for a business that never opens the
-- setting, and enabling it is a deliberate act.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_online_payment_settings (
    id          text        PRIMARY KEY,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,

    is_enabled  boolean     NOT NULL DEFAULT false,
    -- Locations that accept online payment. Only meaningful when is_enabled.
    loc_ids     text[]      NOT NULL DEFAULT '{}',

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text
);

-- Added separately as well as in the CREATE, so a database that already has the
-- earlier business-wide version of this table gains the column on redeploy.
ALTER TABLE mystoreguard.msg_online_payment_settings
    ADD COLUMN IF NOT EXISTS loc_ids text[] NOT NULL DEFAULT '{}';

-- One row per business. No soft delete here — a setting is switched off, not deleted.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_online_payment_settings_scope
    ON mystoreguard.msg_online_payment_settings (tenant_id, org_id, bus_id);
