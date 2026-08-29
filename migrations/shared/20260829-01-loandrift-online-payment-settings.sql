-- 20260829-01-loandrift-online-payment-settings.sql
-- Where LoanDrift offers a borrower a card or mobile-money repayment.
--
-- CorePlatform holds the gateway credentials (Paystack, Hubtel, expressPay,
-- Stripe) for the whole tenant, in core_platform.cp_tenant_payment_providers.
-- This says where LoanDrift should offer paying that way. A lender may have a
-- gateway connected because MyStoreGuard uses it and still not want a branch
-- collecting repayments through it, and switching that off here must not mean
-- deleting credentials another app depends on.
--
-- Deliberately the same shape as mystoreguard.msg_online_payment_settings:
-- one row per business holding the list of branches, because the screen sets
-- them together — a switch for the business and a multi-select of the branches
-- it applies to. Saving is then one statement that cannot half-apply.
--
--   is_enabled = false  ->  off everywhere, whatever loc_ids holds
--   is_enabled = true   ->  on at exactly the branches in loc_ids
--
-- Keeping loc_ids while switched off is deliberate: a lender pausing online
-- repayment for a week should not have to reassemble the list afterwards.
--
-- Absent row means off. Nothing changes for a business that never opens the
-- setting, and enabling it is a deliberate act.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.

CREATE TABLE IF NOT EXISTS loandrift.ld_online_payment_settings (
    id          text        PRIMARY KEY,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,

    is_enabled  boolean     NOT NULL DEFAULT false,
    -- Branches that accept online repayment. Only meaningful when is_enabled.
    loc_ids     text[]      NOT NULL DEFAULT '{}',

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text
);

-- One row per business. No soft delete — a setting is switched off, not deleted.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_online_payment_settings_scope
    ON loandrift.ld_online_payment_settings (tenant_id, org_id, bus_id);
