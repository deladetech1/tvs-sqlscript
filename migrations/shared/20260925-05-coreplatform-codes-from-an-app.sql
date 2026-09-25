-- A six-digit code from an app, instead of one from an email.
--
-- Authy, Google Authenticator, Microsoft Authenticator, 1Password, Bitwarden
-- and the rest are all the same protocol: TOTP, RFC 6238. There is nothing to
-- integrate with any of them individually — they scan the same QR code and
-- compute the same code from the same shared secret. One feature, not three.
--
-- Where this sits relative to the other two
-- ----------------------------------------
-- A passkey is stronger: its signature is bound to this site's address, so a
-- convincing copy of the sign-in page cannot use it. A TOTP code can be
-- phished exactly like the emailed one — the fake page asks for it and relays
-- it inside its thirty-second window.
--
-- So this is not a security upgrade over passkeys. It is an upgrade over
-- EMAIL: no waiting on delivery, no inbox, and it works with no signal. That
-- is worth having for the people who will not set up a passkey, which is most
-- people, and the sign-in path prefers a passkey when there is one.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. The shared secret. One per person.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_totp_credentials (
    id           text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text        NOT NULL,
    user_id      text        NOT NULL,

    -- Encrypted, not hashed. Unlike a password this has to be READ back: the
    -- server recomputes the expected code from it on every sign-in, so a
    -- one-way hash would make it useless. Fernet, with a key derived for this
    -- purpose alone — see sh_totp.
    --
    -- Which also means a database dump is enough to generate codes, and is why
    -- it is encrypted rather than stored as it arrives.
    secret       text        NOT NULL,

    -- NULL until the person has typed a code back correctly.
    --
    -- Enrolment is not finished when the QR code is shown; it is finished when
    -- they prove the app actually holds the secret. Without this a mis-scan
    -- would enable MFA against a secret nobody has, and lock them out at the
    -- next sign-in.
    confirmed_at timestamptz,

    -- The time step of the last code accepted.
    --
    -- TOTP allows a small window either side of now, to tolerate clock drift.
    -- That window is also a replay window: the same code stays valid for
    -- ninety seconds. Requiring the next code to come from a LATER step than
    -- the last one closes it, so a code observed in flight cannot be reused.
    last_step    bigint,
    last_used_at timestamptz,

    created_at   timestamptz NOT NULL DEFAULT now(),
    created_ip   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),

    -- One per person. A second authenticator is a second phone with the SAME
    -- secret, which is how these apps are meant to be used; two secrets for
    -- one account would mean two things to disable and one of them forgotten.
    CONSTRAINT uq_cp_totp_credentials_user UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_cp_totp_credentials_user
    ON core_platform.cp_totp_credentials (tenant_id, user_id)
    WHERE confirmed_at IS NOT NULL;


-- =====================================================================
-- 2. Recovery codes.
-- =====================================================================
-- The thing that makes this safe to switch on.
--
-- A lost or wiped phone takes the secret with it, and without a way back the
-- only recovery is an administrator turning MFA off for somebody who cannot
-- prove who they are — which is precisely the call nobody should have to make
-- under pressure.
--
-- Hashed, not encrypted, because unlike the secret these are never read back:
-- a code is checked by hashing what was typed and looking for a match. Shown
-- once, at enrolment, and never again.
CREATE TABLE IF NOT EXISTS core_platform.cp_totp_recovery_codes (
    id         text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text        NOT NULL,
    user_id    text        NOT NULL,
    -- SHA-256 of the code. Not bcrypt: these are long random strings, not
    -- human-chosen passwords, so there is nothing to slow an attacker down
    -- FOR — and a slow hash on the sign-in path buys nothing here.
    code_hash  text        NOT NULL,
    used_at    timestamptz,
    cdatetime  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_cp_totp_recovery_code UNIQUE (tenant_id, user_id, code_hash)
);

CREATE INDEX IF NOT EXISTS ix_cp_totp_recovery_codes_unused
    ON core_platform.cp_totp_recovery_codes (tenant_id, user_id)
    WHERE used_at IS NULL;


-- =====================================================================
-- 3. Which second factor a tenant wants.
-- =====================================================================
-- Nothing is removed. A tenant that changes nothing keeps emailed codes, and
-- anybody who enrols an app simply stops receiving them.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_tenant_auth_settings'
           AND column_name = 'allow_authenticator_app'
    ) THEN
        -- Default TRUE, unlike every other switch here, and deliberately.
        --
        -- The others grant or impose something. This one only changes how an
        -- existing requirement is DELIVERED: a tenant already requiring MFA
        -- gets it by email today, and letting somebody use an app instead is
        -- strictly better for them and no weaker for the tenant. Defaulting it
        -- off would mean the feature existed and nobody found it.
        ALTER TABLE core_platform.cp_tenant_auth_settings
            ADD COLUMN allow_authenticator_app boolean NOT NULL DEFAULT true;
    END IF;
END $$;


-- Spent and abandoned enrolments. An unconfirmed row is a QR code somebody
-- looked at and walked away from; it authorises nothing, and keeping it means
-- the next attempt collides with the UNIQUE constraint above.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_unconfirmed_totp()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_totp_credentials
     WHERE confirmed_at IS NULL
       AND created_at < now() - interval '1 hour';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;
