#!/usr/bin/env python3
"""The Deladetech console on a login of its own (20261023-20, CONSOLE-GAPS gap 1).

# WHY THIS EXISTS

The console's staff accounts and sessions were granted to the pooled app group, so
every application's database login could mint a console OWNER session. The fix gives
the console its own login (deladetech_<env>, created by tvs-iac) and grants it exactly
what it uses. A grant is only visible from the role that has to use it, so this test
connects AS each role, never as the migrator or a superuser.

# WHAT IS ASSERTED

  * 20261023-20 applies, as a non-superuser migrator, in a database named like the
    pool (dev-db, so this_database_unit() says 'pooled'), and again -- migrations
    re-run every deploy;
  * BEFORE the login exists it grants nothing and does not fail (it lands before the
    IaC apply);
  * once deladetech_dev exists, the next run grants it what the console does: sign in
    (operators, sessions), setups, the clear audit, the price list, a lock, charges,
    the route reference data, the route functions;
  * it is never given DELETE on the clear audit or on operators, nor the ledger by way
    of the derived control_plane read loop;
  * control_plane.purge_tenant(): only the console login may run it; it deletes a
    tenant's rows across schemas in foreign-key order, fires the DELETE triggers and the
    deferred constraint triggers AS THE OWNER (the console holds none of what they
    write), refuses the platform tenant, and keeps the console's own records;
  * an application login is NOT changed by this file (the revoke is a later, separate
    step), so landing it changes nothing for the apps.

Run (needs initdb/pg_ctl/psql on PATH):

    python3 scripts/test_console_own_login.py
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
MIG = HERE.parent / "migrations"
SAAS = MIG / "saas"
PORT = "5491"
DB = "dev-db"

CONSOLE_FILES = [
    SAAS / "20261003-01-deladetech-hosting-requests.sql",
    SAAS / "20261003-02-hosting-requests-say-which-country.sql",
    SAAS / "20261003-03-no-basic-hosting-requests.sql",
    SAAS / "20261003-04-deladetech-console.sql",
    SAAS / "20261003-06-record-every-client-clear.sql",
    SAAS / "20261004-04-the-console-gains-an-admin-role.sql",
    SAAS / "20261005-05-the-clear-may-delete-the-setup-record.sql",
    SAAS / "20261023-20-the-console-has-its-own-login.sql",
]
# Files a later step adds (the held revoke). Applied when present, so the same test
# covers both states of the branch.
LATER_FILES = [
    SAAS / "20261023-21-the-app-group-loses-the-console-tables.sql",
]

HELPERS = re.compile(r"-- >>> tenancy role helpers.*?-- <<< tenancy role helpers", re.S)

# Roles as the pool has them, and the shapes the console's statements need. Everything
# is created by postgres and handed to the migrator, which is what owns it on dev.
FIXTURE = """
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $r$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='migrator') THEN
     CREATE ROLE migrator LOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tvs_app_dev')
     THEN CREATE ROLE tvs_app_dev NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coreplatform_dev')
     THEN CREATE ROLE coreplatform_dev LOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='mystoreguard_dev')
     THEN CREATE ROLE mystoreguard_dev LOGIN; END IF;
END $r$;
GRANT tvs_app_dev TO coreplatform_dev, mystoreguard_dev;
GRANT ALL ON DATABASE "dev-db" TO migrator;
REVOKE CONNECT, TEMPORARY ON DATABASE "dev-db" FROM PUBLIC;
GRANT CONNECT ON DATABASE "dev-db" TO coreplatform_dev, mystoreguard_dev;

CREATE SCHEMA core_platform AUTHORIZATION migrator;
CREATE SCHEMA control_plane AUTHORIZATION migrator;
CREATE SCHEMA deladetech AUTHORIZATION migrator;
CREATE SCHEMA mystoreguard AUTHORIZATION migrator;
SET ROLE migrator;

-- What db-app-group (tvs-iac) gives the group: USAGE and DML on the app schemas, and
-- the same on the migrator's future tables. deladetech's base set is what
-- common.hcl app_group_restricted_schemas says today.
GRANT USAGE ON SCHEMA core_platform, mystoreguard, deladetech, control_plane TO tvs_app_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA core_platform
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tvs_app_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA mystoreguard
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tvs_app_dev;
-- 20261001-01: every control_plane table readable by the app group by default.
ALTER DEFAULT PRIVILEGES IN SCHEMA control_plane GRANT SELECT ON TABLES TO tvs_app_dev;

