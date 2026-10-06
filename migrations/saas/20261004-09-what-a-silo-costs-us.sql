-- =====================================================================================
-- What a silo costs us to run.
--
-- WHY THIS EXISTS, AND WHY IT IS TYPED IN BY HAND
-- 20261004-03 deliberately carried no cost column, with this reasoning: "a cost figure
-- is only worth having if it is real, and deriving one needs per-silo server, storage
-- and backup metering that does not exist. A made-up cost would make every margin on
-- the dashboard confidently wrong."
--
-- That was right about DERIVED costs and wrong about the consequence. The consequence
-- was that nobody could answer "does this silo client make money", which is the question
-- underneath every pricing decision for a silo client -- and a dedicated silo has a
-- FIXED monthly floor (its own database, often its own server, its own storage account,
-- its backups) that a per-location price cannot recover if the client drops to one
-- location.
--
-- So: a figure somebody TYPES IN when a silo is provisioned. It is not metering and does
-- not pretend to be. It is what we agreed to pay for that infrastructure, which is a
-- number a human knows and no query can discover. A typed figure that is roughly right
-- beats a derived figure that is precisely wrong, and beats nothing at all by more.
--
-- WHY A TABLE AND NOT A COLUMN ON THE ROUTE
-- ctl_tenant_routes is one row per HOST and a silo may answer at several, so a cost
-- there would be duplicated per host and "what does itech cost" would become a question
-- about which copy to believe. And cost CHANGES -- a server is resized, a backup policy
-- changes -- so it wants history, which a column cannot hold.
--
-- Append-only with a latest-wins view, exactly like the billing ledger it sits beside,
-- so "what did this cost in June" stays answerable after somebody resizes the server.
--
-- NOTE ON SCOPE: the pooled database is deliberately absent. Its cost is shared by every
-- pooled tenant and dividing it per tenant needs an allocation rule nobody has agreed;
-- a wrong rule applied to the many is worse than no figure for them. Self-managed is
-- absent because it costs us no infrastructure at all.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS control_plane.ctl_silo_costs (
    id            text        NOT NULL
                  DEFAULT ('silocost_' || replace(gen_random_uuid()::text, '-', '')),

    -- The silo, as ctl_tenant_routes.silo_key names it. No foreign key: a cost may be
    -- recorded before the route exists (the infrastructure is built first) and must
    -- survive the route being retired, or the history disappears exactly when somebody
    -- asks what the silo used to cost.
    silo_key      text        NOT NULL,

    -- What we pay per month for this silo's infrastructure, in the currency we pay it
    -- in. USD by default, like everything else the platform prices in -- but a bill from
    -- a regional provider may not be, and converting it here would bury the fact.
    monthly_cost  numeric(18,2) NOT NULL,
    currency      text        NOT NULL DEFAULT 'USD',

    -- What the figure covers, in the words of whoever entered it: "B2s server + 32GB
    -- storage + weekly backups". Without this, a number nobody can account for is a
    -- number nobody dares correct.
    covers        text,

    -- From when this figure applies. A resize in the middle of a month leaves two rows,
    -- and a question about June reads the one in force then.
    effective_from date       NOT NULL DEFAULT CURRENT_DATE,

    recorded_by   text,
    observed_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_ctl_silo_costs PRIMARY KEY (id),
    -- Zero is allowed: a silo running on capacity already paid for genuinely costs no
    -- more, and saying so is different from not knowing. Below zero is never meaningful.
    CONSTRAINT ck_ctl_silo_costs_sane CHECK (monthly_cost >= 0),
    CONSTRAINT ck_ctl_silo_costs_currency CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX IF NOT EXISTS ix_ctl_silo_costs_latest
    ON control_plane.ctl_silo_costs (silo_key, effective_from DESC, observed_at DESC);

COMMENT ON TABLE control_plane.ctl_silo_costs IS
    'What each silo costs us per month, typed in when it is provisioned and whenever it '
    'changes. Not metering -- an agreed infrastructure cost, which is a number a human '
    'knows and no query can discover. Append-only; read ctl_silo_costs_current.';

-- The figure in force now, per silo.
CREATE OR REPLACE VIEW control_plane.ctl_silo_costs_current AS
SELECT DISTINCT ON (silo_key)
       id, silo_key, monthly_cost, currency, covers, effective_from,
       recorded_by, observed_at
  FROM control_plane.ctl_silo_costs
 WHERE effective_from <= CURRENT_DATE
 ORDER BY silo_key, effective_from DESC, observed_at DESC, id DESC;

COMMENT ON VIEW control_plane.ctl_silo_costs_current IS
    'The cost in force today per silo. A future-dated row is excluded until its date '
    'arrives, so a planned resize can be entered in advance without changing today''s '
    'margin.';

-- Revenue beside cost, per silo, which is the whole point.
--
-- The revenue side comes from ctl_billing_customers_current, so it is USD and it is the
-- MRR run rate -- not a month's bill, which would make a client who joined on the 28th
-- look unprofitable. Cost is converted only when the currencies match; where they do
-- not, margin is NULL rather than a figure computed across two currencies.
-- STANDS ASIDE ONCE 20261004-12 HAS REDEFINED THIS VIEW.
--
-- 20261004-12 DROPs ctl_silo_margin and recreates it with a different shape --
-- itemised lines, monthly_charge, the unbilled counts -- and re-grants, as its
-- own comment explains. Every migration re-runs on every deploy, so this file
-- then replaced that with ITS column list and got
--
--     42P16: cannot drop columns from view
--
-- which stopped the deploy before 20261004-12 was reached. The dev pipeline had
-- been failing on this since 2026-10-04.
--
-- GUARDED ON monthly_charge, a column 20261004-12 adds and this definition does
-- not have. Not on the view existing: on a FRESH database this file must create
-- it so 20261004-12 has something to drop, and an existence check would leave a
-- new database on this shape for ever.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'control_plane'
                  AND table_name = 'ctl_silo_margin'
                  AND column_name = 'monthly_charge') THEN
        RAISE NOTICE 'ctl_silo_margin already carries monthly_charge; '
                     '20261004-12 owns its shape';
        RETURN;
    END IF;
    EXECUTE $view$
