-- =====================================================================================
-- A warning that cannot be cleared is a warning nobody reads.
--
-- ctl_billing_coverage answers one question -- has every database we expect to hear
-- from reported THIS month -- and the console puts that answer above every billing
-- screen, where it is deliberately not dismissible. So it has to be right, and since
-- 2026-10-07 it has been wrong for the one database that holds every paying customer:
--
--     tier POOLED | current_period 2026-10-01 | last_period 2026-11-01
--     last_reported_at 2026-10-07 08:30 | current_period_missing TRUE
--
-- Reported eight minutes earlier, for October among twelve other months, and flagged
-- as silent anyway.
--
-- WHY. The view picked the scope's report with the HIGHEST PERIOD and then asked
-- whether that period was the current month. Those are the same question only while
-- nothing is ever billed ahead. itech paid for November during October, the reporter
-- learned to carry prepaid months (so the console could show the money it had taken),
-- and from the first run after that the pool's newest period was November -- which is
-- not October, so the pool "had not reported this month". Every billing screen then
-- told the operator to treat real figures as a floor.
--
-- THE FIX IS THE ORDER BY, not the test. The question is whether a report exists FOR
-- the current period, so the lateral now prefers that period's report and falls back
-- to the newest one when there is none. `period IS DISTINCT FROM current_period` then
-- means what it says.
--
-- It also fixes what the row DESCRIBES. fact_count, tenant_count and the totals come
-- from whichever report the lateral picked, so the reporting screen was showing a
-- prepaid November's figures under the heading of this month's coverage. A scope that
-- has genuinely gone quiet still shows its last report, period and all, which is the
-- one case where the newest row is the useful one.
--
-- CREATE OR REPLACE with the SAME columns in the same order -- see 20261004-07 for why
-- a drop is not available here: the GRANTs on this view are issued by files that run
-- earlier in filename order, and a dropped view would be re-granted out from under the
-- console.
-- =====================================================================================

CREATE OR REPLACE VIEW control_plane.ctl_billing_coverage AS
WITH scopes AS (
    SELECT DISTINCT ON (COALESCE(silo_key, ''))
           COALESCE(silo_key, '') AS scope_silo,
           silo_key, tier, host, db_name
      FROM control_plane.ctl_tenant_routes
     WHERE status = 'ACTIVE'
       AND tier <> 'SELF_MANAGED'
     ORDER BY COALESCE(silo_key, ''), length(host)
)
SELECT s.silo_key,
       s.tier,
       s.host,
       s.db_name,
       date_trunc('month', now())::date AS current_period,
       r.period                         AS last_period,
       r.observed_at                    AS last_reported_at,
       r.fact_count,
       r.tenant_count,
       r.currency,
       r.total_due,
       r.total_paid,
       r.id IS NULL                     AS never_reported,
       r.period IS DISTINCT FROM date_trunc('month', now())::date
                                        AS current_period_missing
  FROM scopes s
  LEFT JOIN LATERAL (
       SELECT b.id, b.period, b.observed_at, b.fact_count, b.tenant_count,
              b.currency, b.total_due, b.total_paid
         FROM control_plane.ctl_billing_reports b
        WHERE COALESCE(b.silo_key, '') = s.scope_silo
        -- THIS MONTH FIRST. A prepaid month is a real report for a real period
        -- and sorts above the current one by date, which is how a database that
        -- had just reported came to be listed as silent.
        ORDER BY (b.period = date_trunc('month', now())::date) DESC,
                 b.period DESC, b.observed_at DESC, b.id DESC
        LIMIT 1
  ) r ON true;

-- ------------------------------------------------------------------------------ checks
DO $$
DECLARE n integer;
BEGIN
    -- The bug itself, asked of whatever data this database happens to hold: no
    -- scope may be flagged as missing while a report for the current period
    -- exists for it. Trivially true on a database with no reports yet, and the
    -- alarm on one that has them.
    SELECT count(*) INTO n
      FROM control_plane.ctl_billing_coverage c
     WHERE c.current_period_missing
       AND EXISTS (
           SELECT 1 FROM control_plane.ctl_billing_reports b
            WHERE COALESCE(b.silo_key, '') = COALESCE(c.silo_key, '')
              AND b.period = date_trunc('month', now())::date);
    IF n > 0 THEN
        RAISE EXCEPTION
            '% scope(s) report this month and are still flagged as silent', n;
    END IF;

    -- And the other direction, which is the one that matters more: a scope with
    -- NO report for this month must still be flagged. Losing that would make the
    -- banner permanently green and hide a database that had gone quiet.
    SELECT count(*) INTO n
      FROM control_plane.ctl_billing_coverage c
     WHERE NOT c.current_period_missing
       AND NOT EXISTS (
           SELECT 1 FROM control_plane.ctl_billing_reports b
            WHERE COALESCE(b.silo_key, '') = COALESCE(c.silo_key, '')
              AND b.period = date_trunc('month', now())::date);
    IF n > 0 THEN
        RAISE EXCEPTION
            '% scope(s) have not reported this month and are not flagged', n;
    END IF;

    RAISE NOTICE 'coverage asks whether THIS month was reported';
END $$;