CREATE TABLE control_plane.ctl_tenant_routes (
    host text PRIMARY KEY, tenant_id text, tier text, db_name text, silo_key text);
CREATE TABLE control_plane.ctl_cells (cell_key text PRIMARY KEY);
CREATE TABLE control_plane.ctl_reserved_labels (label text PRIMARY KEY, reason text);
CREATE TABLE control_plane.ctl_platform_domains (domain text PRIMARY KEY);
-- The ledger: revoked from the groups by 20261004-01, so the derived read loop must
-- never hand it to the console by that route.
CREATE TABLE control_plane.ctl_billing_facts (id text PRIMARY KEY);
REVOKE ALL ON control_plane.ctl_billing_facts FROM tvs_app_dev;
CREATE FUNCTION control_plane.label_for_name(p text) RETURNS text
  LANGUAGE sql AS $f$ SELECT lower(p) $f$;
CREATE FUNCTION control_plane.move_tenant_host(a text, b text, c text, d text)
  RETURNS text LANGUAGE sql AS $f$ SELECT a $f$;
CREATE FUNCTION control_plane.reconcile_route_tenant(a text, b text, c text, d text)
  RETURNS text LANGUAGE sql AS $f$ SELECT a $f$;
CREATE FUNCTION control_plane.release_tenant_host(a text, b text, c text DEFAULT NULL)
  RETURNS text LANGUAGE sql AS $f$ SELECT a $f$;
CREATE FUNCTION control_plane.tenant_host_refusal(a text, b text)
  RETURNS text LANGUAGE sql AS $f$ SELECT NULL::text $f$;
