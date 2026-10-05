#!/usr/bin/env python3
"""Does the identity backfill give every person exactly one credential?

# WHY THIS EXISTS

Phase 1 of one-login-several-clients is inert by design -- nothing reads
identity_id yet -- which is exactly why it needs testing now. Phase 2 moves
authentication onto cp_identities, and anything this backfill gets wrong becomes
somebody unable to sign in, discovered in production.

Four things have to hold, and three of them are only visible with awkward data:

  1. one identity per PERSON, not per user row -- two rows for one address
     collapse to one identity, or that person ends up with two credentials again
  2. CASE does not make a second person. The login compares LOWER(u.email) while
     the old index was on email, so dev already holds two accounts for one person
     differing by a capital letter -- with different passwords
  3. the identity takes a password that WORKS. The pair above has one row with an
     empty login_password; picking that one hands phase 2 an identity nobody can
     sign in as
  4. it is idempotent. Every migration re-runs on every deploy, so a second pass
     must not create a second identity or relink anything

Run (needs initdb/pg_ctl/psql on PATH):

    python3 scripts/test_identity_backfill.py
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
MIGRATION = HERE.parent / "migrations" / "shared" / "20261005-06-a-person-is-not-a-user-row.sql"

# cp_users reduced to the columns the backfill reads. The shape is dev's, read off
# information_schema rather than guessed -- this fixture has drifted from the real
# table before.
FIXTURE = """
CREATE SCHEMA IF NOT EXISTS core_platform;
CREATE TABLE core_platform.cp_users (
    id             text NOT NULL,
    tenant_id      text NOT NULL,
    email          text,
    contact        text,
    fullname       text,
    login_password text,
    can_login      boolean NOT NULL DEFAULT true,
    is_active      boolean NOT NULL DEFAULT true,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED',
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, tenant_id)
);

INSERT INTO core_platform.cp_users
    (id, tenant_id, email, contact, login_password, cdatetime) VALUES
 -- an ordinary person, one tenant
 ('u_amina','tnt_a','amina@example.com','+233200000001','hash-amina', now() - interval '10 days'),
 -- THE CASE PAIR, one tenant, different passwords, the newer one BLANK.
 -- Ordered by cdatetime alone the blank would win; the backfill must prefer the
 -- row that has a password.
 ('u_kofi_old','tnt_a','Kofi@example.com','+233200000002','hash-kofi', now() - interval '20 days'),
 ('u_kofi_new','tnt_a','kofi@example.com','+233200000003','',         now() - interval '2 days'),
 -- the same person engaged by a SECOND tenant: the case this whole feature is for
 ('u_yaa_a','tnt_a','yaa@example.com','+233200000004','hash-yaa', now() - interval '30 days'),
 ('u_yaa_b','tnt_b','yaa@example.com','+233200000005','hash-yaa', now() - interval '5 days'),
 -- no password at all, which is a real state today
 ('u_nana','tnt_b','nana@example.com','+233200000006', NULL, now() - interval '1 day'),
 -- deleted: must not get an identity, and must not hold the address
 ('u_gone','tnt_b','gone@example.com','+233200000007','hash-gone', now() - interval '40 days'),
 -- no email: skipped entirely rather than making a blank identity
 ('u_noemail','tnt_b', NULL, '+233200000008','hash-x', now());
UPDATE core_platform.cp_users SET delete_status = 'DELETED' WHERE id = 'u_gone';
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
        self.tmp = tempfile.mkdtemp(prefix="/tmp/pgid")
        data = os.path.join(self.tmp, "data")
        subprocess.run(["initdb", "-D", data, "-U", "postgres", "--auth=trust"],
                       check=True, capture_output=True)
        subprocess.run(
            ["pg_ctl", "-D", data, "-l", os.path.join(self.tmp, "pg.log"), "-o",
             f"-p 5476 -k {self.tmp} -c listen_addresses=''", "start"],
            check=True, capture_output=True)
        for _ in range(60):
            if self.run("SELECT 1").returncode == 0:
                break
            time.sleep(0.5)

    def stop(self):
        if self.tmp:
            subprocess.run(["pg_ctl", "-D", os.path.join(self.tmp, "data"),
                            "-m", "immediate", "stop"], capture_output=True)
            shutil.rmtree(self.tmp, ignore_errors=True)

    def run(self, sql, db="postgres", file=False):
        # ON_ERROR_STOP for a file, or psql carries on past a failed statement and
        # exits 0 -- a half-applied migration then reports success here.
        args = ["psql", "-h", self.tmp, "-p", "5476", "-U", "postgres", "-d", db] + (
            ["-v", "ON_ERROR_STOP=1", "-f", sql] if file else ["-tAc", sql])
        return subprocess.run(args, capture_output=True, text=True)

    def value(self, sql, db="ident"):
        r = self.run(sql, db)
        out = (r.stdout or "").strip() or (r.stderr or "").strip()
        return out.splitlines()[0] if out else ""


