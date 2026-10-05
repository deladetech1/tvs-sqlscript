#!/usr/bin/env python3
"""Can the console do the things it does, as the role it actually connects as?

# WHY THIS EXISTS

Clearing a silo client deletes its setup row so the host can be set up again.
It never once worked. The app role was granted SELECT, INSERT, UPDATE on
dlt_client_setups and DELETE on nothing but dlt_operator_sessions -- written
when sessions really were the only thing the console deleted, and never
revisited when the clear feature arrived.

The handler logged the refusal at WARN and carried on, so every silo clear
answered COMPLETED with setups_removed = 0 and told the operator "the host is
available to set up again". It was not. Setting the same client up then refused
with "There is already a COMPLETED setup for this host", and nothing joined the
two statements together. Four clears went that way before anybody worked it out.

Nothing caught it because every other test runs as a superuser or the migrator,
and both have DELETE on everything. A grant is only visible from the role that
has to use it -- which is the same lesson test_billing_ledger.py exists for.

# WHAT IS ASSERTED

The console must be able to:
  * delete a setup row, which is what frees a host

and must NOT be able to:
  * delete a clear record -- the audit of the very operation doing the deleting,
    which is why those live in a separate table
  * delete an operator -- that is who-did-what

Run (needs initdb/pg_ctl/psql on PATH):

    python3 scripts/test_console_grants.py
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

# In filename order, exactly as the pipeline applies them: the console's tables,
# then the clear audit, then the grant that was missing.
MIGRATIONS = [
    SAAS / "20261003-01-deladetech-hosting-requests.sql",
    SAAS / "20261003-04-deladetech-console.sql",
    SAAS / "20261003-06-record-every-client-clear.sql",
    SAAS / "20261005-05-the-clear-may-delete-the-setup-record.sql",
]

# The roles as dev has them: a NOLOGIN group holding the privileges, and a login
# role that is a member. The console connects as the login role -- coreplatform_dev
# on dev, which is the detail that makes "grant to the app group" load-bearing.
FIXTURE = """
-- The one thing outside deladetech these migrations read. Minimal on purpose:
-- this test is about grants, not about the console's schema.
CREATE SCHEMA IF NOT EXISTS core_platform;
CREATE TABLE IF NOT EXISTS core_platform.cp_app_schemas (schema_name text PRIMARY KEY);

DO $r$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='migrator') THEN
     CREATE ROLE migrator LOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tvs_app_dev')
     THEN CREATE ROLE tvs_app_dev NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coreplatform_dev')
     THEN CREATE ROLE coreplatform_dev LOGIN; END IF;
END $r$;
GRANT tvs_app_dev TO coreplatform_dev;
GRANT ALL ON DATABASE console TO migrator;