REVOKE ALL ON FUNCTION control_plane.label_for_name(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.move_tenant_host(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION control_plane.reconcile_route_tenant(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION control_plane.label_for_name(text),
  control_plane.move_tenant_host(text, text, text, text),
  control_plane.reconcile_route_tenant(text, text, text, text) TO tvs_app_dev;

CREATE TABLE core_platform.cp_app_schemas (schema_name text PRIMARY KEY);
CREATE TABLE core_platform.cp_tenants (
    id text PRIMARY KEY, tenant_name text, is_locked boolean DEFAULT false);
CREATE TABLE core_platform.cp_user_sessions (
    id text PRIMARY KEY, tenant_id text REFERENCES core_platform.cp_tenants(id),
    revoked_at timestamptz);
CREATE TABLE core_platform.cp_app_subscriptions (
    id text PRIMARY KEY, tenant_id text REFERENCES core_platform.cp_tenants(id),
    price_override numeric);
CREATE TABLE core_platform.cp_app_tier_configs (id text PRIMARY KEY, price numeric);
CREATE TABLE core_platform.cp_platform_charges (
    id text PRIMARY KEY, tenant_id text REFERENCES core_platform.cp_tenants(id),
    name text);
CREATE TABLE core_platform.cp_apps (id text PRIMARY KEY);
CREATE TABLE core_platform.cp_users (
    id text PRIMARY KEY, tenant_id text REFERENCES core_platform.cp_tenants(id));
CREATE TABLE core_platform.cp_events (id bigserial PRIMARY KEY, tenant_id text, kind text);
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_platform TO tvs_app_dev;

-- An app's tables: a parent/child pair the purge must order, a DELETE trigger that
-- writes elsewhere, and a deferred constraint trigger that publishes an event -- the
-- shapes the accounting events and the stock invariant have on dev.
CREATE TABLE mystoreguard.msg_sales (
    id text PRIMARY KEY, tenant_id text REFERENCES core_platform.cp_tenants(id));
CREATE TABLE mystoreguard.msg_sales_items (
    id text PRIMARY KEY, tenant_id text, sale_id text REFERENCES mystoreguard.msg_sales(id));
CREATE TABLE mystoreguard.msg_acc_state (id text PRIMARY KEY, tenant_id text, gone boolean);
CREATE FUNCTION mystoreguard.msg_sale_gone() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO mystoreguard.msg_acc_state (id, tenant_id, gone)
  VALUES ('gone_' || OLD.id, OLD.tenant_id, true) ON CONFLICT (id) DO NOTHING;
  RETURN OLD;
END $f$;
CREATE TRIGGER msg_sale_gone AFTER DELETE ON mystoreguard.msg_sales
  FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_sale_gone();
CREATE FUNCTION mystoreguard.msg_publish() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO core_platform.cp_events (tenant_id, kind) VALUES (OLD.tenant_id, 'msg.item.deleted');
  RETURN NULL;
END $f$;
CREATE CONSTRAINT TRIGGER msg_publish AFTER DELETE ON mystoreguard.msg_sales_items
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_publish();
RESET ROLE;
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
        self.tmp = tempfile.mkdtemp(prefix="/tmp/pgol")   # short: socket path limit
        data = os.path.join(self.tmp, "data")
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
                       check=True, capture_output=True)
        subprocess.run(
            ["pg_ctl", "-D", data, "-l", os.path.join(self.tmp, "pg.log"), "-o",
             f"-p {PORT} -k {self.tmp} -c listen_addresses=''", "start"],
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

    def run(self, user, sql, db=DB, file=False):
        args = ["psql", "-h", self.tmp, "-p", PORT, "-U", user, "-d", db,
                "-v", "ON_ERROR_STOP=1"] + (["-f", sql] if file else ["-tAc", sql])
        return subprocess.run(args, capture_output=True, text=True)

    def value(self, user, sql, db=DB):
        r = self.run(user, sql, db)
        out = (r.stdout or "").strip() or (r.stderr or "").strip()
        return out.splitlines()[0] if out else ""

    def ok(self, user, sql):
        """True when the statement ran as `user` without an error."""
        return self.run(user, sql).returncode == 0

    def denied(self, user, sql):
        r = self.run(user, sql)
        return r.returncode != 0 and "permission denied" in (r.stderr or "").lower()


def apply(pg, files, label):
    for m in files:
        r = pg.run("migrator", str(m), file=True)
        if r.returncode != 0:
            err = next((l for l in (r.stderr or "").splitlines() if "ERROR" in l),
                       (r.stderr or "")[:300])
            check(f"{label}: {m.name} applies as the migrator", False, err)
            return r
    check(f"{label}: the console files apply as the migrator", True)
    return r


def main():
    files = CONSOLE_FILES + [f for f in LATER_FILES if f.exists()]
    for f in files:
        if not f.exists():
            sys.exit(f"missing migration: {f.name}")
    later = [f for f in LATER_FILES if f.exists()]

    pg = Postgres()
    pg.start()
    try:
        pg.run("postgres", f'CREATE DATABASE "{DB}"', db="postgres")
        helpers = HELPERS.search((MIG / "shared" / "20261001-01-control-plane-host-routing.sql")
                                 .read_text()).group(0)
        with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fh:
            fh.write(FIXTURE + "\nSET ROLE migrator;\n" + helpers + "\nRESET ROLE;\n")
            fixture = fh.name
        r = pg.run("postgres", fixture, file=True)
        os.unlink(fixture)
        if r.returncode != 0:
            sys.exit("fixture failed: " + (r.stderr or "")[:600])
        check("the fixture is the pool (this_database_unit = pooled)",
              pg.value("migrator", "SELECT (control_plane.this_database_unit()).unit") == "pooled")

        # ---------------------------------------------- before the login exists
        r = apply(pg, files, "no console login yet")
        check("with no login, 20261023-20 says so instead of failing",
              "no deladetech_<env> login" in (r.stderr or "") + (r.stdout or "")
              or r.returncode == 0)
        check("nobody but the owner may run purge_tenant -- not the app group",
              pg.value("postgres", "SELECT has_function_privilege('mystoreguard_dev',"
                       "'control_plane.purge_tenant(text)','EXECUTE')") == "f")

        # What dev and prod hold TODAY, from the old shape of the console files and
        # tvs-iac's db-app-group: the group on every console table. The revoke has to
        # take this away, not merely not add it.
        legacy = pg.run("migrator", """
            GRANT SELECT, INSERT, UPDATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA deladetech TO tvs_app_dev;
            GRANT DELETE, TRUNCATE ON deladetech.dlt_operator_sessions, deladetech.dlt_client_setups TO tvs_app_dev;
            GRANT SELECT (id) ON deladetech.dlt_operators TO tvs_app_dev;
            ALTER DEFAULT PRIVILEGES IN SCHEMA deladetech
              GRANT SELECT, INSERT, UPDATE, REFERENCES, TRIGGER ON TABLES TO tvs_app_dev;""")
        check("the legacy grants are in place to be taken away", legacy.returncode == 0,
              (legacy.stderr or "")[:200])
        check("...so an app login can mint a console session today",
              pg.value("postgres", "SELECT has_table_privilege('mystoreguard_dev',"
                       "'deladetech.dlt_operator_sessions','INSERT')") == "t")

        # -------------------------------- tvs-iac creates the login; next deploy
        pg.run("postgres", "CREATE ROLE deladetech_dev LOGIN; "
                           'GRANT CONNECT, CREATE, TEMPORARY ON DATABASE "dev-db" TO deladetech_dev')
        apply(pg, files, "with the login")
        apply(pg, files, "re-run")   # every deploy runs every file

        # Rows to act on, written by the owner.
        seed = pg.run("migrator", """
            INSERT INTO core_platform.cp_tenants (id, tenant_name) VALUES
              ('system-tenant-id','Platform'), ('tnt_gone','Gone Ltd'), ('tnt_keep','Keep Ltd');
            INSERT INTO core_platform.cp_users VALUES ('u1','tnt_gone'), ('u2','tnt_keep');
            INSERT INTO core_platform.cp_user_sessions VALUES ('s1','tnt_gone',NULL);
            INSERT INTO core_platform.cp_app_subscriptions VALUES ('a1','tnt_gone',NULL);
            INSERT INTO core_platform.cp_app_tier_configs VALUES ('t1', 10);
            INSERT INTO mystoreguard.msg_sales VALUES ('sale1','tnt_gone'), ('sale2','tnt_keep');
            INSERT INTO mystoreguard.msg_sales_items VALUES ('it1','tnt_gone','sale1'),
                                                            ('it2','tnt_keep','sale2');
            INSERT INTO deladetech.dlt_operators
              (id, email, fullname, role, password_hash, must_change_password)
              VALUES ('opr_1','o@example.invalid','O','OWNER','x',false);
        """)
        check("seed rows", seed.returncode == 0, (seed.stderr or "")[:300])

        C = "deladetech_dev"
        # ---------------------------------------------- what the console does
        cases = [
            ("sign in: read an operator", "SELECT count(*) FROM deladetech.dlt_operators"),
            ("sign in: start a session",
             "INSERT INTO deladetech.dlt_operator_sessions (token_hash, operator_id, expires_at) "
             "VALUES ('h1','opr_1', now() + interval '1 hour')"),
            ("sign out", "UPDATE deladetech.dlt_operator_sessions SET revoked_at = now() "
                         "WHERE token_hash = 'h1'"),
            ("expired sessions are deleted",
             "DELETE FROM deladetech.dlt_operator_sessions WHERE token_hash = 'h1'"),
            ("an operator changes their password",
             "UPDATE deladetech.dlt_operators SET must_change_password = false WHERE id = 'opr_1'"),
            ("a setup is recorded",
             "INSERT INTO deladetech.dlt_client_setups (hosting_kind, host, company_name, "
             "owner_email, status) VALUES ('SILO_SHARED','c.example.invalid','C','c@x.invalid','STARTED')"),
            ("a clear frees the host", "DELETE FROM deladetech.dlt_client_setups "
                                       "WHERE host = 'c.example.invalid'"),
            ("a clear is recorded",
             "INSERT INTO deladetech.dlt_client_clears (id, tenant_id, host, hosting_kind, "
             "status, performed_by) VALUES ('clr_1','tnt_gone','shared','POOLED','STARTED','o@x')"),
            ("a request changes status", "UPDATE deladetech.dlt_hosting_requests SET status = status"),
            ("a client is locked", "UPDATE core_platform.cp_tenants SET is_locked = true "
                                   "WHERE id = 'tnt_keep'"),
            ("...and their sessions revoked", "UPDATE core_platform.cp_user_sessions "
                                              "SET revoked_at = now() WHERE tenant_id = 'tnt_keep'"),
            ("an agreed price", "UPDATE core_platform.cp_app_subscriptions SET price_override = 5 "
                                "WHERE id = 'a1'"),
            ("the price list", "UPDATE core_platform.cp_app_tier_configs SET price = 11 WHERE id = 't1'"),
            ("a charge is added", "INSERT INTO core_platform.cp_platform_charges VALUES "
                                  "('pch_1','tnt_keep','Backups')"),
            ("route reference data", "SELECT count(*) FROM control_plane.ctl_reserved_labels, "
                                     "control_plane.ctl_platform_domains, control_plane.ctl_cells, "
                                     "control_plane.ctl_tenant_routes"),
            ("a route function", "SELECT control_plane.label_for_name('Acme')"),
            ("users are listed", "SELECT count(*) FROM core_platform.cp_users"),
        ]
        for label, sql in cases:
            r = pg.run(C, sql)
            check(f"console may: {label}", r.returncode == 0, (r.stderr or "").strip()[:200])

        # ---------------------------------------------- what it must not
        check("console may NOT delete the clear audit",
              pg.denied(C, "DELETE FROM deladetech.dlt_client_clears"))
        check("console may NOT delete an operator",
              pg.denied(C, "DELETE FROM deladetech.dlt_operators"))
        check("console may NOT read the ledger through the derived control_plane loop",
              pg.denied(C, "SELECT 1 FROM control_plane.ctl_billing_facts"))
        check("console may NOT delete tenant data directly",
              pg.denied(C, "DELETE FROM mystoreguard.msg_sales_items WHERE tenant_id = 'tnt_gone'"))
        check("console may NOT write app data",
              pg.denied(C, "INSERT INTO mystoreguard.msg_sales VALUES ('x','tnt_keep')"))
        check("console is not a member of the app group",
              pg.value("postgres", "SELECT pg_has_role('deladetech_dev','tvs_app_dev','MEMBER')") == "f")

        # ---------------------------------------------- the purge
        check("the purge refuses the platform's own tenant",
              not pg.ok(C, "SELECT * FROM control_plane.purge_tenant('system-tenant-id')"))
        check("an app login may NOT run the purge",
              pg.denied("mystoreguard_dev", "SELECT * FROM control_plane.purge_tenant('tnt_gone')"))
        # The file's own guard: an app role that somehow holds EXECUTE fails the deploy
        # loudly. Broken on purpose, then put back.
        pg.run("migrator", "GRANT EXECUTE ON FUNCTION control_plane.purge_tenant(text) TO tvs_app_dev")
        r = pg.run("migrator", str(SAAS / "20261023-20-the-console-has-its-own-login.sql"), file=True)
        check("20261023-20 refuses to pass while an app role may run the purge",
              r.returncode != 0 and "may execute control_plane.purge_tenant" in (r.stderr or ""),
              (r.stderr or "")[-200:])
        pg.run("migrator", "REVOKE EXECUTE ON FUNCTION control_plane.purge_tenant(text) FROM tvs_app_dev")
        # The deferred triggers must fire INSIDE the function, as its owner. PostgreSQL
        # 18 runs a deferred trigger as the role that queued it, but Azure runs 17,
        # where it fires at COMMIT as the CALLER -- who cannot write what it writes.
        # So prove it fired before the function returned (visible before commit),
        # which is version-independent, rather than relying on the commit succeeding.
        with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fh:
            fh.write("BEGIN;\nSET LOCAL ROLE deladetech_dev;\n"
                     "SELECT count(*) FROM control_plane.purge_tenant('tnt_gone');\n"
                     "RESET ROLE;\n"
                     "SELECT 'events=' || count(*) FROM core_platform.cp_events "
                     "WHERE tenant_id = 'tnt_gone';\nROLLBACK;\n")
            probe = fh.name
        r = pg.run("postgres", probe, file=True)
        os.unlink(probe)
        check("...the deferred triggers fire inside the purge, before it returns",
              "events=1" in (r.stdout or ""), (r.stdout or "") + (r.stderr or ""))
        out = pg.value(C, "SELECT purged_name || '|' || purged_rows "
                          "FROM control_plane.purge_tenant('tnt_gone')")
        check("the console purges a pooled tenant through the function",
              out.startswith("Gone Ltd|"), out)
        left = pg.value("migrator", """
            SELECT (SELECT count(*) FROM core_platform.cp_tenants WHERE id='tnt_gone')
                 + (SELECT count(*) FROM core_platform.cp_users WHERE tenant_id='tnt_gone')
                 + (SELECT count(*) FROM core_platform.cp_user_sessions WHERE tenant_id='tnt_gone')
                 + (SELECT count(*) FROM mystoreguard.msg_sales WHERE tenant_id='tnt_gone')
                 + (SELECT count(*) FROM mystoreguard.msg_sales_items WHERE tenant_id='tnt_gone')""")
        check("...every row of it is gone, children before parents", left == "0", left)
        check("...the DELETE trigger ran as the owner (wrote where the console cannot)",
              pg.value("migrator", "SELECT count(*) FROM mystoreguard.msg_acc_state "
                                   "WHERE id = 'gone_sale1'") == "1")
        check("...the deferred event trigger fired inside the purge",
              pg.value("migrator", "SELECT count(*) FROM core_platform.cp_events "
                                   "WHERE kind = 'msg.item.deleted' AND tenant_id='tnt_gone'") == "1")
        keep = pg.value("migrator", """
            SELECT (SELECT count(*) FROM core_platform.cp_tenants WHERE id='tnt_keep')
                 + (SELECT count(*) FROM mystoreguard.msg_sales_items WHERE tenant_id='tnt_keep')""")
        check("...another tenant is untouched", keep == "2", keep)
        check("...the clear's own audit row survives it",
              pg.value("migrator", "SELECT count(*) FROM deladetech.dlt_client_clears "
                                   "WHERE id='clr_1'") == "1")

        # ---------------------------------------------- the apps
        A = "mystoreguard_dev"
        check("core-platform may still record a hosting request (its signup page)",
              pg.ok("coreplatform_dev",
                    "INSERT INTO deladetech.dlt_hosting_requests (id, hosting_kind, requested_tier, "
                    "fullname, email, contact, company_name) VALUES ('hrq_1','SILO_SHARED',"
                    "'PREMIUM','F','f@x.invalid','+233','F Ltd')"))
        check("...and read it back", pg.ok("coreplatform_dev",
              "SELECT * FROM deladetech.dlt_hosting_requests WHERE id = 'hrq_1'"))
        if later:
            # The held revoke (20261023-21) is on this branch: the apps lose the console.
            for label, sql in [
                ("read operators", "SELECT * FROM deladetech.dlt_operators"),
                ("make an operator OWNER", "UPDATE deladetech.dlt_operators SET role = 'OWNER'"),
                ("mint a session", "INSERT INTO deladetech.dlt_operator_sessions (token_hash, "
                                   "operator_id, expires_at) VALUES ('evil','opr_1', now() + interval '1 day')"),
                ("read sessions", "SELECT * FROM deladetech.dlt_operator_sessions"),
                ("read setups", "SELECT * FROM deladetech.dlt_client_setups"),
                ("read the clear audit", "SELECT * FROM deladetech.dlt_client_clears"),
                ("change a request's status", "UPDATE deladetech.dlt_hosting_requests SET status = status"),
            ]:
                check(f"an app login may NOT {label}", pg.denied(A, sql))
                check(f"core-platform's login may NOT {label}", pg.denied("coreplatform_dev", sql))
            # A table added to deladetech later must not reach the apps by default.
            pg.run("migrator", "CREATE TABLE deladetech.dlt_probe_new (id text)")
            apply(pg, files, "after a new console table")
            check("a NEW console table is not left to the app group",
                  pg.denied(A, "SELECT * FROM deladetech.dlt_probe_new"))
        else:
            # This file alone changes nothing for the apps -- the revoke is a later step.
            check("until the revoke lands, the apps keep what they had (unchanged)",
                  pg.ok(A, "SELECT count(*) FROM deladetech.dlt_operators"))
    finally:
        pg.stop()

    print(f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed.")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
