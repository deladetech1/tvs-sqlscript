#!/usr/bin/env python3
"""The billing ledger's guarantees, proven against a real PostgreSQL.

The ledger gathers every tenant's billing into one place, and the only reason it
is safe to do that is the grant shape: the processes that WRITE to it cannot read
it, and nothing can erase it. That shape is not visible in the DDL -- it is the
interaction between a GRANT, a foreign key, and the fact that PostgreSQL requires
SELECT privilege for ``INSERT ... RETURNING``. Reading the migration will not tell
you whether it holds. Only connecting as each role will.

Three things this caught that review did not:

  1. ``INSERT ... RETURNING id`` fails for an append-only role. The reporter needs
     the report's id to attach facts to it, so with an identity column the whole
     design was unimplementable -- the writer has to choose the id itself.
  2. A tempting fix, ``GRANT SELECT (id)``, does not appear in
     ``role_table_grants``, so a table-level check would have passed while the
     column was readable.
  3. The coverage view has to collapse several pooled hosts into ONE scope, or the
     console shows four missing reports for a database that reported once.

Run (needs initdb/pg_ctl/psql on PATH -- Homebrew's postgresql@18 is enough):

    python3 scripts/test_billing_ledger.py

Or against a database you already have, as a superuser:

    TEST_DSN=postgres://... python3 scripts/test_billing_ledger.py
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
SAAS = HERE.parent / "migrations" / "saas"
MIGRATION = SAAS / "20261004-01-one-ledger-for-every-tenants-billing.sql"
# Applied after it, in filename order, exactly as the pipeline does. The customer
# table carries a foreign key to the reports table, so the two only work together.
FOLLOW_ONS = [SAAS / "20261004-03-what-each-customer-is-worth.sql"]

# What the pooled database already has, reduced to the columns the ledger reads.
# The route mix is the real dev one plus the two cases that must be EXCLUDED: a
# self-managed tenant whose timers we do not run, and a retired silo.
FIXTURE = """
CREATE SCHEMA IF NOT EXISTS control_plane;
CREATE SCHEMA IF NOT EXISTS core_platform;

CREATE TABLE IF NOT EXISTS control_plane.ctl_tenant_routes (
    host text PRIMARY KEY,
    tenant_id text,
    tier text NOT NULL,
    cell_key text NOT NULL,
    status text NOT NULL,
    is_wildcard boolean NOT NULL DEFAULT false,
    route_kind text NOT NULL DEFAULT 'PLATFORM',
    silo_key text,
    db_name text,
    db_server_fqdn text,
    db_secret_uri text,
    container_prefix text
);
CREATE TABLE IF NOT EXISTS core_platform.cp_app_schemas (schema_name text PRIMARY KEY);

TRUNCATE control_plane.ctl_tenant_routes;
INSERT INTO control_plane.ctl_tenant_routes
    (host, tenant_id, tier, cell_key, status, silo_key, db_name, route_kind) VALUES
 ('dev.trovesuite.com',             NULL,       'POOLED',        'uksouth-dev','ACTIVE', NULL,         NULL,             'PLATFORM'),
 ('mystoreguard.dev.trovesuite.com',NULL,       'POOLED',        'uksouth-dev','ACTIVE', NULL,         NULL,             'PLATFORM'),
 ('itech.dev.trovesuite.com',       'tnt_itech','SILO_SHARED',   'uksouth-dev','ACTIVE', 'itech',      'tvs_itech',      'TENANT'),
 ('accesspoint.dev.trovesuite.com', 'tnt_ap',   'SILO_DEDICATED','uksouth-dev','ACTIVE', 'accesspoint','tvs_accesspoint','TENANT'),
 ('selfhosted.example.com',         'tnt_sh',   'SELF_MANAGED',  'uksouth-dev','ACTIVE', 'sh',         'tvs_sh',         'TENANT'),
 ('retired.dev.trovesuite.com',     'tnt_old',  'SILO_SHARED',   'uksouth-dev','RETIRED','retired',    'tvs_retired',    'TENANT');

