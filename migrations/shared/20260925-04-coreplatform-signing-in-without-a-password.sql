-- Letting an organisation drop the password entirely.
--
-- Passkeys shipped as a SECOND factor: password, then a fingerprint instead of
-- an emailed code. That is the right default and it is what most tenants will
-- want, because it changes nothing about how people think about signing in.
--
-- But a passkey is a stronger proof than a password on its own — it cannot be
-- guessed, reused, leaked in somebody else's breach, or phished — so requiring
-- a password alongside it is, for some organisations, protecting a strong thing
-- with a weak one. This makes that an organisation's choice rather than ours.
--
-- Three switches now, and they are deliberately independent:
--
--   is_passkey_enabled    may a device stand in for the emailed code
--   allow_passwordless    may a device stand in for the PASSWORD too
--   is_device_restricted  must the device be one somebody approved
--
-- allow_passwordless does nothing on its own. Without is_passkey_enabled there
-- is no passkey to sign in with, which is why it is a separate column rather
-- than a third value of one setting — a tenant turning it on while passkeys are
-- off has made a mistake, and the screen can say so.
--
-- Idempotent; safe to re-run on every deploy.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_tenant_auth_settings'
           AND column_name = 'allow_passwordless'
    ) THEN
        ALTER TABLE core_platform.cp_tenant_auth_settings
            ADD COLUMN allow_passwordless boolean NOT NULL DEFAULT false;
    END IF;

    -- Per-user and per-group too, in the same table that already holds the
    -- other two, so all three resolve the same way MFA does.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_login_settings'
           AND column_name = 'allow_passwordless'
    ) THEN
        -- NULLABLE here, unlike the tenant column, and that is the whole
        -- point: NULL means "no opinion", false means "explicitly refuse".
        -- With NOT NULL DEFAULT false the two would be indistinguishable, and
        -- every group would read as refusing something nobody had decided.
        ALTER TABLE core_platform.cp_login_settings
            ADD COLUMN allow_passwordless boolean;
    END IF;
END $$;

-- How this one resolves, and why it is not like the others.
--
-- The other switches are most-restrictive-wins: if the tenant, or any group you
-- are in, or your own row turns something ON, it applies to you. That is right
-- for a restriction and wrong for a permission — under the same rule, one
-- permissive group could drop the password for somebody the tenant meant to
-- keep it for.
--
-- So: the TENANT grants it, and a group or a user row may WITHHOLD it. Nothing
-- below the tenant can grant what the tenant did not. The tenant column
-- therefore defaults to false (an absent decision is never permission), and the
-- per-user/group column is nullable so that "no opinion" and "no" are different
-- answers. See sh_device_access.resolve.
