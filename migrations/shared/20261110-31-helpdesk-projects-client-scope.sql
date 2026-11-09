-- Help Desk <-> Projects: Projects applies Help Desk's MSP client scoping (Help Desk R4 §4).
--
-- A Help Desk user listed in helpdesk.hd_client_agents for some client accounts of a business sees
-- only those clients' tickets, problems and changes (and no internal ones). Until now Projects
-- showed every linked ticket's subject, customer and impact to anyone with Help Desk ticket access,
-- so a person scoped to client A could read client B's tickets through a work item.
--
-- Projects already reads client_account_id on projects.src_helpdesk_links and
-- projects.src_helpdesk_tickets (20261109-31, restated by 20261109-73, which owns them). This file
-- adds the one thing it lacks: who is scoped to which client, as a view, so Projects applies the
-- same rule Help Desk does (tvs-shared-apps-bk platform/hdprojects.ClientScope, one function for
-- both). Out-of-scope tickets show in Projects only as a count ("n tickets hidden").
--
-- The two ticket views are NOT restated here (20261109-73 stays their owner); this file checks
-- that they still leave confidential HR cases out.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

DO $$
BEGIN
    IF to_regclass('helpdesk.hd_client_agents') IS NULL OR to_regclass('projects.prj_tasks') IS NULL THEN
        RAISE NOTICE 'helpdesk-projects client scope: Help Desk (with MSP) and Projects are not both here: no view';
        RETURN;
    END IF;
    -- Who is client-scoped, to which clients. Ids only: no client names, no people's details.
    EXECUTE $v$
    CREATE OR REPLACE VIEW projects.src_helpdesk_client_agents AS
    SELECT a.tenant_id, a.bus_id, a.user_id, a.client_account_id
      FROM helpdesk.hd_client_agents a
    $v$;
END $$;

-- ===================================================================== checks (invariants, not counts)
DO $$
DECLARE v text;
BEGIN
    -- Projects never reads a confidential HR case (20261109-73): both views filter on it, and no
    -- confidential ticket comes through either.
    IF to_regclass('projects.src_helpdesk_tickets') IS NOT NULL
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'helpdesk' AND table_name = 'hd_tickets'
                    AND column_name = 'confidentiality') THEN
        FOREACH v IN ARRAY ARRAY['projects.src_helpdesk_tickets', 'projects.src_helpdesk_links'] LOOP
            IF position('confidentiality' IN pg_get_viewdef(v::regclass)) = 0 THEN
                RAISE EXCEPTION 'helpdesk-projects client scope: % no longer leaves confidential HR cases out', v;
            END IF;
        END LOOP;
        IF EXISTS (SELECT 1 FROM projects.src_helpdesk_tickets x JOIN helpdesk.hd_tickets k ON k.id = x.ticket_id
                    WHERE k.confidentiality <> 'none') THEN
            RAISE EXCEPTION 'helpdesk-projects client scope: a confidential HR case is readable through projects.src_helpdesk_tickets';
        END IF;
        IF EXISTS (SELECT 1 FROM projects.src_helpdesk_links x JOIN helpdesk.hd_tickets k ON k.id = x.record_id
                    WHERE x.record_type = 'ticket' AND k.confidentiality <> 'none') THEN
            RAISE EXCEPTION 'helpdesk-projects client scope: a confidential HR case is readable through projects.src_helpdesk_links';
        END IF;
    END IF;
    -- The client columns the scoping reads are on both views.
    IF to_regclass('projects.src_helpdesk_client_agents') IS NOT NULL THEN
        FOREACH v IN ARRAY ARRAY['src_helpdesk_tickets', 'src_helpdesk_links'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'projects' AND table_name = v
                            AND column_name = 'client_account_id') THEN
                RAISE EXCEPTION 'helpdesk-projects client scope: projects.% has no client_account_id to scope by', v;
            END IF;
        END LOOP;
    END IF;
END $$;

COMMIT;
