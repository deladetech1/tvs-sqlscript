-- =====================================================================================
-- ON DELETE SET NULL stops trying to null the tenant id.
--
-- Twelve foreign keys reference cp_users(id, tenant_id) as a PAIR and carry ON DELETE SET
-- NULL. Postgres nulls EVERY column of the key, not just the one naming the person, and
-- tenant_id is NOT NULL on all twelve tables. So deleting a user raised
--
--     null value in column "tenant_id" of relation "cp_otps" violates not-null constraint
--     CONTEXT: SET "created_by" = NULL, "tenant_id" = NULL
--
-- and the screen said "User Deletion failed. Please try again." Trying again did the same
-- thing: one OTP row, written the first time that person signed in, made the account
-- undeletable forever.
--
-- Postgres 15 added a column list for exactly this, and production runs 17: name the one
-- column to blank and tenant_id is left alone. The rows keep their tenant, the authorship
-- becomes unknown, which is what SET NULL was reaching for in the first place.
--
-- The same shape as the MyStoreGuard SetNull-over-PK bug, where a default SET NULL nulled
-- columns of a composite primary key. It is worth knowing that EF's default for an optional
-- relationship produces this, and that a composite key makes it a bug rather than a choice.
-- =====================================================================================

DO $$
DECLARE
    fk RECORD;
    user_col TEXT;
BEGIN
    FOR fk IN
        SELECT c.oid,
               c.conname,
               c.conrelid::regclass::text AS tbl,
               (SELECT a.attname
                  FROM unnest(c.conkey) WITH ORDINALITY k(attnum, ord)
                  JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
                 WHERE a.attname <> 'tenant_id'
                 LIMIT 1) AS person_col
          FROM pg_constraint c
         WHERE c.confrelid = 'core_platform.cp_users'::regclass
           AND c.contype = 'f'
           AND c.confdeltype = 'n'
           AND array_length(c.conkey, 1) = 2
    LOOP
        user_col := fk.person_col;
        IF user_col IS NULL THEN
            CONTINUE;
        END IF;

        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', fk.tbl, fk.conname);
        EXECUTE format(
            'ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I, tenant_id) '
            'REFERENCES core_platform.cp_users(id, tenant_id) ON DELETE SET NULL (%I)',
            fk.tbl, fk.conname, user_col, user_col);

        RAISE NOTICE 'rewrote % on % to null only %', fk.conname, fk.tbl, user_col;
    END LOOP;
END $$;
