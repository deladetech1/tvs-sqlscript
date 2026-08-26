-- =====================================================================
-- msg_batch_locations.purchase_batche_id must always name a batch
-- ---------------------------------------------------------------------
-- A row here says "this much of THIS delivery sits at THIS location". With
-- no batch it says nothing: product-level views reach the ledger by joining
-- through msg_purchase_batches, so such a row is invisible to every stock
-- figure while still being counted in the location's cached total. That is
-- how a stock take came to snapshot 29 units of a product the store showed
-- as 0.
--
-- Nothing legitimately writes one — all nine insert paths in the service
-- name the column, and the only row of this shape ever recorded came from
-- a reversal falling back to an insert when the original correction had no
-- delivery reference. That fallback is gone and the reversal now refuses
-- such a correction outright; this makes the shape unstorable regardless of
-- which code path is at fault next time.
--
-- Runs after 20260813-01, which clears any such row, so the column is empty
-- of NULLs by the time this executes. If one somehow remains the constraint
-- is skipped with a warning rather than failing the deploy.
--
-- Idempotent: SET NOT NULL on an already-constrained column is a no-op.
-- =====================================================================

DO $$
DECLARE
    stragglers integer;
BEGIN
    SELECT COUNT(*) INTO stragglers
    FROM mystoreguard.msg_batch_locations
    WHERE purchase_batche_id IS NULL;

    IF stragglers > 0 THEN
        RAISE WARNING 'msg_batch_locations still has % row(s) with no batch; '
                      'leaving the column nullable. Investigate before this '
                      'constraint can be applied.', stragglers;
    ELSE
        -- Hardening, not a schema requirement of any feature: if this database's
        -- deploy role doesn't own the table, warn and carry on rather than fail
        -- the run. The service-level guard is what actually prevents the bug.
        BEGIN
            ALTER TABLE mystoreguard.msg_batch_locations
                ALTER COLUMN purchase_batche_id SET NOT NULL;
        EXCEPTION
            WHEN insufficient_privilege THEN
                RAISE WARNING 'Not the owner of msg_batch_locations; leaving '
                              'purchase_batche_id nullable. Apply as the owner to '
                              'get the database-level guard.';
        END;
    END IF;
END $$;
