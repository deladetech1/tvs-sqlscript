-- =====================================================================================
-- A silo database holds exactly one tenant. Say so, and check it.
--
-- This is the first file in migrations/silo/, and it is here because it is a statement
-- that is TRUE of a silo and FALSE of the pool -- which is the whole test for whether
-- something belongs in a class folder rather than in shared/.
--
-- What it catches: a silo whose connection string has been pointed at the wrong
-- database. That is not a hypothetical -- schema-silos.yml refuses outright if a silo's
-- secret resolves to the pooled database, and this is the same guard one layer down,
-- where it runs even when somebody applies the schema by hand.
--
-- It does NOT fail on a silo that is merely empty: a database gets its schema before it
-- gets its tenant, so zero rows is the normal state for a silo that has just been
-- provisioned. Only MORE THAN ONE non-system tenant is a contradiction, and it means
-- this is the pool wearing a silo's connection string.
--
-- Dated 0001-01-01 on purpose, so it sorts first and runs before anything that might
-- assume the database is the one it was supposed to be.
-- =====================================================================================

DO $$
DECLARE
    n_tenants integer;
    names     text;
BEGIN
    IF to_regclass('core_platform.cp_tenants') IS NULL THEN
        -- The very first deploy creates the table after this file; nothing to check yet.
        RAISE NOTICE 'cp_tenants does not exist yet; skipping the single-tenant check';
        RETURN;
    END IF;

    -- Excluding the system tenant by its literal id, NOT by is_system. That column
    -- is TRUE on every row in the dev pool -- including BGCLT and ITech & Touch Hub,
    -- which are ordinary customers -- so filtering on it counted zero tenants and
    -- this check passed happily against a pool holding three. A check that cannot
    -- fire is worse than no check: it reads as a guarantee and is not one.
    SELECT count(*), coalesce(string_agg(tenant_name, ', ' ORDER BY tenant_name), '')
      INTO n_tenants, names
      FROM core_platform.cp_tenants
     WHERE delete_status = 'NOT_DELETED'
       AND id <> 'system-tenant-id';

    IF n_tenants > 1 THEN
        RAISE EXCEPTION
            'This is a SILO database but it holds % tenants (%). A silo holds one. '
            'The likeliest cause is a connection string pointing at the shared pool, '
            'which would apply silo-only SQL to every tenant''s data.',
            n_tenants, names;
    END IF;

    IF n_tenants = 0 THEN
        RAISE NOTICE 'silo check: no tenant yet, which is normal before provisioning';
    ELSE
        RAISE NOTICE 'silo check: one tenant (%), as a silo should have', names;
    END IF;
END $$;
