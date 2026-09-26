-- Letting a person choose HOW their sign-in code reaches them.
--
-- Three ways now: an email, a text message, or an authenticator app. Until this
-- migration the choice was implicit and made for them — enrolling an app
-- silently stopped the emails, and there was no way to say "I would rather have
-- a text" at all, even though plenty of people prefer one and some have no
-- practical access to email on the device they are signing in on.
--
-- Two separate questions, deliberately
-- ------------------------------------
-- What a TENANT permits, and what a PERSON prefers. They are different
-- decisions with different owners: an organisation may not want codes going to
-- personal phones, and within whatever it does allow, the choice of which is
-- nobody's business but the person's.
--
-- Nothing about WHETHER multi-factor applies changes here. That is still
-- cp_login_settings.is_multi_factor_enabled resolved across tenant, group and
-- user. This is only about delivery.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. What the tenant permits.
-- =====================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_tenant_auth_settings'
           AND column_name = 'allow_mfa_email'
    ) THEN
        -- Email defaults TRUE because it is what every existing tenant already
        -- uses. Turning this migration on must not change how a single person
        -- currently signs in.
        --
        -- SMS defaults TRUE as well, but that is a weaker claim: it only
        -- becomes usable for somebody who has a phone number on their account
        -- AND whose tenant has an SMS provider configured. Absent either, the
        -- option is not offered — see sh_mfa.available_methods. Defaulting it
        -- off would instead have meant the feature existed and nobody found it.
        ALTER TABLE core_platform.cp_tenant_auth_settings
            ADD COLUMN allow_mfa_email boolean NOT NULL DEFAULT true,
            ADD COLUMN allow_mfa_sms   boolean NOT NULL DEFAULT true;
    END IF;
END $$;


-- =====================================================================
-- 2. What the person prefers.
-- =====================================================================
-- Its own table rather than a column on cp_login_settings, which holds BOTH
-- per-user and per-group rows. A delivery preference is meaningless on a group
-- row — a group does not own a phone — and a column that is only sometimes
-- applicable is a column somebody will read on the wrong row.
CREATE TABLE IF NOT EXISTS core_platform.cp_mfa_preferences (
    tenant_id  text        NOT NULL,
    user_id    text        NOT NULL,

    -- EMAIL, SMS or APP. A preference, not a guarantee: if the chosen method
    -- stops being available — the tenant withdraws it, the app is removed, the
    -- phone number is deleted — sign-in falls back to something that works
    -- rather than refusing. A preference that can lock somebody out is not a
    -- preference, it is a trap.
    method     text        NOT NULL,

    updated_at timestamptz NOT NULL DEFAULT now(),
    cdatetime  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_cp_mfa_preferences PRIMARY KEY (tenant_id, user_id),
    CONSTRAINT ck_cp_mfa_preferences_method
        CHECK (method IN ('EMAIL', 'SMS', 'APP'))
);


-- =====================================================================
-- 3. Backfill, so nothing changes for anybody already set up.
-- =====================================================================
-- Anyone who had already enrolled an authenticator app was, in effect, choosing
-- APP: that is what the old implicit precedence gave them. Recording it makes
-- the behaviour they already have explicit and visible on the screen, rather
-- than leaving them to discover their preference reads "email" while codes
-- arrive in an app.
--
-- Only where there is no row yet, so a deliberate choice is never overwritten.
INSERT INTO core_platform.cp_mfa_preferences (tenant_id, user_id, method)
SELECT tenant_id, user_id, 'APP'
  FROM core_platform.cp_totp_credentials
 WHERE confirmed_at IS NOT NULL
ON CONFLICT (tenant_id, user_id) DO NOTHING;
