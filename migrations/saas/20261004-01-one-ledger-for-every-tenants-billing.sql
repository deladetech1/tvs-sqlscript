-- =====================================================================================
-- One place where every tenant's billing can be seen, whichever database they live in.
--
-- WHY THIS IS NEEDED
-- core_platform.cp_billings_logs is the money ledger -- a line per (organization,
-- business, location, app, month, line_type) with its price, rate and paid state. It is
-- a tenant-scoped table in core_platform, so a copy of it exists in EVERY database, and
-- the Functions timers already fan out per database: a silo tenant's bills are generated
-- and charged correctly, inside the silo's own database.
--
-- What did not exist is anywhere for US to see them. The pooled database's copy is
-- readable from the console; a silo's is not, because that is what a silo IS. So the
-- owners of the platform could see revenue for pooled clients and were blind to every
-- silo -- and a silo that silently stopped billing looked exactly like a silo with
-- nothing to bill.
--
-- WHY PUSH AND NOT PULL
-- The obvious fix is to let the console hold a credential for every tenant database and
-- read their billing tables. That would give one process read access to every customer's
-- data, which is precisely what a silo exists to prevent: the value of the architecture
-- is that no single credential reaches two customers. Gathering a number is not worth
-- re-centralising what the silos decentralised, and it cannot work at all for a customer
-- who supplies their own database and may revoke us.
--
-- So each database reports its own billing OUTWARD into these tables. Route resolution
-- happens before a tenant is known, so every app and Functions process already holds a
-- connection to the pooled database -- the report needs no new credential, no new network
-- path, and no inbound access to anybody's data. The reporting role may INSERT here and
-- do nothing else.
--
-- WHY THIS MIGRATION IS IN saas/ AND NOT shared/
-- Because shared/ is applied to every database, including each silo. A control_plane
-- table created there would exist N times, and a silo would happily write its facts into
-- its own local copy -- where nobody would ever look. The ledger must exist in exactly
-- one database: the pooled one, which is where the control plane that routes everything
-- already lives. saas/ is the tree that means "the pooled database", so that is where
-- this belongs, even though the schema it touches is control_plane.
--
-- A consequence worth stating: the ledger is per CELL, because each cell's pooled
-- database is its own control plane. An environment's console reads its own cell's
-- ledger. A separate cell (bgclt) keeps its own, which is correct -- it is a separate
-- installation, not a client of this one.
--
-- WHAT DELIBERATELY DOES NOT CROSS
-- cp_billings_logs carries organization_name, business_name and location_name. Those are
-- the customer's own business data and they stay in the customer's database. Only ids,
-- counts and money come out. We already hold the client's identity in
-- deladetech.dlt_client_setups, so the console joins OUR record of who they are to THEIR
-- report of what they owe, on tenant_id. That split is the thing that stops this ledger
-- becoming a back door into tenant data: a reader of every row still learns no names.
--
-- Provider references are not carried either. A Paystack reference would make
-- per-transaction reconciliation possible from here, but totals and counts are enough to
-- see that a figure is wrong, and the narrower surface is worth more than the
-- convenience. Reconciling a specific transaction is done in the system that holds it.
-- =====================================================================================

CREATE SCHEMA IF NOT EXISTS control_plane;

