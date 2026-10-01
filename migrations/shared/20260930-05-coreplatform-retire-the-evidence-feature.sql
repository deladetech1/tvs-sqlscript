-- =====================================================================================
-- Retire the Evidence feature: the tamper-evident hash chain.
--
-- DO NOT RUN THIS UNTIL 20260930-04 HAS RUN AND THE CODE THAT STOPPED READING THE CHAIN
-- COLUMNS IS DEPLOYED. It drops columns a previous release still selects, and that release
-- answers 500 on every security event read the moment they are gone.
--
-- What goes:
--   * the trigger that stamps each event, and the function behind it
--   * the verifier the retired screen called
--   * chain_seq, prev_hash, row_hash
--   * the feature itself: its catalogue entry, which is the only place it is recorded
--
-- What stays: every security event, and `seq` from 20260930-04, which carries the ordering
-- the feed needs. Retiring the evidence does not retire the record.
--
-- There are no tenant rows to delete or disable. Platform entitlement is derived, not
-- stored -- cp_tenant_platform_features is a view over the catalogue and each tenant's
-- tier_rank -- so removing the catalogue entry is what makes the feature cease to exist
-- for everybody at once. Nobody is left entitled to something that does not exist.
-- =====================================================================================

DROP TRIGGER IF EXISTS trg_cp_security_events_chain ON core_platform.cp_security_events;

-- Dropped by oid, one overload at a time, rather than by a written-out signature.
-- cp_verify_security_chain grew a second argument along the way, so this ran as a deploy
-- against several shapes: (text) in the first release, (text, integer) after. A DROP naming
-- the wrong one is not an error -- IF EXISTS matches nothing and says nothing -- and the
-- function stays behind, reachable, reading columns this migration is about to remove.
DO $$
DECLARE
    fn regprocedure;
BEGIN
    FOR fn IN
        SELECT p.oid::regprocedure
          FROM pg_proc p
         WHERE p.pronamespace = 'core_platform'::regnamespace
           AND p.proname IN ('cp_chain_security_event', 'cp_verify_security_chain')
    LOOP
        EXECUTE format('DROP FUNCTION %s CASCADE', fn);
    END LOOP;
END $$;

ALTER TABLE core_platform.cp_security_events
    DROP COLUMN IF EXISTS chain_seq,
    DROP COLUMN IF EXISTS prev_hash,
    DROP COLUMN IF EXISTS row_hash;

-- Deleting the catalogue row is the whole job. There is no per-tenant entitlement to
-- clear: cp_tenant_platform_features is a VIEW joining cp_tenant_platform_limits to
-- cp_platform_feature_catalog on tier_rank >= min_tier_rank, so a tenant "holds" a
-- feature by being on a high enough tier, not by owning a row. The two tenants that
-- can see this feature today see it for that reason alone, and stop seeing it the
-- moment the catalogue row below is gone.
--
-- This previously tried to DELETE from that view, which a join view cannot accept --
-- 55000: cannot delete from view -- and it failed every deploy of the shared SQL.
DELETE FROM core_platform.cp_platform_feature_catalog
 WHERE feature_key = 'security.tamper-evident';

-- The alert the verifier used to raise can no longer be raised, and the provider that put it
-- in the bell is gone. Anything still open would sit there for ever with nothing able to
-- clear it, so it is resolved here and told why.
--
-- RESOLVED, not CLOSED: the status check allows OPEN, ACKNOWLEDGED and RESOLVED, and nothing
-- else. The event itself stays -- it is a security record, and retiring the feature that
-- raised it is not a reason to delete the finding.
UPDATE core_platform.cp_security_events
   SET status = 'RESOLVED',
       status_note = COALESCE(status_note || ' | ', '')
                     || 'Resolved automatically: the tamper-evident feature was retired.',
       status_changed_at = now()
 WHERE event_type = 'security_record_broken'
   AND status <> 'RESOLVED';
