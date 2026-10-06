#!/usr/bin/env python3
"""Do the migrations still apply AFTER somebody has used the feature they add?

# WHY THIS EXISTS

Every migration re-runs on every deploy. A self-check written as "no row has
this yet" therefore passes on the deploy that adds the column and fails on the
first deploy after somebody legitimately used it -- which is the worst possible
timing, because by then nobody connects the failure to a migration written
weeks earlier.

This has now happened twice:

  * 20261003-07 added a constraint that an earlier seed violated, and the
    deploy AFTER it died in 20261002-09 (see test_route_migration_order.py);
  * 20261004-05 asserted "no tenant is locked immediately after adding the
    column". True on a fresh database. The first deploy after anybody was
    suspended would have failed, and suspending somebody is the entire point
    of the column.

A single pass cannot see either. So this applies each migration, USES the
feature the way the product uses it, and applies it again.

Run (needs initdb/pg_ctl/psql on PATH):

    python3 scripts/test_migrations_survive_use.py
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
SHARED = HERE.parent / "migrations" / "shared"
PORT = "5487"

# What the product does once the migration has shipped. Each entry is
# (migration, what somebody does with it, how to check it survived).
#
# Written as the product writes it -- a real UPDATE of a real row -- because
# the point is to leave the database in the state a live one is actually in.
CASES = [
    (
        "20261004-05-a-tenant-can-be-locked.sql",
        "UPDATE core_platform.cp_tenants SET is_locked = true, locked_at = now(), "
        "locked_by = 'owner@deladetech.com', lock_reason = 'unpaid' WHERE id = 't1'",
        "SELECT is_locked::text FROM core_platform.cp_tenants WHERE id = 't1'",
        "true",
        "a customer is suspended",
    ),
    (
        "20261004-06-an-agreed-rate-for-one-client.sql",
        "UPDATE core_platform.cp_app_subscriptions SET rate_override = 13.5000, "
        "rate_override_by = 'owner@deladetech.com', rate_override_reason = 'agreed', "
        "rate_override_at = now() WHERE id = 's1'",
        "SELECT rate_override::text FROM core_platform.cp_app_subscriptions WHERE id = 's1'",
        "13.5000",
        "a client is put on an agreed rate",
    ),
    (
        "20260923-06-coreplatform-an-agreed-price-for-one-client.sql",
        "UPDATE core_platform.cp_app_subscriptions SET price_override = 280.00, "
        "price_override_by = 'owner@deladetech.com', price_override_reason = 'deal', "
        "price_override_at = now() WHERE id = 's1'",
        "SELECT price_override::text FROM core_platform.cp_app_subscriptions WHERE id = 's1'",
        "280.00",
        "a client is put on an agreed price",
    ),
]

# Only what these migrations ALTER, kept to the columns they name.
FIXTURE = """
CREATE SCHEMA IF NOT EXISTS core_platform;
CREATE TABLE IF NOT EXISTS core_platform.cp_tenants (
    id text PRIMARY KEY, tenant_name text, is_verified boolean DEFAULT true,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED');
CREATE TABLE IF NOT EXISTS core_platform.cp_app_subscriptions (
    id text PRIMARY KEY, tenant_id text, app_id text,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED');
INSERT INTO core_platform.cp_tenants (id, tenant_name) VALUES ('t1','A Real Client')
    ON CONFLICT DO NOTHING;
INSERT INTO core_platform.cp_app_subscriptions (id, tenant_id, app_id)
    VALUES ('s1','t1','app-msg') ON CONFLICT DO NOTHING;
"""

FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f": {detail}" if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def main():
    for tool in ("initdb", "pg_ctl", "psql"):
        if not shutil.which(tool):
            sys.exit(f"{tool} is not on PATH; install postgresql")

    d = tempfile.mkdtemp(prefix="/tmp/pgsurv")
    data = os.path.join(d, "data")
    try:
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
                       check=True, capture_output=True)
        subprocess.run(["pg_ctl", "-D", data, "-l", os.path.join(d, "pg.log"), "-o",
                        f"-p {PORT} -k {d} -c listen_addresses=''", "start"],
                       check=True, capture_output=True)

        def psql(sql=None, f=None):
            cmd = ["psql", "-h", d, "-p", PORT, "-U", "postgres", "-d", "postgres",
                   "-v", "ON_ERROR_STOP=1"]
            cmd += ["-q", "-f", f] if f else ["-tAc", sql]
            return subprocess.run(cmd, capture_output=True, text=True)

        for _ in range(60):
            if psql("SELECT 1").returncode == 0:
                break
            time.sleep(0.5)
        psql(FIXTURE)

        for name, use, verify, expected, story in CASES:
            path = SHARED / name
            if not path.exists():
                check(f"{name} exists", False, "not found")
                continue

            # Deploy 1: the migration arrives.
            r = psql(f=str(path))
            check(f"{name} applies to a fresh database", r.returncode == 0,
                  (r.stderr or "").strip()[-200:])
            if r.returncode != 0:
                continue

            # ...and then the feature gets used, which is the point of shipping it.
            r = psql(use)
            check(f"...and then {story}", r.returncode == 0,
                  (r.stderr or "").strip()[-200:])

            # Deploy 2: every migration runs again, over a database in use.
            r = psql(f=str(path))
            check(f"...and the NEXT deploy still applies it", r.returncode == 0,
                  (r.stderr or "").strip()[-200:])

            # Deploy 3, because twice can pass by luck.
            r = psql(f=str(path))
            check("...and the one after that", r.returncode == 0,
                  (r.stderr or "").strip()[-200:])

            # And re-running must not have undone what somebody did.
            got = (psql(verify).stdout or "").strip()
            check(f"...without quietly reverting it", got == expected,
                  f"{got!r}, expected {expected!r}")
    finally:
        subprocess.run(["pg_ctl", "-D", data, "-m", "immediate", "stop"],
                       capture_output=True)
        shutil.rmtree(d, ignore_errors=True)

    print(f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed.")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
