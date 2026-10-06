-- =====================================================================================
-- A billing fact need not name an app.
--
-- ctl_billing_facts.app_id was NOT NULL, from when every bill line was a subscription
-- charge and therefore belonged to an app. A PLATFORM_CHARGE does not: a client's
-- database, storage account or backups belong to the CLIENT, which is why
-- cp_billings_logs.app_id was made nullable in shared/20261004-11.
--
-- The ledger never caught up, so the reporter raised
--
--     null value in column "app_id" of relation "ctl_billing_facts"
--     violates not-null constraint
--
-- for every database holding a platform charge. And because that aborts the whole
-- report, it did not merely drop the charge fact -- it dropped EVERY fact for that
-- database, subscriptions included. On dev both silos vanished from the console's
-- billing screens entirely while the pooled database reported fine, which reads as
-- "the silos have no billing" rather than as a failure.
--
-- That is the exact failure the push design exists to prevent: the one database whose
-- figures nobody else can see, reporting nothing, with every total still adding up.
--
-- WHY NULL AND NOT A SENTINEL
-- '(platform)' or similar would make a figure that is not attributable to an app look
-- like one that is. It would appear in by-app breakdowns as an app nobody recognises,
-- and a join against cp_apps would find nothing -- the same trap as putting a charge on
-- an arbitrary branch's invoice. NULL says "not an app", which is true, and
-- count(DISTINCT app_id) then correctly reports a charges-only client as having no apps.
--
-- WHY THE LATEST-WINS VIEW STILL WORKS
-- ctl_billing_facts_current is DISTINCT ON (source_db, tenant_id, app_id, period,
-- line_type). DISTINCT ON treats NULLs as EQUAL -- unlike a unique index, where every
-- NULL is distinct -- so the charge facts for one tenant and period collapse to one row
-- exactly as the subscription ones do. The view needs no change, and this file
-- deliberately does not touch it.
-- =====================================================================================

ALTER TABLE control_plane.ctl_billing_facts
    ALTER COLUMN app_id DROP NOT NULL;

COMMENT ON COLUMN control_plane.ctl_billing_facts.app_id IS
    'The app these figures are for, or NULL when they are not for an app at all -- a '
    'PLATFORM_CHARGE is billed to the client, not to one of their apps. Readers must '
    'COALESCE it; count(DISTINCT app_id) excludes NULLs, which is the wanted answer.';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; probe text;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_billing_facts'
       AND column_name = 'app_id' AND is_nullable = 'YES';
    IF n <> 1 THEN
        RAISE EXCEPTION 'ctl_billing_facts.app_id is still NOT NULL, so a platform '
                        'charge aborts the whole report for its database';
    END IF;

    -- Proved by DOING it: a NOT NULL that has been dropped and an insert that
    -- succeeds without the column are different claims, and it is the insert the
    -- reporter performs.
    --
    -- A fact is FK'd to a report, so the probe needs one. That FK is the reason
    -- the first version of this check failed -- worth keeping in the file,
    -- because it is also the reason a partial report leaves no orphan facts.
    INSERT INTO control_plane.ctl_billing_reports
        (id, source_db, tier, period, fact_count, tenant_count, total_due,
         total_paid, reported_by, observed_at)
    VALUES ('billrep_probe_noapp', 'probe-db', 'POOLED', date '2026-01-01',
            2, 1, 3, 0, 'migration-probe', now());

    INSERT INTO control_plane.ctl_billing_facts
        (id, report_id, source_db, tier, tenant_id, period, line_type, currency,
         amount_due, amount_paid, line_count, paid_line_count, billable_units,
         observed_at)
    VALUES ('billfact_probe_noapp', 'billrep_probe_noapp', 'probe-db', 'POOLED',
            'tnt_probe_noapp', date '2026-01-01', 'PLATFORM_CHARGE', 'USD',
            1, 0, 1, 0, 0, now())
    RETURNING COALESCE(app_id, '(null)') INTO probe;
    IF probe <> '(null)' THEN
        RAISE EXCEPTION 'a fact with no app came back as %, not null', probe;
    END IF;

    -- ...and the latest-wins view still collapses them to one row per key, which is
    -- what DISTINCT ON over a NULL has to do for the ledger to mean anything.
    INSERT INTO control_plane.ctl_billing_facts
        (id, report_id, source_db, tier, tenant_id, period, line_type, currency,
         amount_due, amount_paid, line_count, paid_line_count, billable_units,
         observed_at)
    VALUES ('billfact_probe_noapp2', 'billrep_probe_noapp', 'probe-db', 'POOLED',
            'tnt_probe_noapp', date '2026-01-01', 'PLATFORM_CHARGE', 'USD',
            2, 0, 1, 0, 0, now() + interval '1 second');

    SELECT count(*) INTO n FROM control_plane.ctl_billing_facts_current
     WHERE tenant_id = 'tnt_probe_noapp';
    IF n <> 1 THEN
        RAISE EXCEPTION 'two no-app facts for one key gave % current rows, not 1 -- '
                        'the view is not collapsing NULL app_ids', n;
    END IF;

    SELECT amount_due::text INTO probe FROM control_plane.ctl_billing_facts_current
     WHERE tenant_id = 'tnt_probe_noapp';
    IF probe::numeric <> 2 THEN
        RAISE EXCEPTION 'the current no-app fact is % , not the later 2', probe;
    END IF;

    -- Facts first, then the report they hang off: the other order is refused by
    -- the same foreign key.
    DELETE FROM control_plane.ctl_billing_facts
     WHERE tenant_id = 'tnt_probe_noapp';
    DELETE FROM control_plane.ctl_billing_reports
     WHERE id = 'billrep_probe_noapp';

    SELECT count(*) INTO n FROM control_plane.ctl_billing_facts
     WHERE tenant_id = 'tnt_probe_noapp';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe fact(s) survived, and would be read as real revenue', n;
    END IF;
    SELECT count(*) INTO n FROM control_plane.ctl_billing_reports
     WHERE id = 'billrep_probe_noapp';
    IF n > 0 THEN
        RAISE EXCEPTION 'the probe report survived, and would be read as a real '
                        'database having reported';
    END IF;

    RAISE NOTICE 'a ledger fact need not name an app';
END $$;
