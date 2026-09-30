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
--   * the feature itself: its catalogue entry, and the entitlement of every tenant holding it
--
-- What stays: every security event, and `seq` from 20260930-04, which carries the ordering
-- the feed needs. Retiring the evidence does not retire the record.
--
-- The tenant rows are deleted rather than disabled. A feature nobody can be granted has no
-- use for a row saying a tenant is not granted it, and leaving them means the next person to
-- read that table finds three tenants entitled to something that does not exist.
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

DELETE FROM core_platform.cp_tenant_platform_features
 WHERE feature_key = 'security.tamper-evident';

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
