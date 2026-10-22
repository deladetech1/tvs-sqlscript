#!/usr/bin/env python3
"""Guard against granting to roles by NAME PATTERN (silo-cross-tenant-pattern-grants).

PostgreSQL roles are per server, and one server holds several of our databases, so a
migration that grants to "every role matching ^mystoreguard" hands every silo's role a
privilege inside every other database on that server. Grants must go through
control_plane.app_groups_here() / app_logins_here() (20261001-01), which derive the
roles from current_database().

Checks, no database needed:
  1. no migration loops over pg_roles by a name pattern and GRANTs in that loop
     (REVOKE-only loops are fine: taking a privilege from every group is safe);
  2. scripts/isolation_report.sql carries the same helper block as 20261001-01.

Run: python3 scripts/test_role_isolation.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIG = ROOT / "migrations"

# One exception: migrations/saas/ (runs only in the POOL) grants the console's pooled
# login by the pooled-only shape ^(coreplatform|deladetech)_[a-z0-9]+$ -- no underscore
# after the app, so no silo login can match, and in the pool that is exactly
# app_logins_here('coreplatform'). Those loops are left alone; nothing else may join.
POOLED_CONSOLE = "(coreplatform|deladetech)_[a-z0-9]+$"

LOOP = re.compile(r"FOR\s+\w+\s+IN\s+(?P<query>.*?)\bLOOP\b(?P<body>.*?)\bEND\s+LOOP", re.S | re.I)
PATTERN_QUERY = re.compile(r"pg_roles.*?rolname\s*(~|LIKE|SIMILAR)", re.S | re.I)
GRANTS = re.compile(r"'\s*(GRANT\s|ALTER DEFAULT PRIVILEGES[^']*GRANT)", re.I)


def pattern_grant_loops(text: str, pooled_class: bool):
    for m in LOOP.finditer(text):
        if pooled_class and POOLED_CONSOLE in m.group("query"):
            continue
        if PATTERN_QUERY.search(m.group("query")) and GRANTS.search(m.group("body")):
            yield text[: m.start()].count("\n") + 1


def main() -> int:
    bad = []
    for f in sorted(MIG.rglob("*.sql")):
        for line in pattern_grant_loops(f.read_text(), f.parent.name == "saas"):
            bad.append(f"{f.relative_to(ROOT)}:{line}")
    if bad:
        print("GRANT inside a loop over pg_roles by name pattern -- use "
              "control_plane.app_groups_here() / app_logins_here() instead:")
        print("\n".join("  " + b for b in bad))

    # The report's pg_temp copy must be the migration's block, schema swapped.
    block = re.compile(r"-- >>> tenancy role helpers.*?-- <<< tenancy role helpers", re.S)
    mig = block.search((MIG / "shared" / "20261001-01-control-plane-host-routing.sql").read_text())
    rep = block.search((ROOT / "scripts" / "isolation_report.sql").read_text())
    drift = False
    if not (mig and rep):
        print("helper block markers missing from 20261001-01 or scripts/isolation_report.sql")
        drift = True
    else:
        want = re.sub(r"control_plane\.(this_database_unit|app_groups_here|app_logins_here|role_is_foreign_here)",
                      r"pg_temp.\1", mig.group(0))
        if want != rep.group(0):
            print("scripts/isolation_report.sql's helper block differs from 20261001-01's -- regenerate it")
            drift = True

    if bad or drift:
        return 1
    print("role isolation: no pattern grants; report helpers match the migration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
