#!/usr/bin/env python3
"""The dev silo fixtures survive in dev and nowhere else.

20261006-04 removes the itech and accesspoint route rows from every database
except dev's own. It cannot be reviewed by reading it, because the branch it
takes depends on ``current_database()`` -- so the only way to know it is right is
to run it inside several differently-named databases and look.

The dangerous direction is not the one it was written for. Getting production
wrong leaves two stale rows; getting DEV wrong deletes itech's and accesspoint's
routes from the databases that need them, and shared/ is applied to the silo
databases too -- so the file runs INSIDE silo-itech-dev, where the row it wants
to delete elsewhere is the one that must stay.

Four databases, one per shape the file can ever run in:

    dev-db                the dev control plane            keeps
    silo-itech-dev        a dev silo's own database        keeps
    silo-accesspoint-dev  the other one                    keeps
    prod-db               production                       strips
    stage-db              staging                          strips

Run (needs a real server, not just libpq -- libpq ships initdb but not the
`postgres` binary it calls, so put postgresql@18 ahead of it:
`export PATH=/opt/homebrew/opt/postgresql@18/bin:$PATH`):

    python3 scripts/test_dev_silos_belong_to_dev.py

Or against a server you already have, as a superuser:

    TEST_DSN=postgres://... python3 scripts/test_dev_silos_belong_to_dev.py
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATION = ROOT / "migrations" / "shared" / "20261006-04-dev-silos-belong-only-to-dev.sql"

# Enough of the table for the migration to run. Only the columns it reads.
SCHEMA = """
CREATE SCHEMA IF NOT EXISTS control_plane;
CREATE TABLE control_plane.ctl_tenant_routes (
    host     text PRIMARY KEY,
    cell_key text,
    tier     text NOT NULL,
    db_name  text,
    silo_key text
);
INSERT INTO control_plane.ctl_tenant_routes (host, cell_key, tier, db_name, silo_key) VALUES
    -- the two dev silo fixtures, seeded everywhere by 20261004-02
    ('itech.dev.trovesuite.com',       'uksouth-dev',     'SILO_SHARED',
     'silo-itech-dev',       'itech'),
    ('accesspoint.dev.trovesuite.com', 'uksouth-dev',     'SILO_DEDICATED',
     'silo-accesspoint-dev', 'accesspoint'),
    -- the address registry, which must be left alone in every database
    ('dev.trovesuite.com',             'uksouth-dev',     'POOLED', NULL, NULL),
    ('trovesuite.com',                 'uksouth-prod',    'POOLED', NULL, NULL),
    ('staging.trovesuite.com',         'uksouth-staging', 'POOLED', NULL, NULL);
"""

DATABASES = {
    "dev-db": True,                # the dev control plane
    "silo-itech-dev": True,        # a dev silo, where the row must stay
    "silo-accesspoint-dev": True,
    "prod-db": False,
    "stage-db": False,
}


def psql(dsn, *args, sql=None, check=True):
    cmd = ["psql", dsn, "-X", "-q", "-v", "ON_ERROR_STOP=1", "-At", *args]
    r = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if check and r.returncode != 0:
        raise SystemExit(f"psql failed:\n{r.stderr}")
    return r


class Server:
    """A throwaway cluster, or whatever TEST_DSN points at."""

    def __init__(self):
        self.base = os.environ.get("TEST_DSN")
        self.dir = None
        if self.base:
            return
        for tool in ("initdb", "pg_ctl", "psql"):
            if not shutil.which(tool):
                sys.exit(f"{tool} is not on PATH; install postgresql or set TEST_DSN")
        self.dir = tempfile.mkdtemp(prefix="devsilo-")
        data, sock = f"{self.dir}/data", f"{self.dir}/sock"
        os.mkdir(sock)
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "-A", "trust"],
                       capture_output=True, check=True)
        subprocess.run(["pg_ctl", "-D", data, "-l", f"{self.dir}/log", "-o",
                        f"-k {sock} -h '' -c listen_addresses=''", "-w", "start"],
                       capture_output=True, check=True)
        self.base = f"postgres://postgres@/postgres?host={sock}"
        self.sock = sock

    def dsn(self, db):
        if self.dir:
            return f"postgres://postgres@/{db}?host={self.sock}"
        sep = "&" if "?" in self.base else "?"
        return f"{self.base}{sep}dbname={db}"

    def stop(self):
        if self.dir:
            subprocess.run(["pg_ctl", "-D", f"{self.dir}/data", "-m", "immediate", "stop"],
                           capture_output=True)
            shutil.rmtree(self.dir, ignore_errors=True)


def main():
    if not MIGRATION.exists():
        sys.exit(f"missing {MIGRATION}")
    sql = MIGRATION.read_text()
    server = Server()
    failures = []
    try:
        for db, is_dev in DATABASES.items():
            psql(server.dsn("postgres"), sql=f'CREATE DATABASE "{db}";')
            dsn = server.dsn(db)
            psql(dsn, sql=SCHEMA)

            # Twice: a migration re-runs on every deploy, so it has to be a no-op
            # the second time rather than only correct the first.
            for pass_no in (1, 2):
                psql(dsn, sql=sql)

                silos = int(psql(dsn, sql=(
                    "SELECT count(*) FROM control_plane.ctl_tenant_routes "
                    "WHERE cell_key='uksouth-dev' AND tier<>'POOLED';")).stdout.strip())
                pooled = int(psql(dsn, sql=(
                    "SELECT count(*) FROM control_plane.ctl_tenant_routes "
                    "WHERE tier='POOLED';")).stdout.strip())

                want = 2 if is_dev else 0
                ok = silos == want and pooled == 3
                mark = "PASS" if ok else "FAIL"
                if pass_no == 1 or not ok:
                    print(f"{mark}  {db:<22} run {pass_no}: {silos} dev silo row(s) "
                          f"(want {want}), {pooled} pooled row(s) (want 3)")
                if not ok:
                    failures.append((db, pass_no, silos, pooled))
    finally:
        server.stop()

    print()
    if failures:
        for db, p, s, pl in failures:
            print(f"  BROKEN {db} run {p}: silos={s} pooled={pl}")
        print("BROKEN")
        return 1
    print("OK -- dev keeps its silo routes, every other database loses them, "
          "and the address registry is untouched everywhere")
    return 0


if __name__ == "__main__":
    sys.exit(main())
