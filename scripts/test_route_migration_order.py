#!/usr/bin/env python3
"""The route migrations, applied the way the pipeline applies them.

# WHY THIS EXISTS

Every migration re-runs on every deploy. That is fine until a migration adds a
constraint, because then every EARLIER migration that writes the same table has
to satisfy a rule that did not exist when it was written -- and the failure does
not appear on the deploy that adds the constraint. It appears on the next one.

That is exactly what happened. 20261003-07 added route_kind, with a default of
'PLATFORM' and a check that a customer's address may never resolve to the pooled
database. The deploy that added it passed. The next deploy died in
20261002-09 -- a seed from the day before -- with

    new row for relation "ctl_tenant_routes" violates check constraint
    "ck_ctl_routes_tenant_kind_not_pooled"

because the two silo clients had been cleared and set up again in between, so
the seed had no rows to UPDATE and fell into its INSERT path, where the default
applied. One release of delay, in a pipeline every schema change goes through.

A single pass over the migrations cannot catch this; it needs the second pass.
So this does three:

  1. a FRESH database, where a later migration's column does not exist yet;
  2. a RE-RUN, where it does, and the rows are there to be updated;
  3. a re-run with the rows DELETED, which is the state that actually broke --
     and the only one of the three that fails on both of the obvious fixes.

Run (needs initdb/pg_ctl/psql on PATH):

    python3 scripts/test_route_migration_order.py
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
SHARED = HERE.parent / "migrations" / "shared"
SAAS = HERE.parent / "migrations" / "saas"

PORT = "5482"

# The migrations that touch control_plane. Chosen by what they do rather than by
# a date range, so a new one is picked up without editing this list.
def route_migrations():
    out = []
    for path in sorted(SHARED.glob("*.sql")):
        text = path.read_text()
        if "ctl_tenant_routes" in text or "control_plane" in text:
            out.append(path)
    # The ledger lives in saas/ and reads the route table, so it belongs in the
    # same ordering check -- its coverage view breaks if a route column moves.
    out += [p for p in sorted(SAAS.glob("*.sql")) if "ctl_tenant_routes" in p.read_text()]
    return out


FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}{(': ' + detail) if detail and not ok else ''}")
    if not ok:
        FAILS.append(label)


class Cluster:
    def __init__(self):
        self.dir = None

    def start(self):
        for tool in ("initdb", "pg_ctl", "psql"):
            if not shutil.which(tool):
                sys.exit(f"{tool} is not on PATH; install postgresql")
        self.dir = tempfile.mkdtemp(prefix="/tmp/pgro")
        data = os.path.join(self.dir, "data")
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
                       check=True, capture_output=True)
        subprocess.run(
            ["pg_ctl", "-D", data, "-l", os.path.join(self.dir, "pg.log"), "-o",
             f"-p {PORT} -k {self.dir} -c listen_addresses=''", "start"],
            check=True, capture_output=True)
        for _ in range(60):
            if self.sql("SELECT 1").returncode == 0:
                break
            time.sleep(0.5)
        # The one thing outside control_plane that these migrations read.
        self.sql("CREATE SCHEMA IF NOT EXISTS core_platform")
        self.sql("CREATE TABLE IF NOT EXISTS core_platform.cp_app_schemas "
                 "(schema_name text PRIMARY KEY)")

    def stop(self):
        if self.dir:
            subprocess.run(["pg_ctl", "-D", os.path.join(self.dir, "data"), "-m",
                            "immediate", "stop"], capture_output=True)
            shutil.rmtree(self.dir, ignore_errors=True)

    def sql(self, statement):
        return subprocess.run(
            ["psql", "-h", self.dir, "-p", PORT, "-U", "postgres", "-d", "postgres",
             "-v", "ON_ERROR_STOP=1", "-tAc", statement],
            capture_output=True, text=True)

    def value(self, statement):
        r = self.sql(statement)
        return (r.stdout or r.stderr or "").strip().splitlines()[0] if (r.stdout or r.stderr).strip() else ""

    def apply_all(self, files):
        """Every migration in order. Returns [(name, first error line)]."""
        failures = []
        for path in files:
            r = subprocess.run(
                ["psql", "-h", self.dir, "-p", PORT, "-U", "postgres", "-d", "postgres",
                 "-v", "ON_ERROR_STOP=1", "-q", "-f", str(path)],
                capture_output=True, text=True)
            if r.returncode != 0:
                line = next((l for l in (r.stderr or "").splitlines()
                             if "ERROR" in l), r.stderr.strip()[:200])
                failures.append((path.name, re.sub(r"^psql:[^ ]* ", "", line)))
        return failures


def main():
    files = route_migrations()
    print(f"{len(files)} migrations touch the control plane\n")

    c = Cluster()
    c.start()
    try:
        # ------------------------------------------------------------ pass 1
        failures = c.apply_all(files)
        check("a fresh database applies them all", not failures,
              "; ".join(f"{n} -> {e}" for n, e in failures))

        # ------------------------------------------------------------ pass 2
        failures = c.apply_all(files)
        check("a second pass applies them all (they re-run every deploy)",
              not failures, "; ".join(f"{n} -> {e}" for n, e in failures))

        # ------------------------------------------------------------ pass 3
        # The state that actually broke: a silo's route removed after the
        # constraint existed, so the seed has to INSERT rather than UPDATE.
        c.sql("DELETE FROM control_plane.ctl_tenant_routes WHERE silo_key IS NOT NULL")
        failures = c.apply_all(files)
        check("a pass with every silo route deleted re-creates them",
              not failures, "; ".join(f"{n} -> {e}" for n, e in failures))

        # ---------------------------------------------------- and the result
        check("every silo route says it is a tenant address",
              c.value("SELECT count(*) FROM control_plane.ctl_tenant_routes "
                      "WHERE tier <> 'POOLED' AND route_kind <> 'TENANT'") == "0")
        check("no platform route claims a silo tier",
              c.value("SELECT count(*) FROM control_plane.ctl_tenant_routes "
                      "WHERE route_kind = 'PLATFORM' AND tier <> 'POOLED'") == "0")
        check("the retired test hosts stay deleted",
              c.value("SELECT count(*) FROM control_plane.ctl_tenant_routes WHERE host "
                      "IN ('ddt.dev.trovesuite.com','bidtl.dev.trovesuite.com')") == "0")

        # The ledger's coverage view reads the route table, so a route column
        # moving breaks the billing screens and nothing else.
        check("the billing coverage view still resolves",
              c.sql("SELECT count(*) FROM control_plane.ctl_billing_coverage").returncode == 0)
        check("...and lists one scope per database: the pool plus each live silo",
              c.value("SELECT count(*) FROM control_plane.ctl_billing_coverage") == "3",
              c.value("SELECT string_agg(COALESCE(silo_key,'(pooled)'), ', ') "
                      "FROM control_plane.ctl_billing_coverage"))
    finally:
        c.stop()

    print(f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed.")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
