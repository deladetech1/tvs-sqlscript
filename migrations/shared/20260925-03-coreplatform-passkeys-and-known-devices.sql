-- Passkeys, and only signing in from a device somebody approved.
--
-- Two features that share one mechanism, which is why they share a migration.
--
-- WHY NOT THE OBVIOUS THING
-- The platform already records a "device" per user in cp_sign_in_sources, with
-- an is_trusted flag nothing has ever read. It is tempting to enforce that
-- flag and call it device restriction. It would not work, in both directions
-- at once:
--
--   * The value stored is the user-agent string. It changes when the browser
--     updates — dev already holds two rows for one Mac that differ only by
--     WebKit build — so enforcing it locks people out for installing updates.
--   * It is a request header the client chooses. Copying it from a real
--     sign-in is one line, so it stops nobody.
--
-- A WebAuthn credential is the opposite: a private key held in the device's
-- secure hardware, non-extractable, and impossible to present from anywhere
-- else. So the credential IS the device registration, and cp_sign_in_sources
-- goes on doing what it already does well — noticing something new and saying
-- so — without being asked to be an identity it cannot be.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. The credentials. One row per device per person.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_webauthn_credentials (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,
    user_id        text        NOT NULL,

    -- The authenticator's own handle for this credential, base64url as the
    -- browser reports it. UNIQUE across the whole table and not just per
    -- tenant: authentication looks a credential up by this alone, before any
    -- user is known, so a collision would be an authentication bypass.
    credential_id  text        NOT NULL,

    -- COSE-encoded public key, base64. The private half never leaves the
    -- device and is not derivable from this, which is the entire point: a
    -- full dump of this table lets nobody sign in as anybody.
    public_key     text        NOT NULL,

    -- Incremented by the authenticator on each use. A signature arriving with
    -- a counter at or below the stored one means two things are answering for
    -- the same credential — i.e. a clone. Some authenticators legitimately
    -- always report 0, so zero must be treated as "not supported" rather than
    -- as evidence.
    sign_count     bigint      NOT NULL DEFAULT 0,

    -- Which make and model of authenticator. Useful for telling somebody
    -- which of their devices a credential is, and for refusing models a
    -- tenant does not accept.
    aaguid         text,

    -- THE FIELD THAT DECIDES WHETHER DEVICE RESTRICTION MEANS ANYTHING.
    --
    -- backup_eligible is the authenticator saying "this credential may sync to
    -- the person's other devices" — an iCloud Keychain or Google Password
    -- Manager passkey. Those are excellent for phishing resistance and useless
    -- for device restriction, because the same credential appears on the
    -- phone, the tablet and the laptop without anybody approving anything.
    --
    -- Stored rather than inferred so the enforcement can refuse a syncing
    -- credential when the tenant asked for device restriction, and allow it
    -- when they only asked for passkeys.
    backup_eligible boolean    NOT NULL DEFAULT false,
    backup_state    boolean    NOT NULL DEFAULT false,

    -- usb / nfc / ble / internal / hybrid, as reported. Shown to the person
    -- so "internal" reads as "this laptop" rather than as a word.
    transports     text,

    -- What the person calls it. Defaults to something derived from the
    -- user-agent at registration, because "Credential 3" helps nobody decide
    -- which one to revoke.
    label          text,

    -- The domain the credential was registered against. Recorded because a
    -- credential is bound to it and CANNOT be moved: if the RP ID ever
    -- changes, every row with the old value is dead, and this is the only way
    -- to tell which those are.
    rp_id          text        NOT NULL,

    -- =================================================================
    -- Approval. Registering a device and being allowed to use it are two
    -- different things, which is what "an admin approves all devices" means.
    -- =================================================================
    -- NULL until an administrator approves it. A credential may be used as a
    -- second factor while unapproved — it still proves possession — but it
    -- cannot satisfy device restriction. That split is deliberate: turning on
    -- passkeys must not silently turn on device restriction too.
    approved_at    timestamptz,
    approved_by    text,

    revoked_at     timestamptz,
    revoked_by     text,
    revoke_reason  text,

    created_at     timestamptz NOT NULL DEFAULT now(),
    last_used_at   timestamptz,
    -- Where it was registered from, for an approver deciding whether they
    -- believe it.
    created_ip     text,
    created_country char(2),

    -- Retention needs these two by convention; see the activity-log purge.
    tenant_scope   text        GENERATED ALWAYS AS (tenant_id) STORED,
    cdatetime      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_cp_webauthn_credential_id UNIQUE (credential_id)
);

