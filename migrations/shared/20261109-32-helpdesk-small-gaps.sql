-- Help Desk: the small gaps of R3 (docs/helpdesk/OWNER-BRIEF.md §5).
--
--   hd_status_events.severity   what an open incident does to the components it names:
--                               degraded, partial_outage or major_outage (NULL: the state decides,
--                               as before). Incidents only; maintenance never has one. It is the
--                               only way a component reaches major_outage.
--
-- The other three gaps need no schema: a portal request's assets go in hd_ticket_assets (-13), a
-- licence's holders are read with their names from core_platform.cp_users, and tickets already
-- have vendor_party_id (-11) -- the API now sets it.
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants, no data
-- written. Idempotent; safe to re-run on every deploy. A database without Help Desk is left alone.

BEGIN;

DO $$
BEGIN
    IF to_regclass('helpdesk.hd_status_events') IS NULL THEN
        RAISE NOTICE 'helpdesk small gaps: no helpdesk schema here; nothing to do';
        RETURN;
    END IF;

    ALTER TABLE helpdesk.hd_status_events ADD COLUMN IF NOT EXISTS severity text;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_status_events'::regclass AND conname = 'hd_status_events_severity_check') THEN
        ALTER TABLE helpdesk.hd_status_events ADD CONSTRAINT hd_status_events_severity_check
            CHECK (severity IS NULL OR severity IN ('degraded', 'partial_outage', 'major_outage'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conrelid = 'helpdesk.hd_status_events'::regclass AND conname = 'hd_status_events_severity_kind_check') THEN
        ALTER TABLE helpdesk.hd_status_events ADD CONSTRAINT hd_status_events_severity_kind_check
            CHECK (severity IS NULL OR kind = 'incident');
    END IF;
END $$;

COMMIT;
