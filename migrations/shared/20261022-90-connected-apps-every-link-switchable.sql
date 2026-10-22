-- Connected apps, phase 2: every link between apps becomes a switch, not only the five into
-- Accounting (20261022-65). docs/POSTINGS.md §10.
--
-- The links (Core Platform's catalogue, app_connections_catalogue.py), each enforced by the
-- app that RECEIVES, per business, failing closed (no row, or a row it cannot read, is OFF):
--
--   mystoreguard-invoicing  sync, two-way, OFF/ALWAYS   Invoicing: bringing MyStoreGuard invoices
--                                                       in, and taking payments on them; MyStoreGuard:
--                                                       its queue drainer (invoicing payment queue)
--   expenses-invoicing      sync, OFF/ONE_TIME/ALWAYS   Invoicing's billable lines (spent_on in range)
--   projects-invoicing      sync, OFF/ONE_TIME/ALWAYS   Invoicing's billable lines (work date in range)
--   expenses-zeloshr        sync, OFF/ONE_TIME/ALWAYS   platform/payrollextras (approved in range)
--   zeloshr-expenses        lookup, OFF/ALWAYS (on)     Expenses' approval route, departments, payee
--   mystoreguard-crm        lookup                      the CRM's sync sweep and product prices
--   loandrift-crm           lookup                      the CRM's sync sweep
--   zeloshr-projects        lookup                      Projects' planning, time and rules
--
-- This file holds:
--
--   * A ONE-TIME backfill per link, so nothing stops for a business already using it: where the
--     data shows a business used the link, it gets ALWAYS (changed_by = 'system'); everyone else
--     has no row, which is OFF. One marker per link and database
--     (cp_app_connection_backfills '<link>@20261022'), written only once the tables that hold the
--     evidence exist in this database -- a silo that has not got an app's schema yet runs that
--     link's backfill on the deploy that brings it. ON CONFLICT DO NOTHING: never overwrites a
--     choice an owner made, and never re-runs over one (a re-run every deploy would switch on
--     businesses that must start OFF -- see 20261022-65).
--
--   * Two functions MyStoreGuard's queue drainer needs to obey the switch without ever holding
--     money that is already taken: invoicing.msg_queue_facts (when each payment was queued and
--     whether a payment gateway took it) and invoicing.msg_queue_hold (keep it queued, untried,
--     with the reason, and try again in a minute).
--
-- Guards rather than assumptions about other modules: every other app's table is touched only
-- where it exists, through EXECUTE so this file parses on a database without it.
-- Idempotent; safe to re-run.

BEGIN;

-- 20261022-65 owns these; restated (IF NOT EXISTS) so this file stands on a database where that
-- one has not run yet in the same deploy order.
CREATE TABLE IF NOT EXISTS core_platform.cp_app_connection_backfills (
    key     text PRIMARY KEY,
    ran_at  timestamptz NOT NULL DEFAULT now(),
    rows    integer NOT NULL DEFAULT 0
);

-- ===================================================================== backfill (once per link)
DO $$
DECLARE
    l record;
    marker text;
    ready boolean;
    n integer;
    t text;
BEGIN
    IF to_regclass('core_platform.cp_app_connections') IS NULL THEN
        RAISE NOTICE 'connected apps phase 2: no cp_app_connections here (20261022-65 not run): nothing to backfill';
        RETURN;
    END IF;

    FOR l IN
        SELECT * FROM (VALUES
            -- link key, source, target, the tables the evidence needs, the evidence (tenant_id, bus_id)
            ('mystoreguard-invoicing', 'app-mystoreguard', 'app-invoicing',
             ARRAY['invoicing.inv_invoices', 'invoicing.inv_msg_payment_queue'],
             $q$SELECT tenant_id, bus_id FROM invoicing.inv_invoices
                 WHERE source_app = 'mystoreguard' AND coalesce(source_id, '') <> ''
                UNION
                SELECT tenant_id, bus_id FROM invoicing.inv_msg_payment_queue$q$),
            ('expenses-invoicing', 'app-expenses', 'app-invoicing',
             ARRAY['expenses.exp_expenses'],
             $q$SELECT tenant_id, bus_id FROM expenses.exp_expenses
                 WHERE invoice_id IS NOT NULL OR (billable AND billable_customer_id IS NOT NULL)$q$),
            ('projects-invoicing', 'app-projects', 'app-invoicing',
             ARRAY['projects.prj_projects', 'projects.prj_worklogs', 'projects.prj_expenses'],
             $q$SELECT p.tenant_id, p.bus_id FROM projects.prj_projects p
                 WHERE p.inv_customer_id IS NOT NULL
                    OR EXISTS (SELECT 1 FROM projects.prj_worklogs w WHERE w.project_id = p.id AND w.inv_invoice_id IS NOT NULL)
                    OR EXISTS (SELECT 1 FROM projects.prj_expenses e WHERE e.project_id = p.id AND e.inv_invoice_id IS NOT NULL)$q$),
            ('expenses-zeloshr', 'app-expenses', 'app-zeloshr',
             ARRAY['expenses.exp_claim_payouts'],
             $q$SELECT tenant_id, bus_id FROM expenses.exp_claim_payouts WHERE method = 'payroll'$q$),
            -- Expenses has read ZelosHR for every business subscribed to both: with no route set,
            -- a claim goes to the claimant's manager there. So a business with claims, an HR
            -- route step or a department budget on a live ZelosHR subscription was using it.
            ('zeloshr-expenses', 'app-zeloshr', 'app-expenses',
             ARRAY['expenses.exp_claims', 'expenses.exp_approval_steps', 'expenses.exp_budgets', 'core_platform.cp_business_app_tier'],
             $q$SELECT x.tenant_id, x.bus_id FROM (
                    SELECT tenant_id, bus_id FROM expenses.exp_claims
                    UNION SELECT tenant_id, bus_id FROM expenses.exp_approval_steps WHERE approver_kind IN ('manager', 'department_head')
                    UNION SELECT tenant_id, bus_id FROM expenses.exp_budgets WHERE scope = 'department') x
                 WHERE EXISTS (SELECT 1 FROM core_platform.cp_business_app_tier t
                                WHERE t.tenant_id = x.tenant_id AND t.business_id = x.bus_id AND t.app_id = 'app-zeloshr')$q$),
            ('mystoreguard-crm', 'app-mystoreguard', 'app-crm',
             ARRAY['crm.crm_sync_settings', 'crm.crm_contact_sources', 'crm.crm_products'],
             $q$SELECT tenant_id, bus_id FROM crm.crm_sync_settings WHERE source_app LIKE 'mystoreguard%' AND enabled
                UNION SELECT tenant_id, bus_id FROM crm.crm_contact_sources WHERE source_app = 'mystoreguard'
                UNION SELECT tenant_id, bus_id FROM crm.crm_products WHERE source = 'mystoreguard'$q$),
            ('loandrift-crm', 'app-loandrift', 'app-crm',
             ARRAY['crm.crm_sync_settings', 'crm.crm_contact_sources'],
             $q$SELECT tenant_id, bus_id FROM crm.crm_sync_settings WHERE source_app = 'loandrift' AND enabled
                UNION SELECT tenant_id, bus_id FROM crm.crm_contact_sources WHERE source_app = 'loandrift'$q$),
            -- Projects has shown ZelosHR's leave, holidays and attendance to every business with
            -- projects whose organisation is on ZelosHR.
            ('zeloshr-projects', 'app-zeloshr', 'app-projects',
             ARRAY['projects.prj_projects', 'core_platform.cp_business_app_tier', 'core_platform.cp_businesses'],
             $q$SELECT DISTINCT p.tenant_id, p.bus_id FROM projects.prj_projects p
                  JOIN core_platform.cp_businesses b ON b.id = p.bus_id AND b.tenant_id = p.tenant_id
                 WHERE EXISTS (SELECT 1 FROM core_platform.cp_business_app_tier t
                                 JOIN core_platform.cp_businesses ob ON ob.id = t.business_id AND ob.tenant_id = t.tenant_id
                                WHERE t.tenant_id = p.tenant_id AND ob.org_id = b.org_id AND t.app_id = 'app-zeloshr')$q$)
        ) AS v(link_key, source_app, target_app, needs, evidence)
    LOOP
        marker := l.link_key || '@20261022';
        IF EXISTS (SELECT 1 FROM core_platform.cp_app_connection_backfills WHERE key = marker) THEN
            CONTINUE;
        END IF;
        ready := true;
        FOREACH t IN ARRAY l.needs LOOP
            ready := ready AND to_regclass(t) IS NOT NULL;
        END LOOP;
        IF NOT ready THEN
            RAISE NOTICE 'connected apps phase 2: % waits: its tables are not in this database yet', l.link_key;
            CONTINUE;
        END IF;
        EXECUTE format(
            $f$INSERT INTO core_platform.cp_app_connections
                      (tenant_id, bus_id, link_key, source_app, target_app, mode, changed_by, changed_by_name)
               SELECT DISTINCT e.tenant_id, e.bus_id, %L, %L, %L, 'ALWAYS', 'system', 'Kept on when the link became a switch'
                 FROM (%s) e
                WHERE coalesce(e.tenant_id, '') <> '' AND coalesce(e.bus_id, '') <> ''
               ON CONFLICT (tenant_id, bus_id, link_key) DO NOTHING$f$,
            l.link_key, l.source_app, l.target_app, l.evidence);
        GET DIAGNOSTICS n = ROW_COUNT;
        INSERT INTO core_platform.cp_app_connection_backfills (key, rows) VALUES (marker, n);
        RAISE NOTICE 'connected apps phase 2: % kept on for % business(es) already using it', l.link_key, n;
    END LOOP;
END $$;

-- ===================================================================== MyStoreGuard's queue drainer
-- Every row in invoicing.inv_msg_payment_queue is money already taken in Invoicing. While the
-- link is off MyStoreGuard still posts what was queued before it went off and anything a payment
-- gateway took (the customer had started paying while it was on); only a payment recorded by
-- hand after the link went off -- which Invoicing refuses -- is held, never refused, and posts
-- when the link is on again.
DO $$
BEGIN
    IF to_regclass('invoicing.inv_msg_payment_queue') IS NULL OR to_regclass('invoicing.inv_payments') IS NULL THEN
        RAISE NOTICE 'connected apps phase 2: no invoicing payment queue here, no drainer functions';
        RETURN;
    END IF;
    EXECUTE $f$
        CREATE OR REPLACE FUNCTION invoicing.msg_queue_facts(p_ids text[])
        RETURNS TABLE (id text, queued_at timestamptz, by_gateway boolean)
        LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, invoicing AS $body$
            SELECT q.id, q.cdatetime, (p.gateway_reference IS NOT NULL AND p.gateway_reference <> '')
              FROM invoicing.inv_msg_payment_queue q
              JOIN invoicing.inv_payments p ON p.id = q.payment_id
             WHERE q.id = ANY (p_ids)
        $body$
    $f$;
    EXECUTE $f$
        CREATE OR REPLACE FUNCTION invoicing.msg_queue_hold(p_id text, p_reason text)
        RETURNS void
        LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, invoicing AS $body$
            UPDATE invoicing.inv_msg_payment_queue
               SET last_error = left(p_reason, 1000),
                   next_try_at = now() + interval '1 minute',
                   attempts = greatest(attempts - 1, 0)   -- a hold is not a failed try
             WHERE id = p_id AND posted_at IS NULL AND failed_at IS NULL AND cancelled_at IS NULL
        $body$
    $f$;
    REVOKE ALL ON FUNCTION invoicing.msg_queue_facts(text[]) FROM PUBLIC;
    REVOKE ALL ON FUNCTION invoicing.msg_queue_hold(text, text) FROM PUBLIC;
END $$;

DO $$
DECLARE r text;
BEGIN
    IF to_regprocedure('invoicing.msg_queue_hold(text,text)') IS NULL THEN
        RETURN;
    END IF;
    -- MyStoreGuard's logins, whatever the environment calls them (as 20261019-22 does).
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname ~ '^mystoreguard(_|$)' LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION invoicing.msg_queue_facts(text[]) TO %I', r);
        EXECUTE format('GRANT EXECUTE ON FUNCTION invoicing.msg_queue_hold(text, text) TO %I', r);
    END LOOP;
END $$;

-- ===================================================================== checks
DO $$
DECLARE bad text;
BEGIN
    -- A lookup is on or off; MyStoreGuard ⇄ Invoicing moves money both ways and has no range.
    SELECT string_agg(DISTINCT link_key, ', ') INTO bad
      FROM core_platform.cp_app_connections
     WHERE mode = 'ONE_TIME'
       AND link_key IN ('mystoreguard-invoicing', 'zeloshr-expenses', 'mystoreguard-crm', 'loandrift-crm', 'zeloshr-projects');
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'connected apps phase 2: ONE_TIME on a link that is only on or off: %', bad;
    END IF;
    -- The backfill writes exactly the catalogue's direction for each link.
    SELECT string_agg(DISTINCT link_key, ', ') INTO bad
      FROM core_platform.cp_app_connections c
      JOIN (VALUES ('mystoreguard-invoicing', 'app-mystoreguard', 'app-invoicing'),
                   ('expenses-invoicing', 'app-expenses', 'app-invoicing'),
                   ('projects-invoicing', 'app-projects', 'app-invoicing'),
                   ('expenses-zeloshr', 'app-expenses', 'app-zeloshr'),
                   ('zeloshr-expenses', 'app-zeloshr', 'app-expenses'),
                   ('mystoreguard-crm', 'app-mystoreguard', 'app-crm'),
                   ('loandrift-crm', 'app-loandrift', 'app-crm'),
                   ('zeloshr-projects', 'app-zeloshr', 'app-projects')) AS v(k, s, t) ON v.k = c.link_key
     WHERE c.source_app <> v.s OR c.target_app <> v.t;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'connected apps phase 2: link(s) stored with the wrong apps: %', bad;
    END IF;
    IF to_regclass('invoicing.inv_msg_payment_queue') IS NOT NULL
       AND (to_regprocedure('invoicing.msg_queue_facts(text[])') IS NULL OR to_regprocedure('invoicing.msg_queue_hold(text,text)') IS NULL) THEN
        RAISE EXCEPTION 'connected apps phase 2: the payment queue is here but its drainer functions are not';
    END IF;
END $$;

COMMIT;
