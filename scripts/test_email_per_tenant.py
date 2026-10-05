#!/usr/bin/env python3
"""Can a second client grant access to somebody who already has an account?

Run (needs a real postgres server on PATH, not just libpq):

    PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH" \
        python3 scripts/test_email_per_tenant.py

# WHY THIS EXISTS

cp_users.email was UNIQUE across the whole database. A consultant engaged by two
clients therefore could not be given a second account: the second client's
INSERT was refused by the index, and the code doing the insert was already
asking the right question ("does this address exist IN MY TENANT").

shared/20261005-09 scopes that uniqueness to the tenant. Two ways to get it
wrong:

  * too loose -- one client accepts the same address twice, so "already exists"
    stops being reported and a client ends up with two accounts for one person,
    which is the state that makes sign-in ambiguous in the first place;
  * too tight -- the migration appears to work while a second client still
    cannot be given the person, i.e. nothing was actually fixed.

Both directions are driven here, against a fresh database and against a re-run,
because every migration re-runs on every deploy and an index created with IF NOT
EXISTS is exactly the kind of thing that passes once.
"""
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from test_route_migration_order import Cluster  # noqa: E402

MIGRATION = (HERE.parent / "migrations" / "shared"
             / "20261005-09-an-email-names-one-person-per-client.sql")

# The shape off dev, trimmed to what this migration touches. The FK on tenant_id
# is real and is why the probe has to create tenants at all.
FIXTURE = """
CREATE SCHEMA IF NOT EXISTS core_platform;
CREATE TABLE IF NOT EXISTS core_platform.cp_tenants (
    id text PRIMARY KEY,
    tenant_name text,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED');
CREATE TABLE IF NOT EXISTS core_platform.cp_users (
    id text NOT NULL,
    tenant_id text NOT NULL REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    fullname text NOT NULL,
    email text NOT NULL,
    contact text NOT NULL,
    login_password text,
    is_owner boolean DEFAULT false,
    is_active boolean DEFAULT true,
    can_login boolean DEFAULT true,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime timestamptz DEFAULT now(),
    CONSTRAINT pk_cp_users PRIMARY KEY (id, tenant_id));
-- The rule as it stood: one address for the whole database.
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_users_email
    ON core_platform.cp_users (email);
CREATE UNIQUE INDEX IF NOT EXISTS ix_cp_users_contact
    ON core_platform.cp_users (contact);
INSERT INTO core_platform.cp_tenants (id, tenant_name) VALUES
    ('tnt_a', 'Client A'), ('tnt_b', 'Client B')
    ON CONFLICT (id) DO NOTHING;
"""

FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}{(': ' + detail) if detail and not ok else ''}")
    if not ok:
        FAILS.append(label)


def insert_user(c, uid, tenant, email, contact):
    r = c.sql(
        "INSERT INTO core_platform.cp_users "
        "(id, tenant_id, fullname, email, contact) "
        f"VALUES ('{uid}', '{tenant}', 'Someone', '{email}', '{contact}')")
    return r.returncode == 0, (r.stderr or "").strip().splitlines()[:1]


def main():
    c = Cluster()
    c.start()
    try:
        c.sql(FIXTURE)

        # ---------------------------------------------- the world before the change
        ok, _ = insert_user(c, "u_a1", "tnt_a", "consultant@x.test", "+111")
        check("a first client can add somebody", ok)
        ok, _ = insert_user(c, "u_b1", "tnt_b", "consultant@x.test", "+111")
        check("...and a second client could NOT, before this migration", not ok,
              "the fixture is not reproducing the old global index")
        c.sql("DELETE FROM core_platform.cp_users WHERE id LIKE 'u_%'")

        # ------------------------------------------------------------- the migration
        for attempt in (1, 2):
            r = c.sql_file(MIGRATION) if hasattr(c, "sql_file") else None
            if r is None:
                import subprocess
                r = subprocess.run(
                    ["psql", "-h", c.dir, "-p", "5482", "-U", "postgres",
                     "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-f", str(MIGRATION)],
                    capture_output=True, text=True)
            err = next((l for l in (r.stderr or "").splitlines() if "ERROR" in l), "")
            check(f"the migration applies (pass {attempt})", r.returncode == 0, err)
            if r.returncode != 0:
                return 1
            warn = [l for l in (r.stderr or "").splitlines() if "WARNING" in l]
            for w in warn:
                print(f"      {w.strip()}")

        # ------------------------------------------------------------- the whole point
        ok, err = insert_user(c, "u_a1", "tnt_a", "consultant@x.test", "+111")
        check("the first client's account still goes in", ok, str(err))
        ok, err = insert_user(c, "u_b1", "tnt_b", "consultant@x.test", "+111")
        check("A SECOND CLIENT CAN NOW GRANT ACCESS TO THE SAME PERSON", ok, str(err))

        # ...and the per-client rule still holds, which is what user_service reports.
        ok, _ = insert_user(c, "u_a2", "tnt_a", "consultant@x.test", "+222")
        check("one client still cannot add the same email twice", not ok,
              "the email rule is now too loose")
        ok, _ = insert_user(c, "u_a3", "tnt_a", "other@x.test", "+111")
        check("one client still cannot add the same contact twice", not ok,
              "the contact rule is now too loose")

        # A deleted user releases the address -- the old global index did not.
        c.sql("UPDATE core_platform.cp_users SET delete_status='DELETED' WHERE id='u_a1'")
        ok, err = insert_user(c, "u_a4", "tnt_a", "consultant@x.test", "+111")
        check("a deleted user releases their email for their replacement", ok, str(err))

        # Blank contacts must not collide: several rows legitimately have none.
        c.sql("INSERT INTO core_platform.cp_users "
              "(id, tenant_id, fullname, email, contact) VALUES "
              "('u_b2','tnt_b','No Phone One','np1@x.test','')")
        ok, err = insert_user(c, "u_b3", "tnt_b", "np2@x.test", "")
        check("two people with no phone number can coexist", ok, str(err))

        # The old global indexes are really gone, not merely shadowed.
        left = c.value("SELECT coalesce(string_agg(indexname, ', '), '(none)') "
                       "FROM pg_indexes WHERE tablename='cp_users' "
                       "AND indexname IN ('ix_cp_users_email','ix_cp_users_contact')")
        check("the global indexes are dropped", left == "(none)", left)

        # CASE. The index is on the raw column, so a capital letter is a different
        # address -- stated as a test because it is the migration's one compromise
        # and the next person needs to know it is deliberate, not an oversight.
        ok, err = insert_user(c, "u_b4", "tnt_b", "CONSULTANT@x.test", "+333")
        check("case-different addresses are allowed in one client (deliberate)",
              ok, str(err))
    finally:
        c.stop()

    print()
    if FAILS:
        print(f"{len(FAILS)} FAILED: " + "; ".join(FAILS[:6]))
        return 1
    print("every check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
