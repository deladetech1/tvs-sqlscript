-- =====================================================================================
-- A whole tenant can be locked out.
--
-- WHY A NEW COLUMN AND NOT is_active
-- cp_tenants.is_active already exists and reads like the right switch. It is not:
-- nothing in the sign-in path looks at it. Setting it false today changes nothing at
-- all, which is the worst possible outcome for a lock -- somebody uses it, believes the
-- client is suspended, and the client keeps working. It is also read by other code for
-- other reasons, so giving it a second meaning would make both ambiguous.
--
-- This is the same trap as cp_tenants.is_system, which is true for a real paying client
-- and therefore useless as "not a customer". A flag whose meaning has drifted cannot be
-- borrowed for a new decision.
--
-- WHY THE EXTRA COLUMNS
-- Locking a customer out of their own system is the most disruptive reversible thing
-- this console can do. "Who did this and why" has to survive it, and has to be
-- answerable at the moment somebody is on the phone asking -- which rules out reading
-- it back out of an audit log in another schema.
--
-- WHY shared/ AND NOT saas/
-- Unlike the billing ledger, this is per-TENANT state and belongs in the database that
-- holds the tenant. A silo's tenants live in the silo's own database, so the column has
-- to exist there too, which is what shared/ means.
-- =====================================================================================

ALTER TABLE core_platform.cp_tenants
    ADD COLUMN IF NOT EXISTS is_locked   boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS locked_at   timestamptz,
    ADD COLUMN IF NOT EXISTS locked_by   text,
    ADD COLUMN IF NOT EXISTS lock_reason text;

COMMENT ON COLUMN core_platform.cp_tenants.is_locked IS
    'Suspended by us. Every user of this tenant is refused at sign-in. NOT the same as '
    'is_active, which the sign-in path does not read, or is_verified, which means the '
    'tenant has not confirmed its email yet.';
COMMENT ON COLUMN core_platform.cp_tenants.lock_reason IS
    'Shown to whoever asks why. Stored beside the flag so the answer survives the lock '
    'and does not have to be dug out of an audit log while a customer is on the phone.';

-- Finding the locked ones is a question somebody asks ("who have we suspended?"), and
-- the sign-in path reads the flag on every login, so it is worth an index only where it
-- is selective -- which is the locked side.
CREATE INDEX IF NOT EXISTS ix_cp_tenants_locked
    ON core_platform.cp_tenants (is_locked) WHERE is_locked;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
       AND column_name IN ('is_locked', 'locked_at', 'locked_by', 'lock_reason');
    IF n <> 4 THEN
        RAISE EXCEPTION 'the lock columns were not all created (% of 4)', n;
    END IF;

    -- Nobody is locked by the migration itself. A schema change that suspends a
    -- customer is the kind of thing that happens once and is never forgotten.
    SELECT count(*) INTO n FROM core_platform.cp_tenants WHERE is_locked;
    IF n > 0 THEN
        RAISE EXCEPTION '% tenant(s) are locked immediately after adding the column', n;
    END IF;

    -- The default must be false rather than NULL: a NOT NULL boolean read as "is this
    -- locked" is the one place a three-valued answer would be dangerous.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_tenants'
       AND column_name = 'is_locked' AND (is_nullable <> 'NO' OR column_default IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION 'is_locked is nullable or has no default';
    END IF;

    RAISE NOTICE 'a tenant can be locked';
END $$;