-- -------------------------------------------------------------------------------------
-- THE HEARTBEAT
--
-- One row each time a database reports, even when it has nothing to bill. This is the
-- table that makes silence legible: without it, a silo that stopped reporting is
-- indistinguishable from a silo that owes nothing, which is how three months of revenue
-- goes missing and is noticed at year end.
--
-- It is also an integrity check on the facts it carries. The report states its own
-- totals; the facts attached to it must add up to them. If they disagree, something was
-- lost in transit and the figure is not to be trusted -- better to know that than to
-- show a plausible wrong number.
-- -------------------------------------------------------------------------------------
-- The id is a value the WRITER chooses, not an identity column, and that is forced by
-- the append-only grant: PostgreSQL requires SELECT privilege for INSERT ... RETURNING,
-- so a role holding INSERT alone cannot ask the database what id it was given. A
-- reporter that must attach facts to its report has to know the id before it writes.
-- Text ids with a prefix are also what every other table here uses.
CREATE TABLE IF NOT EXISTS control_plane.ctl_billing_reports (
    id            text        NOT NULL
                  DEFAULT ('billrep_' || replace(gen_random_uuid()::text, '-', '')),

    -- WHICH database spoke. source_db is its current_database(); silo_key names the
    -- silo, and is NULL for the pooled database -- the same "NULL means the pool"
    -- convention the route table already uses for tenant_id.
    source_db     text        NOT NULL,
    host          text,
    tier          text        NOT NULL,
    silo_key      text,

    -- The billing month, as a real date (the first of it) so it sorts and ranges.
    -- cp_billings_logs stores a display string like 'Oct 2026'; period_label keeps that
    -- verbatim so a figure here can be traced back to the rows that produced it.
    period        date        NOT NULL,
    period_label  text,

    fact_count    integer     NOT NULL DEFAULT 0,
    tenant_count  integer     NOT NULL DEFAULT 0,
    currency      text,
    total_due     numeric(18,2) NOT NULL DEFAULT 0,
    total_paid    numeric(18,2) NOT NULL DEFAULT 0,

    reported_by   text        NOT NULL,
    observed_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_ctl_billing_reports PRIMARY KEY (id),
    CONSTRAINT ck_ctl_billing_reports_sane CHECK (
        fact_count >= 0 AND tenant_count >= 0
        AND total_due >= 0 AND total_paid >= 0
    )
);

-- -------------------------------------------------------------------------------------
-- THE FACTS
--
-- A SNAPSHOT, not a delta. Each report states the whole picture for its period, so a
-- correction is simply a later report and nothing ever has to be edited. That is what
-- lets both tables be append-only, which is what makes them worth believing: an audit
-- trail the application can rewrite is not an audit trail.
--
-- Readers take the latest row per (source_db, tenant_id, app_id, period, line_type).
-- The view below does it so that nobody has to remember.
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS control_plane.ctl_billing_facts (
    id              text        NOT NULL
                    DEFAULT ('billfact_' || replace(gen_random_uuid()::text, '-', '')),

    -- A fact cannot exist without the report that carried it. The foreign key is the
    -- point: money may not be pushed here without a heartbeat to account for it, and
    -- PostgreSQL enforces it without the writer needing to read the parent table.
    report_id       text        NOT NULL,

    source_db       text        NOT NULL,
    host            text,
    tier            text        NOT NULL,
    silo_key        text,

    -- Ids and counts only. See the header for what is deliberately absent.
    tenant_id       text        NOT NULL,
    app_id          text        NOT NULL,
    period          date        NOT NULL,
    period_label    text,
    line_type       text        NOT NULL,

    currency        text        NOT NULL,
    amount_due      numeric(18,2) NOT NULL DEFAULT 0,
    amount_paid     numeric(18,2) NOT NULL DEFAULT 0,

    line_count      integer     NOT NULL DEFAULT 0,
    paid_line_count integer     NOT NULL DEFAULT 0,
    -- There is deliberately no "paid at" here. cp_billings_logs records paid_date as
    -- free text ('Monday 25th May, 2026') and has no update timestamp, so the only
    -- timestamp available is the row's creation -- which is when the bill was RAISED,
    -- not when it was paid. A column named for a payment time and filled with a
    -- billing time is worse than no column: the counts and amounts below are true.
    --
    -- How many locations this charge covered. The unit a bill is actually sized by, and
    -- the number to watch when an amount changes: units up means growth, units flat with
    -- amount up means a price change somebody should be able to explain.
    billable_units  integer     NOT NULL DEFAULT 0,

    observed_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_ctl_billing_facts PRIMARY KEY (id),
    CONSTRAINT fk_ctl_billing_facts_report FOREIGN KEY (report_id)
        REFERENCES control_plane.ctl_billing_reports (id),
    CONSTRAINT ck_ctl_billing_facts_sane CHECK (
        amount_due >= 0 AND amount_paid >= 0
        AND line_count >= 0 AND paid_line_count >= 0 AND billable_units >= 0
        AND paid_line_count <= line_count
    )
);