CREATE OR REPLACE VIEW control_plane.ctl_silo_margin AS
SELECT c.silo_key,
       c.monthly_cost,
       c.currency                                        AS cost_currency,
       c.covers,
       c.effective_from,
       COALESCE(r.tenants, 0)                            AS tenants,
       COALESCE(r.mrr, 0)                                AS mrr,
       r.currency                                        AS mrr_currency,
       CASE WHEN r.currency = c.currency
            THEN COALESCE(r.mrr, 0) - c.monthly_cost END AS margin,
       CASE WHEN r.currency = c.currency AND COALESCE(r.mrr, 0) > 0
            THEN round(((COALESCE(r.mrr, 0) - c.monthly_cost)
                        / r.mrr) * 100, 1) END           AS margin_pct
  FROM control_plane.ctl_silo_costs_current c
  LEFT JOIN (
        SELECT silo_key,
               count(*)::bigint        AS tenants,
               sum(mrr)::numeric       AS mrr,
               -- One currency per silo in practice; NULL if they disagree, which
               -- makes the margin NULL above rather than wrong.
               CASE WHEN count(DISTINCT currency) = 1 THEN max(currency) END AS currency
          FROM control_plane.ctl_billing_customers_current
         WHERE silo_key IS NOT NULL
         GROUP BY silo_key
  ) r ON r.silo_key = c.silo_key;
$view$;
END $$;

COMMENT ON VIEW control_plane.ctl_silo_margin IS
    'Revenue beside cost per silo. margin is NULL where the cost currency and the '
    'revenue currency differ -- a figure subtracted across two currencies is worse '
    'than a blank.';

-- ----------------------------------------------------------------- revoke first
-- control_plane grants SELECT on new tables to every application group by default.
-- Correct for a route table, wrong for this: what our infrastructure costs is nobody
-- else's business, least of all a tenant-facing app's.
DO $$
DECLARE grp text;
BEGIN
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('REVOKE ALL ON control_plane.ctl_silo_costs FROM %I', grp);
        EXECUTE format('REVOKE ALL ON control_plane.ctl_silo_costs_current FROM %I', grp);
        EXECUTE format('REVOKE ALL ON control_plane.ctl_silo_margin FROM %I', grp);
    END LOOP;
END $$;