-- The migrator OWNS the schemas on dev. Created above by postgres, so handed
-- over -- otherwise the first migration fails with "permission denied for
-- schema core_platform" and the whole run reports grant failures that are
-- really an ownership problem in the fixture.
ALTER SCHEMA core_platform OWNER TO migrator;
ALTER TABLE core_platform.cp_app_schemas OWNER TO migrator;
"""

FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f": {detail}" if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


class Postgres:
    def __init__(self):
        self.tmp = None

    def start(self):
        for tool in ("initdb", "pg_ctl", "psql"):
            if not shutil.which(tool):
                sys.exit(f"{tool} is not on PATH; install postgresql")
        # Short path: a unix socket directory over 103 bytes cannot be connected to.
        self.tmp = tempfile.mkdtemp(prefix="/tmp/pgcg")
        data = os.path.join(self.tmp, "data")
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
                       check=True, capture_output=True)
        subprocess.run(
            ["pg_ctl", "-D", data, "-l", os.path.join(self.tmp, "pg.log"), "-o",
             f"-p 5477 -k {self.tmp} -c listen_addresses=''", "start"],
            check=True, capture_output=True)
        for _ in range(60):
            if self.run("postgres", "SELECT 1", db="postgres").returncode == 0:
                break
            time.sleep(0.5)

    def stop(self):
        if self.tmp:
            subprocess.run(["pg_ctl", "-D", os.path.join(self.tmp, "data"),
                            "-m", "immediate", "stop"], capture_output=True)
            shutil.rmtree(self.tmp, ignore_errors=True)

    def run(self, user, sql, db="console", file=False):
        # ON_ERROR_STOP for a file, or psql carries on past a failed statement
        # and exits 0 -- a half-applied migration then reports success here.
        args = ["psql", "-h", self.tmp, "-p", "5477", "-U", user, "-d", db] + (
            ["-v", "ON_ERROR_STOP=1", "-f", sql] if file else ["-tAc", sql])
        return subprocess.run(args, capture_output=True, text=True)

    def value(self, user, sql, db="console"):
        r = self.run(user, sql, db)
        out = (r.stdout or "").strip() or (r.stderr or "").strip()
        return out.splitlines()[0] if out else ""


def main():
    pg = Postgres()
    pg.start()
    try:
        pg.run("postgres", "DROP DATABASE IF EXISTS console", db="postgres")
        pg.run("postgres", "CREATE DATABASE console", db="postgres")
        with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fh:
            fh.write(FIXTURE)
            fixture = fh.name
        r = pg.run("postgres", fixture, file=True)
        if r.returncode != 0:
            sys.exit("fixture failed: " + (r.stderr or "")[:400])
        os.unlink(fixture)

        # AS THE MIGRATOR, not as postgres: the pipeline applies migrations as a
        # non-superuser that owns the schemas, and a GRANT a superuser can make
        # is not proof the migrator can.
        for m in MIGRATIONS:
            if not m.exists():
                sys.exit(f"missing migration: {m.name}")
            r = pg.run("migrator", str(m), file=True)
            if r.returncode != 0:
                line = next((l for l in (r.stderr or "").splitlines() if "ERROR" in l),
                            (r.stderr or "")[:200])
                check(f"{m.name} applies", False, line)
                break
        else:
            check("the console's migrations apply as the migrator", True)

        # Rows to act on, created by the role that owns them.
        pg.run("migrator", """
            INSERT INTO deladetech.dlt_client_setups
                (id, hosting_kind, host, silo_key, company_name, owner_email,
                 tenant_id, status)
            VALUES ('stp_probe','SILO_SHARED','probe.dev.trovesuite.com','probe',
                    'Probe Ltd','probe@example.invalid','tnt_probe','COMPLETED')
            ON CONFLICT (id) DO NOTHING""")
        check("a setup row exists to act on",
              pg.value("migrator",
                       "SELECT count(*) FROM deladetech.dlt_client_setups") == "1")

        # ------------------------------------------------- what the console MAY do
        #
        # As coreplatform_dev, which is what the console connects as on dev -- not
        # as the group that holds the privilege. Membership is the thing being
        # tested as much as the grant.
        check("the console connects as a login role, not the group",
              pg.value("coreplatform_dev", "SELECT current_user") == "coreplatform_dev")

        out = pg.value("coreplatform_dev",
                       "DELETE FROM deladetech.dlt_client_setups "
                       "WHERE host = 'probe.dev.trovesuite.com'")
        check("the console may delete a setup row, which is what frees a host",
              "DELETE" in out or out == "", out)
        check("...and the row is actually gone",
              pg.value("migrator",
                       "SELECT count(*) FROM deladetech.dlt_client_setups") == "0")

        # ------------------------------------------- what it must NOT be able to do
        pg.run("migrator", """
            INSERT INTO deladetech.dlt_client_clears
                (id, tenant_id, tenant_name, host, hosting_kind, status, reason,
                 performed_by)
            VALUES ('clr_probe','tnt_probe','Probe Ltd','probe.dev.trovesuite.com',
                    'SILO_SHARED','COMPLETED','probe','probe@example.invalid')
            ON CONFLICT (id) DO NOTHING""")
        out = pg.value("coreplatform_dev",
                       "DELETE FROM deladetech.dlt_client_clears WHERE id='clr_probe'")
        check("it may NOT delete a clear record -- that is the audit of the purge",
              "permission denied" in out.lower(), out)
        check("...and the record survived",
              pg.value("migrator",
                       "SELECT count(*) FROM deladetech.dlt_client_clears "
                       "WHERE id='clr_probe'") == "1")

        out = pg.value("coreplatform_dev", "DELETE FROM deladetech.dlt_operators")
        check("it may NOT delete an operator -- that is who did what",
              "permission denied" in out.lower(), out)

        # Sessions it genuinely does delete, and always could. Asserted so a future
        # tightening of these grants does not take the legitimate one with it.
        # Asserted as a SUCCESSFUL delete, not as "no permission error". The
        # first version checked the latter, which passes on any other failure --
        # including the missing-table errors this test produced while its
        # fixture was incomplete. It reported PASS with nothing in the database.
        out = pg.value("coreplatform_dev",
                       "DELETE FROM deladetech.dlt_operator_sessions "
                       "WHERE token_hash = 'none'")
        check("it may still delete an expired session",
              out.strip().startswith("DELETE"), out)
    finally:
        pg.stop()

    print(f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed.")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