CREATE INDEX IF NOT EXISTS ix_ctl_billing_facts_latest
    ON control_plane.ctl_billing_facts
       (source_db, tenant_id, app_id, period, line_type, observed_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS ix_ctl_billing_facts_period
    ON control_plane.ctl_billing_facts (period DESC, tier);
CREATE INDEX IF NOT EXISTS ix_ctl_billing_facts_tenant
    ON control_plane.ctl_billing_facts (tenant_id, period DESC);
CREATE INDEX IF NOT EXISTS ix_ctl_billing_reports_scope
    ON control_plane.ctl_billing_reports
       (source_db, period DESC, observed_at DESC, id DESC);

COMMENT ON TABLE control_plane.ctl_billing_reports IS
    'One row each time a database reports its billing outward, including when it has '
    'nothing to bill. Append-only. A missing row is the signal.';
COMMENT ON TABLE control_plane.ctl_billing_facts IS
    'Billing totals reported by each database. Ids, counts and money only -- never a '
    'customer''s organization, business or location names. Append-only snapshots; '
    'readers take the latest per (source_db, tenant_id, app_id, period, line_type).';

-- -------------------------------------------------------------------------------------
-- The latest snapshot per key, so no reader has to know how revisions work.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW control_plane.ctl_billing_facts_current AS
SELECT DISTINCT ON (source_db, tenant_id, app_id, period, line_type)
       id, report_id, source_db, host, tier, silo_key,
       tenant_id, app_id, period, period_label, line_type,
       currency, amount_due, amount_paid,
       line_count, paid_line_count, billable_units, observed_at
  FROM control_plane.ctl_billing_facts
 ORDER BY source_db, tenant_id, app_id, period, line_type, observed_at DESC, id DESC;

COMMENT ON VIEW control_plane.ctl_billing_facts_current IS
    'The current figure for each billing key: the most recent snapshot reported.';

-- -------------------------------------------------------------------------------------
-- COVERAGE -- the view that makes a pushed number verifiable rather than trusted.
--
-- Every database we expect to hear from, beside what it last said. A scope that has
-- never reported, or has not reported for the current month, is the thing to act on;
-- a revenue figure on its own cannot show you that, because the missing silo
-- contributes nothing and nothing looks like zero.
--
-- SELF_MANAGED is excluded. We do not run their timers, so expecting a report from them
-- would leave a permanent warning that means nothing. Their billing is settled by the
-- agreement that put them on their own infrastructure.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW control_plane.ctl_billing_coverage AS
WITH scopes AS (
    -- One row per DATABASE, which is the unit a report comes from -- not per host, since
    -- several hosts resolve to the pooled database. NULL silo_key is the pool.
    SELECT DISTINCT ON (COALESCE(silo_key, ''))
           COALESCE(silo_key, '')             AS scope_silo,
           silo_key,
           tier,
           host,
           db_name
      FROM control_plane.ctl_tenant_routes
     WHERE status = 'ACTIVE'
       AND tier <> 'SELF_MANAGED'
     ORDER BY COALESCE(silo_key, ''), length(host)
)
SELECT s.silo_key,
       s.tier,
       s.host,
       s.db_name,
       date_trunc('month', now())::date       AS current_period,
       r.period                               AS last_period,
       r.observed_at                           AS last_reported_at,
       r.fact_count,
       r.tenant_count,
       r.currency,
       r.total_due,
       r.total_paid,
       (r.id IS NULL)                          AS never_reported,
       (r.period IS DISTINCT FROM date_trunc('month', now())::date)
                                               AS current_period_missing
  FROM scopes s
  LEFT JOIN LATERAL (
       SELECT b.id, b.period, b.observed_at, b.fact_count, b.tenant_count,
              b.currency, b.total_due, b.total_paid
         FROM control_plane.ctl_billing_reports b
        WHERE COALESCE(b.silo_key, '') = s.scope_silo
        ORDER BY b.period DESC, b.observed_at DESC, b.id DESC
        LIMIT 1
  ) r ON true;

COMMENT ON VIEW control_plane.ctl_billing_coverage IS
    'Every database expected to report, beside what it last reported. never_reported or '
    'current_period_missing is the alert; a revenue total cannot show a silent silo.';

-- ------------------------------------------------------------------------------ grants
--
-- APPEND for the reporters, READ for a named group, and DELETE for nobody.
--
-- INSERT goes to the app groups because the reporter is an application process and the
-- grant model here is group-based. Append-only is what makes that safe: a role that may
-- only INSERT cannot read another customer's figures, so giving every app the right to
-- report costs nothing.
--
-- SELECT does NOT go to the app groups. Reading this table means reading every
-- customer's revenue across every database, which is a strictly wider thing than any
-- application has ever been able to do. It goes to tvs_billing_reader, which exists so
-- that the right to see all of it is held by name and can be moved in one statement --
-- today to the credential the console borrows, and to the console's own login the moment
-- it has one.
DO $$
DECLARE grp text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tvs_billing_reader') THEN
        CREATE ROLE tvs_billing_reader NOLOGIN;
        RAISE NOTICE 'created role tvs_billing_reader';
    END IF;

    GRANT USAGE ON SCHEMA control_plane TO tvs_billing_reader;
    GRANT SELECT ON control_plane.ctl_billing_reports        TO tvs_billing_reader;
    GRANT SELECT ON control_plane.ctl_billing_facts          TO tvs_billing_reader;
    GRANT SELECT ON control_plane.ctl_billing_facts_current  TO tvs_billing_reader;
    GRANT SELECT ON control_plane.ctl_billing_coverage       TO tvs_billing_reader;
    -- The coverage view reads the route table, and the view's owner supplies that
    -- access, so a reader needs nothing on ctl_tenant_routes itself.

    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA control_plane TO %I', grp);
        EXECUTE format(
            'GRANT INSERT ON control_plane.ctl_billing_reports TO %I', grp);
        EXECUTE format(
            'GRANT INSERT ON control_plane.ctl_billing_facts TO %I', grp);
        RAISE NOTICE 'billing ledger: INSERT granted to %', grp;
    END LOOP;
END $$;

-- Who may read it. Discovered rather than hardcoded, because the console borrows
-- core-platform's login today and will have deladetech's tomorrow; both are matched, so
-- the switch needs no migration.
DO $$
DECLARE r text; n integer := 0;
BEGIN
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin
           AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format('GRANT tvs_billing_reader TO %I', r);
        RAISE NOTICE 'billing ledger: % may now read it', r;
        n := n + 1;
    END LOOP;

    IF n = 0 THEN
        -- Not an exception: the ledger is still correct and still being written, and a
        -- migration that refuses to finish over a missing grant would block a deploy
        -- over a reporting feature. Loud, and actionable.
        RAISE WARNING 'billing ledger: no console login matched, so NOTHING can read '
                      'it yet. Grant it by name: GRANT tvs_billing_reader TO <login>;';
    END IF;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; rid text := 'billrep_probe';
BEGIN
    IF to_regclass('control_plane.ctl_billing_reports') IS NULL
       OR to_regclass('control_plane.ctl_billing_facts') IS NULL THEN
        RAISE EXCEPTION 'the billing ledger was not created';
    END IF;

    -- Financial records are kept for years. The retention sweep purges any schema listed
    -- in cp_app_schemas, so control_plane must not be in it -- the same hazard that
    -- would have eaten the record of every client deletion.
    SELECT count(*) INTO n FROM core_platform.cp_app_schemas
     WHERE schema_name = 'control_plane';
    IF n > 0 THEN
        RAISE EXCEPTION 'control_plane is in cp_app_schemas; the retention job would '
                        'purge the billing ledger';
    END IF;

    -- Nothing may erase it. The whole value of the ledger rests on this.
    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_reports', 'ctl_billing_facts')
       AND privilege_type IN ('DELETE', 'UPDATE', 'TRUNCATE')
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application role can modify or erase the billing ledger';
    END IF;

    -- ...and no application group may READ it, which is the grant that would quietly
    -- hand every app every customer's revenue. Column grants are checked too: a
    -- SELECT on one column does not appear in role_table_grants, so a tempting
    -- `GRANT SELECT (id)` -- which is exactly what someone reaching for
    -- INSERT ... RETURNING would add -- would slip past a table-level check.
    SELECT count(*) INTO n
      FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_reports', 'ctl_billing_facts')
       AND privilege_type = 'SELECT'
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can read the whole billing ledger';
    END IF;

    SELECT count(*) INTO n
      FROM information_schema.role_column_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_billing_reports', 'ctl_billing_facts')
       AND privilege_type = 'SELECT'
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can read % column(s) of the billing '
                        'ledger', n;
    END IF;

    -- The reporters must still be able to append, or every silo goes quiet and the
    -- coverage view lights up for a reason that is our fault. Asserted per group,
    -- because this is the half of the grant that is easy to lose while tightening
    -- the other half.
    FOR n IN
        SELECT 1 FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
           AND NOT (
             has_table_privilege(rolname, 'control_plane.ctl_billing_reports', 'INSERT')
             AND has_table_privilege(rolname, 'control_plane.ctl_billing_facts', 'INSERT')
           )
    LOOP
        RAISE EXCEPTION 'an application group cannot append to the billing ledger';
    END LOOP;

    -- A fact without a report must be impossible, or money could be pushed here with
    -- nothing accounting for it. Proven, not assumed.
    BEGIN
        INSERT INTO control_plane.ctl_billing_facts
            (report_id, source_db, tier, tenant_id, app_id, period, line_type, currency)
        VALUES ('no-such-report', 'probe', 'POOLED', 'tnt_probe', 'app-probe',
                date_trunc('month', now())::date, 'SUBSCRIPTION', 'GHS');
        RAISE EXCEPTION 'a billing fact was accepted with no report behind it';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;  -- refused, as it should be
    END;

    -- And the honest path must work, or the reporter cannot do its job. Rolled back.
    BEGIN
        INSERT INTO control_plane.ctl_billing_reports
            (id, source_db, tier, period, reported_by, fact_count, total_due)
        VALUES (rid, 'probe', 'POOLED', date_trunc('month', now())::date, 'probe', 1, 10);

        INSERT INTO control_plane.ctl_billing_facts
            (report_id, source_db, tier, tenant_id, app_id, period, line_type,
             currency, amount_due, line_count, billable_units)
        VALUES (rid, 'probe', 'POOLED', 'tnt_probe', 'app-probe',
                date_trunc('month', now())::date, 'SUBSCRIPTION', 'GHS', 10, 1, 1);

        -- The coverage view must survive being queried; a broken view here would only
        -- show up in the console.
        PERFORM count(*) FROM control_plane.ctl_billing_coverage;
        PERFORM count(*) FROM control_plane.ctl_billing_facts_current;

        RAISE EXCEPTION 'probe_ok';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM <> 'probe_ok' THEN RAISE; END IF;
    END;

    RAISE NOTICE 'the billing ledger is ready';
END $$;