-- THE MIGRATOR.
--
-- The pipeline applies migrations as a role that owns the schemas and is NOT a
-- superuser. That distinction is not academic: the first version of this
-- migration created a group role, which works as postgres and fails on Azure
-- Flexible Server with "permission denied to create role" -- found on dev,
-- after review, after a green local run. Applying as this role instead is the
-- only way the test can see what the pipeline sees.
DO $r$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='migrator') THEN
     CREATE ROLE migrator LOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER;
  END IF;
END $r$;

-- The grant model: one NOLOGIN group per environment, a login per app inside it.
DO $r$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tvs_app_dev')
     THEN CREATE ROLE tvs_app_dev NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coreplatform_dev')
     THEN CREATE ROLE coreplatform_dev LOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='mystoreguard_dev')
     THEN CREATE ROLE mystoreguard_dev LOGIN; END IF;
END $r$;
GRANT tvs_app_dev TO coreplatform_dev;
GRANT tvs_app_dev TO mystoreguard_dev;
GRANT USAGE ON SCHEMA control_plane, core_platform TO tvs_app_dev;
-- Apps resolve routes, so reading this table is part of being an app.
GRANT SELECT ON control_plane.ctl_tenant_routes TO tvs_app_dev;

-- AND THE SCHEMA DEFAULT, which is the part that matters here.
--
-- 20261001-01 ends with this, so every table created in control_plane afterwards
-- is readable by every application group without anybody deciding so. The ledger
-- was born that way and the migration has to revoke it. A fixture without this
-- line cannot see the hole -- which is precisely what happened: the test passed
-- locally and the migration failed its own assertion on dev.
-- FOR ROLE migrator, because a default privilege is keyed to the role that
-- CREATES the object, not to the schema alone. In the pipeline 20261001-01 runs
-- as the migrator, so its ALTER DEFAULT PRIVILEGES is implicitly for the same
-- role that later creates the ledger -- and that is what makes the hole real.
-- Setting it as postgres here would key it to postgres, apply to nothing the
-- migration creates, and quietly turn this fixture back into one that cannot
-- see the problem.
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA control_plane
    GRANT SELECT ON TABLES TO tvs_app_dev;

-- The migrator owns what it migrates, which is what lets it grant on its own
-- tables without being a superuser. It can also create a schema -- the real one
-- created control_plane and deladetech -- which is why the migration's defensive
-- CREATE SCHEMA IF NOT EXISTS is not a privilege it lacks.
GRANT CREATE ON DATABASE ledger TO migrator;
ALTER SCHEMA control_plane OWNER TO migrator;
ALTER SCHEMA core_platform OWNER TO migrator;
ALTER TABLE control_plane.ctl_tenant_routes OWNER TO migrator;
ALTER TABLE core_platform.cp_app_schemas OWNER TO migrator;

-- The console's own login, which it does not use yet -- today it borrows
-- core-platform's. It exists here to prove the read grant follows it with no
-- migration change, and that it needs NOTHING else: not app-group membership,
-- not the route table.
DO $r$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='deladetech_dev')
     THEN CREATE ROLE deladetech_dev LOGIN; END IF;