def main():
    pg = Postgres()
    pg.start()
    try:
        pg.run("DROP DATABASE IF EXISTS ident")
        pg.run("CREATE DATABASE ident")
        with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fh:
            fh.write(FIXTURE)
            fixture = fh.name
        r = pg.run(fixture, db="ident", file=True)
        if r.returncode != 0:
            sys.exit("fixture failed: " + (r.stderr or "")[:400])
        os.unlink(fixture)

        r = pg.run(str(MIGRATION), db="ident", file=True)
        check("the migration applies to a fresh database", r.returncode == 0,
              next((l for l in (r.stderr or "").splitlines() if "ERROR" in l), "")[:200])

        # ------------------------------------------------- one identity per person
        # FOUR live addresses from eight user rows: amina, kofi (the case pair, two
        # rows), yaa (two tenants, two rows), nana. The deleted row and the one with
        # no email get none.
        check("one identity per person, not per user row",
              pg.value("SELECT count(*) FROM core_platform.cp_identities "
                       "WHERE delete_status='NOT_DELETED'") == "4",
              pg.value("SELECT string_agg(email, ', ' ORDER BY email) "
                       "FROM core_platform.cp_identities"))

        # ------------------------------------------------- case is not a second person
        check("two rows differing only by case share ONE identity",
              pg.value("SELECT count(DISTINCT identity_id) FROM core_platform.cp_users "
                       "WHERE id IN ('u_kofi_old','u_kofi_new')") == "1")

        # ...and it took the password that WORKS, not the newer blank one.
        check("...and the identity took the password that works, not the blank newer one",
              pg.value("SELECT i.login_password FROM core_platform.cp_identities i "
                       "JOIN core_platform.cp_users u ON u.identity_id = i.id "
                       "WHERE u.id='u_kofi_old'") == "hash-kofi")

        # ------------------------------------------- the case the feature is for
        check("one person in two tenants is one identity, two user rows",
              pg.value("SELECT count(DISTINCT identity_id)||'/'||count(*) "
                       "FROM core_platform.cp_users WHERE id IN ('u_yaa_a','u_yaa_b')") == "1/2")

        # ------------------------------------------------------------- the edges
        check("a deleted user gets no identity and does not hold the address",
              pg.value("SELECT count(*) FROM core_platform.cp_identities "
                       "WHERE lower(email)='gone@example.com'") == "0")
        check("a user with no email is skipped rather than given a blank identity",
              pg.value("SELECT COALESCE(identity_id,'(null)') FROM core_platform.cp_users "
                       "WHERE id='u_noemail'") == "(null)")
        check("a user with no password still gets an identity, with none",
              pg.value("SELECT COALESCE(i.login_password,'(null)') "
                       "FROM core_platform.cp_identities i "
                       "JOIN core_platform.cp_users u ON u.identity_id=i.id "
                       "WHERE u.id='u_nana'") == "(null)")
        check("every live user with an email is linked",
              pg.value("SELECT count(*) FROM core_platform.cp_users "
                       "WHERE delete_status='NOT_DELETED' AND email IS NOT NULL "
                       "AND identity_id IS NULL") == "0")

        # ------------------------------------------------------------ idempotency
        before = pg.value("SELECT count(*)||':'||COALESCE(string_agg(id,',' ORDER BY id),'') "
                          "FROM core_platform.cp_identities")
        r = pg.run(str(MIGRATION), db="ident", file=True)
        check("a second pass applies (every migration re-runs every deploy)",
              r.returncode == 0,
              next((l for l in (r.stderr or "").splitlines() if "ERROR" in l), "")[:200])
        after = pg.value("SELECT count(*)||':'||COALESCE(string_agg(id,',' ORDER BY id),'') "
                         "FROM core_platform.cp_identities")
        check("...and creates no second identity for anybody", before == after,
              f"{before} -> {after}")

        # --------------------------------------------- a new user joins afterwards
        pg.run("INSERT INTO core_platform.cp_users (id,tenant_id,email,contact,login_password) "
               "VALUES ('u_late','tnt_b','late@example.com','+233200000009','hash-late')",
               db="ident")
        r = pg.run(str(MIGRATION), db="ident", file=True)
        check("a user added later gets an identity on the next deploy",
              r.returncode == 0 and pg.value(
                  "SELECT CASE WHEN identity_id IS NULL THEN 'no' ELSE 'yes' END "
                  "FROM core_platform.cp_users WHERE id='u_late'") == "yes")

        # ------------------------------------------------- the uniqueness it rests on
        out = pg.value("INSERT INTO core_platform.cp_identities (email) "
                       "VALUES ('AMINA@example.com')")
        check("a second identity for the same address, in any case, is refused",
              "duplicate key" in out.lower(), out)
    finally:
        pg.stop()

    print(f"\n{len(FAILS)} FAILED: {'; '.join(FAILS)}" if FAILS else "\nAll checks passed.")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