CREATE INDEX IF NOT EXISTS ix_cp_webauthn_credentials_user
    ON core_platform.cp_webauthn_credentials (tenant_id, user_id)
    WHERE revoked_at IS NULL;

-- The approval queue: everything registered and not yet decided.
CREATE INDEX IF NOT EXISTS ix_cp_webauthn_credentials_pending
    ON core_platform.cp_webauthn_credentials (tenant_id, created_at DESC)
    WHERE approved_at IS NULL AND revoked_at IS NULL;


-- =====================================================================
-- 2. Challenges.
-- =====================================================================
-- A WebAuthn ceremony is: server issues a random challenge, device signs it,
-- server checks the signature is over THAT challenge. The check is worthless
-- unless the server remembers what it issued, so the challenge cannot live in
-- the browser or in a cookie.
--
-- In the database rather than in memory because the API runs several replicas
-- behind a load balancer: the reply routinely lands on a different process
-- from the one that issued the challenge, and an in-memory store would fail
-- intermittently in a way that looks like a broken authenticator.
CREATE TABLE IF NOT EXISTS core_platform.cp_webauthn_challenges (
    id         text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id  text,
    user_id    text,
    -- 'REGISTER' or 'AUTHENTICATE'. A challenge issued for one must not be
    -- redeemable for the other.
    purpose    text        NOT NULL,
    challenge  text        NOT NULL,
    -- Single use. Set the moment it is redeemed, so a replayed response finds
    -- it already spent rather than valid-until-expiry.
    consumed_at timestamptz,
    expires_at timestamptz NOT NULL,
    cdatetime  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_cp_webauthn_challenges_purpose
        CHECK (purpose IN ('REGISTER', 'AUTHENTICATE'))
);

CREATE INDEX IF NOT EXISTS ix_cp_webauthn_challenges_lookup
    ON core_platform.cp_webauthn_challenges (challenge)
    WHERE consumed_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_cp_webauthn_challenges_expiry
    ON core_platform.cp_webauthn_challenges (expires_at);

-- Challenges are worthless once expired and there will be a great many of
-- them. Pruned on the same schedule as sign-in attempts.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_webauthn_challenges()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_webauthn_challenges
     WHERE expires_at < now() - interval '1 day';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- 3. The switches, at the three levels that already exist.
-- =====================================================================
-- cp_login_settings holds BOTH the per-user row (user_id set) and the
-- per-group row (group_id set), so two columns here cover two of the three
-- levels — and they combine the same most-restrictive way MFA already does.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_login_settings'
           AND column_name = 'is_passkey_enabled'
    ) THEN
        ALTER TABLE core_platform.cp_login_settings
            ADD COLUMN is_passkey_enabled  boolean NOT NULL DEFAULT false,
            ADD COLUMN is_device_restricted boolean NOT NULL DEFAULT false;
    END IF;
END $$;

-- Tenant level. Its own table rather than two more columns on
-- cp_multi_factor_settings: that table is named for one thing and means one
-- thing, and a column called is_device_restricted living inside "multi factor
-- settings" is the kind of place a future reader stops trusting the schema.
CREATE TABLE IF NOT EXISTS core_platform.cp_tenant_auth_settings (
    tenant_id             text        PRIMARY KEY,

    is_passkey_enabled    boolean     NOT NULL DEFAULT false,
    is_device_restricted  boolean     NOT NULL DEFAULT false,

    -- Owners are exempt from device restriction, always, and this records the
    -- decision rather than leaving it implicit in code. Without an exemption
    -- the first administrator to switch device restriction on locks the
    -- organisation out of itself — the same one-way door as an IP allowlist
    -- that omits your own address. Left as a column so the exemption is
    -- visible on the screen and in the audit trail, not folded into an `if`
    -- somebody has to go and find.
    owner_exempt          boolean     NOT NULL DEFAULT true,

    updated_by            text,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