END $r$;
"""

PERIOD = "date_trunc('month', now())::date"

FAILS = []


def check(label, got, want):
    ok = got == want
    print(f"{'PASS' if ok else 'FAIL'}  {label}: got {got!r}, want {want!r}")
    if not ok:
        FAILS.append(label)


def check_contains(label, got, needle):
    ok = needle.lower() in (got or "").lower()
    print(f"{'PASS' if ok else 'FAIL'}  {label}: got {got!r}, want ~{needle!r}")
    if not ok:
        FAILS.append(label)


class Postgres:
    """A throwaway cluster, or whatever TEST_DSN points at."""

    def __init__(self):
        self.tmp = None
        self.dsn_base = os.environ.get("TEST_DSN")

    def start(self):
        if self.dsn_base:
            return
        for tool in ("initdb", "pg_ctl", "psql"):
            if not shutil.which(tool):
                sys.exit(f"{tool} is not on PATH; install postgresql or set TEST_DSN")
        # Short path: a unix socket directory longer than 103 bytes cannot be
        # connected to, and the usual scratch directories are longer than that.
        self.tmp = tempfile.mkdtemp(prefix="/tmp/pgl")
        data = os.path.join(self.tmp, "data")
        subprocess.run(
            ["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["pg_ctl", "-D", data, "-l", os.path.join(self.tmp, "pg.log"), "-o",
             f"-p 5478 -k {self.tmp} -c listen_addresses=''", "start"],
            check=True, capture_output=True,
        )
        for _ in range(60):
            if self.run("postgres", "SELECT 1", db="postgres").returncode == 0:
                break
            time.sleep(0.5)

    def stop(self):
        if self.tmp:
            subprocess.run(["pg_ctl", "-D", os.path.join(self.tmp, "data"), "-m",
                            "immediate", "stop"], capture_output=True)
            shutil.rmtree(self.tmp, ignore_errors=True)

    def _args(self, user, db):
        if self.dsn_base:
            return ["psql", self.dsn_base, "-U", user, "-d", db]
        return ["psql", "-h", self.tmp, "-p", "5478", "-U", user, "-d", db]

    def run(self, user, sql, db="ledger", file=False):
        # ON_ERROR_STOP for a FILE. Without it psql carries on past a failed
        # statement and exits 0, so a migration that half-applied reported
        # success here and the real cause surfaced three checks later as
        # "permission denied" on a grant that never ran.
        args = self._args(user, db) + (
            ["-v", "ON_ERROR_STOP=1", "-f", sql] if file else ["-tAc", sql])
        return subprocess.run(args, capture_output=True, text=True)

    def value(self, user, sql, db="ledger"):
        r = self.run(user, sql, db)
        out = (r.stdout or "").strip() or (r.stderr or "").strip()
        return out.splitlines()[0] if out else ""


def main():
    pg = Postgres()
    pg.start()
    try:
        pg.run("postgres", "DROP DATABASE IF EXISTS ledger", db="postgres")
        pg.run("postgres", "CREATE DATABASE ledger", db="postgres")

        with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fh:
            fh.write(FIXTURE)
            fixture_path = fh.name
        r = pg.run("postgres", fixture_path, file=True)
        if r.returncode != 0:
            sys.exit("fixture failed:\n" + r.stderr)

        # ---------------------------------------------------- the migration itself
        # As the MIGRATOR, which is not a superuser -- see the fixture.
        r = pg.run("migrator", str(MIGRATION), file=True)
        check("the migration applies as a non-superuser migrator", r.returncode, 0)
        for extra in FOLLOW_ONS:
            r2 = pg.run("migrator", str(extra), file=True)
            check(f"...and {extra.name[:22]} applies too", r2.returncode, 0)
            if r2.returncode != 0:
                print(r2.stderr)
        if r.returncode != 0:
            print(r.stderr)
            sys.exit(1)

        # It is re-applied on every deploy, so a second run must be a no-op.
        r = pg.run("migrator", str(MIGRATION), file=True)
        check("and applies a second time (re-run on every deploy)", r.returncode, 0)
        for extra in FOLLOW_ONS:
            check(f"...{extra.name[:22]} is re-runnable too",
                  pg.run("migrator", str(extra), file=True).returncode, 0)
        if r.returncode != 0:
            print(r.stderr)

        # -------------------------------------------- a silo reports, append-only
        # No RETURNING anywhere: the writer chooses its own ids, because an
        # append-only role cannot be told what the database assigned.
        check(
            "an app role may append a report",
            pg.value("mystoreguard_dev", f"""
                INSERT INTO control_plane.ctl_billing_reports
                    (id, source_db, tier, silo_key, host, period, period_label,
                     reported_by, fact_count, tenant_count, currency,
                     total_due, total_paid)
                VALUES ('billrep_t1', 'tvs_itech', 'SILO_SHARED', 'itech',
                        'itech.dev.trovesuite.com', {PERIOD}, 'Oct 2026',
                        'report_billing_facts', 1, 1, 'GHS', 250.00, 250.00)"""),
            "INSERT 0 1",
        )
        check(
            "...and the fact attached to it",
            pg.value("mystoreguard_dev", f"""
                INSERT INTO control_plane.ctl_billing_facts
                    (id, report_id, source_db, tier, silo_key, tenant_id, app_id,
                     period, period_label, line_type, currency, amount_due,
                     amount_paid, line_count, paid_line_count, billable_units)
                VALUES ('billfact_t1', 'billrep_t1', 'tvs_itech', 'SILO_SHARED',
                        'itech', 'tnt_itech', 'app-msg', {PERIOD}, 'Oct 2026',
                        'SUBSCRIPTION', 'GHS', 250.00, 250.00, 1, 1, 1)"""),
            "INSERT 0 1",
        )
        check_contains(
            "money cannot be pushed with no report accounting for it",
            pg.value("mystoreguard_dev", f"""
                INSERT INTO control_plane.ctl_billing_facts
                    (report_id, source_db, tier, tenant_id, app_id, period,
                     line_type, currency)
                VALUES ('billrep_nope', 'x', 'POOLED', 't', 'a', {PERIOD},
                        'SUBSCRIPTION', 'GHS')"""),
            "foreign key",
        )

        # ------------------------------------- and a writer still cannot read it
        for table in ("ctl_billing_facts", "ctl_billing_reports"):
            check_contains(
                f"a writer cannot read {table}",
                pg.value("mystoreguard_dev", f"SELECT count(*) FROM control_plane.{table}"),
                "permission denied",
            )
        check_contains(
            "a writer cannot read the coverage view",
            pg.value("mystoreguard_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_coverage"),
            "permission denied",
        )
        # The column-level loophole, which a table-level grant check would miss.
        check_contains(
            "a writer cannot read even the id column",
            pg.value("mystoreguard_dev",
                     "SELECT id FROM control_plane.ctl_billing_reports LIMIT 1"),
            "permission denied",
        )

        # ------------------------------------------------- nothing rewrites history
        for role in ("mystoreguard_dev", "coreplatform_dev"):
            for verb, sql in (
                ("UPDATE", "UPDATE control_plane.ctl_billing_facts SET amount_due = 0"),
                ("DELETE", "DELETE FROM control_plane.ctl_billing_facts"),
            ):
                check_contains(f"{role} cannot {verb} the ledger",
                               pg.value(role, sql), "permission denied")

        # ----------------------------------------------------- the console reads
        check("the console reads the facts",
              pg.value("coreplatform_dev",
                       "SELECT count(*) FROM control_plane.ctl_billing_facts"), "1")
        # The console's OWN login, which nothing granted by hand. The migration
        # matches coreplatform_*/deladetech_*, so the day the console stops
        # borrowing a credential the grant follows it on the next deploy.
        #
        # A dedicated group role would read better, but the migrator on Azure
        # Flexible Server cannot CREATE ROLE -- which is how this migration first
        # failed on dev -- so the grant goes to logins by name instead.
        check(
            "the console's own login can read the ledger, ungranted by hand",
            pg.value("deladetech_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_facts"),
            "1",
        )
        check(
            "...and the coverage view, which it is not a member of any app group for",
            pg.value("deladetech_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_coverage"),
            "3",
        )
        # The coverage view reads the route table; the view's owner supplies that
        # access. If it did not, giving the console its own login would quietly
        # need a second grant on ctl_tenant_routes.
        check(
            "...while holding no privilege on the route table at all",
            pg.value("postgres",
                     "SELECT has_table_privilege('deladetech_dev',"
                     "'control_plane.ctl_tenant_routes','SELECT')::text"),
            "false",
        )
        check_contains(
            "...and still cannot write",
            pg.value("deladetech_dev",
                     "DELETE FROM control_plane.ctl_billing_facts"),
            "permission denied",
        )
        # Nothing may create a role here, because the migrator cannot.
        check(
            "the migration creates no role",
            "CREATE ROLE" not in MIGRATION.read_text().replace(
                "CREATE ROLE fails", ""),
            True,
        )

        # ------------------------------------------------- coverage: the whole point
        # Two pooled hosts, two live silos, one self-managed, one retired.
        check(
            "coverage lists one scope per database, not per host",
            pg.value("coreplatform_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_coverage"),
            "3",
        )
        check(
            "self-managed is not expected to report",
            pg.value("coreplatform_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_coverage "
                     "WHERE tier = 'SELF_MANAGED'"),
            "0",
        )
        check(
            "a retired silo is not expected either",
            pg.value("coreplatform_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_coverage "
                     "WHERE silo_key = 'retired'"),
            "0",
        )
        check(
            "the silo that reported is not flagged",
            pg.value("coreplatform_dev",
                     "SELECT never_reported::text || ',' || current_period_missing::text "
                     "FROM control_plane.ctl_billing_coverage WHERE silo_key = 'itech'"),
            "false,false",
        )
        check(
            "the silo that went quiet IS flagged",
            pg.value("coreplatform_dev",
                     "SELECT never_reported::text FROM control_plane.ctl_billing_coverage "
                     "WHERE silo_key = 'accesspoint'"),
            "true",
        )
        check(
            "and so is the pooled database",
            pg.value("coreplatform_dev",
                     "SELECT never_reported::text FROM control_plane.ctl_billing_coverage "
                     "WHERE silo_key IS NULL"),
            "true",
        )

        # ------------------------------------- a correction is a later snapshot
        pg.run("mystoreguard_dev", f"""
            INSERT INTO control_plane.ctl_billing_reports
                (id, source_db, tier, silo_key, period, reported_by, fact_count,
                 tenant_count, currency, total_due, total_paid)
            VALUES ('billrep_t2', 'tvs_itech', 'SILO_SHARED', 'itech', {PERIOD},
                    'report_billing_facts', 1, 1, 'GHS', 400.00, 250.00)""")
        pg.run("mystoreguard_dev", f"""
            INSERT INTO control_plane.ctl_billing_facts
                (id, report_id, source_db, tier, silo_key, tenant_id, app_id, period,
                 line_type, currency, amount_due, amount_paid, line_count,
                 paid_line_count, billable_units, observed_at)
            VALUES ('billfact_t2', 'billrep_t2', 'tvs_itech', 'SILO_SHARED', 'itech',
                    'tnt_itech', 'app-msg', {PERIOD}, 'SUBSCRIPTION', 'GHS',
                    400.00, 250.00, 2, 1, 2, now() + interval '1 second')""")
        check(
            "the current figure is the latest snapshot, not the sum of both",
            pg.value("coreplatform_dev",
                     "SELECT amount_due::text FROM control_plane.ctl_billing_facts_current "
                     "WHERE tenant_id = 'tnt_itech'"),
            "400.00",
        )
        check(
            "...and the superseded one is still on record",
            pg.value("coreplatform_dev",
                     "SELECT count(*) FROM control_plane.ctl_billing_facts "
                     "WHERE tenant_id = 'tnt_itech'"),
            "2",
        )

        # ------------------------------ the report must agree with what it carried
        check(
            "a report whose totals disagree with its facts is detectable",
            pg.value("coreplatform_dev", """
                SELECT count(*)::text FROM control_plane.ctl_billing_reports r
                 WHERE r.total_due <> COALESCE((
                       SELECT sum(f.amount_due) FROM control_plane.ctl_billing_facts f
                        WHERE f.report_id = r.id), 0)"""),
            "0",
        )
    finally:
        pg.stop()

    print(
        f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed."
    )
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
