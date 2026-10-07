-- ---------------------------------------------------------------------------
-- A shared silo's database server is a property of the CELL, not of the client.
--
-- THE PROBLEM THIS SOLVES
--
-- Adding a shared silo meant typing `tvs-shared-sql.postgres.database.azure.com`
-- into a form, every time, for a server we run and already know. That is not a
-- question anybody can answer better than we can, and it has exactly one wrong
-- answer per environment: a route that names the WRONG shared server points a
-- client's requests at a database holding somebody else's data, which is the
-- failure this whole table exists to prevent.
--
-- So the cell carries it, and the route is filled in from the cell.
--
-- WHY A COLUMN AND NOT A CONVENTION
--
-- It is tempting to derive the name -- `tvs-<env>-sql` almost works. It is
-- wrong twice. The real roster in tvs-iac (`platform/<env>/env.hcl`) lets a
-- silo name a DIFFERENT server unit when one runs out of room ("the next silo
-- names a different unit here and nothing else changes" -- connections run out
-- first, one pool per app per silo). And dev and staging deliberately share one
-- server while prod has its own. A convention cannot express either, so the
-- fact is stored where it can be corrected without a release.
--
-- NULL IS MEANINGFUL, AND IT MEANS "NO SHARED SILOS HERE".
--
-- bgclt-prod is one client's own installation in their own Azure tenant. A
-- "shared" silo in that cell would mean putting a second client's database on
-- the first client's server, which is not a thing we will ever do. NULL says
-- so, and the console refuses SILO_SHARED in a cell that has none rather than
-- writing a route with no server in it.
-- ---------------------------------------------------------------------------
ALTER TABLE control_plane.ctl_cells
    ADD COLUMN IF NOT EXISTS shared_db_server_fqdn text;

COMMENT ON COLUMN control_plane.ctl_cells.shared_db_server_fqdn IS
    'The Postgres server a SILO_SHARED route in this cell uses. NULL means this '
    'cell hosts no shared silos (a client-owned installation), and the console '
    'refuses SILO_SHARED there. From tvs-iac platform/<env>/env.hcl db.server.';

-- The roster, from tvs-iac. platform/dev and platform/staging provision no
-- server of their own -- their apps create roles on the shared one -- so both
-- name it. platform/prod has tvs-prod-sql.
UPDATE control_plane.ctl_cells
   SET shared_db_server_fqdn = 'tvs-shared-sql.postgres.database.azure.com',
       udatetime  = now(),
       updated_by = 'migration'
 WHERE cell_key IN ('uksouth-dev', 'uksouth-staging')
   AND shared_db_server_fqdn IS DISTINCT FROM 'tvs-shared-sql.postgres.database.azure.com';

UPDATE control_plane.ctl_cells
   SET shared_db_server_fqdn = 'tvs-prod-sql.postgres.database.azure.com',
       udatetime  = now(),
       updated_by = 'migration'
 WHERE cell_key = 'uksouth-prod'
   AND shared_db_server_fqdn IS DISTINCT FROM 'tvs-prod-sql.postgres.database.azure.com';

-- bgclt-prod is left NULL on purpose. See the header.

-- ---------------------------------------------------------------------------
-- The existing shared silos must already agree with their cell, or the next
-- edit of one of those rows would silently move it to a different server.
--
-- This is an assertion, not a repair. If a live shared silo names a server its
-- cell does not, one of the two is wrong and a human has to decide which --
-- quietly rewriting the route would be changing which database a client's
-- requests reach, inside a migration, without anyone asking.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(
               format('%s (cell %s says %s, route says %s)',
                      r.host, r.cell_key,
                      coalesce(c.shared_db_server_fqdn, '<none>'),
                      coalesce(r.db_server_fqdn, '<none>')),
               '; ' ORDER BY r.host)
      INTO bad
      FROM control_plane.ctl_tenant_routes r
      JOIN control_plane.ctl_cells c USING (cell_key)
     WHERE r.tier = 'SILO_SHARED'
       AND r.db_server_fqdn IS DISTINCT FROM c.shared_db_server_fqdn;

    IF bad IS NOT NULL THEN
        RAISE EXCEPTION
            'shared silos disagree with their cell''s server: %. Fix the cell or the route by hand -- this migration will not guess which is right.',
            bad;
    END IF;
END $$;