-- The console reads and WRITES this -- the figure is typed into it -- which makes it the
-- one control_plane table it needs more than SELECT on.
--
-- Granted to the same login pattern as the billing ledger in 20261004-01, and for the
-- same reason: on dev the console connects as `coreplatform_dev`, the very login the
-- Core Platform app uses. There is no `deladetech_*` login -- the first version of this
-- file looked for one, matched nothing, and granted the console no access at all while
-- reporting success through a WARNING nobody would read.
--
-- So "only the console" is a statement of intent, not of enforcement: anything holding
-- that login can read this. The separation that IS enforced is the one that matters --
-- the per-app GROUPS (tvs_app_*) are revoked above, which is how a tenant-facing app
-- reaches the database, and no app has UPDATE or DELETE here at all.
--
-- The underscore matters in the pattern: [a-z0-9]+ excludes it, so `coreplatform_dev`
-- matches and the per-silo logins `coreplatform_itech_dev` and `coreplatform_shared_dev`
-- do not. A silo's login has no business reading what every other silo costs.
DO $$
DECLARE r text; n integer := 0;
BEGIN
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format(
            'GRANT SELECT, INSERT ON control_plane.ctl_silo_costs TO %I', r);
        EXECUTE format(
            'GRANT SELECT ON control_plane.ctl_silo_costs_current TO %I', r);
        EXECUTE format('GRANT SELECT ON control_plane.ctl_silo_margin TO %I', r);
        n := n + 1;
    END LOOP;
    IF n = 0 THEN
        -- A WARNING here was the bug: the console had no access, the migration
        -- reported success, and the screen failed with "permission denied" long
        -- after anybody would connect the two. A database with a console login
        -- must end up granting it.
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolcanlogin
                    AND rolname ~ '^(coreplatform|deladetech)_') THEN
            RAISE EXCEPTION 'console logins exist but none matched the grant '
                            'pattern, so nothing can read the silo costs';
        END IF;
        RAISE NOTICE 'silo costs: no console login in this database yet';
    END IF;
END $$;

-- No UPDATE and no DELETE, for anybody. The table is append-only so a cost change
-- leaves the old figure in place; without that, "what did June cost" stops being
-- answerable the first time a server is resized.

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('control_plane.ctl_silo_costs') IS NULL THEN
        RAISE EXCEPTION 'ctl_silo_costs was not created';
    END IF;

    SELECT count(*) INTO n FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_silo_costs', 'ctl_silo_costs_current', 'ctl_silo_margin')
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can see what our infrastructure costs';
    END IF;

    -- No UPDATE or DELETE for anybody we GRANT to. The owner is excluded because a
    -- table's owner holds every privilege inherently and cannot be revoked of them --
    -- the first version of this check did not exclude it and failed on its own
    -- migration, which is the right way round for a check to be wrong.
    SELECT count(*) INTO n FROM information_schema.role_table_grants g
     WHERE g.table_schema = 'control_plane' AND g.table_name = 'ctl_silo_costs'
       AND g.privilege_type IN ('UPDATE', 'DELETE', 'TRUNCATE')
       AND g.grantee <> (
           SELECT pg_get_userbyid(relowner) FROM pg_class
            WHERE oid = 'control_plane.ctl_silo_costs'::regclass
       );
    IF n > 0 THEN
        RAISE EXCEPTION 'the cost history can be rewritten by %, so it is not history',
            (SELECT string_agg(DISTINCT grantee, ', ')
               FROM information_schema.role_table_grants
              WHERE table_schema = 'control_plane' AND table_name = 'ctl_silo_costs'
                AND privilege_type IN ('UPDATE', 'DELETE', 'TRUNCATE'));
    END IF;

    -- A negative cost must be impossible; zero must be allowed.
    BEGIN
        INSERT INTO control_plane.ctl_silo_costs (silo_key, monthly_cost)
        VALUES ('probe', -1);
        RAISE EXCEPTION 'a negative monthly cost was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- The margin view must resolve even with no rows on either side.
    PERFORM count(*) FROM control_plane.ctl_silo_margin;

    SELECT count(*) INTO n FROM control_plane.ctl_silo_costs WHERE silo_key = 'probe';
    IF n > 0 THEN
        RAISE EXCEPTION 'the probe row survived';
    END IF;

    RAISE NOTICE 'what a silo costs is recordable';
END $$;
