#!/usr/bin/env python3
"""Record, per permission, whether any endpoint actually checks it.

A permission can exist, be granted to a role, appear on every screen that lists it, and be
checked by nothing. Expense Administrator held all five `expense` permissions while every
expense endpoint checked `settings`, so the role could not manage an expense and nobody could
see why: the catalogue said it should work.

The database cannot know this -- it is a property of the code -- so it is measured here and
written to cp_permissions.is_enforced, which the permissions screen then shows. NULL means
"not audited since the column was added", which is different from false and is shown as such.

    scripts/mark_enforced_permissions.py /path/to/trovesuite            # writes
    scripts/mark_enforced_permissions.py /path/to/trovesuite --dry-run  # reports only

Run it after changing what an endpoint checks. It reads the four app repos out of the given
monorepo root, so it needs them checked out beside each other.
"""
import argparse, os, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from _enforced_permissions import all_enforced


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", help="the monorepo root holding the four app repos")
    ap.add_argument("--dry-run", action="store_true", help="report without writing")
    ap.add_argument("--dsn", default=os.environ.get("DATABASE_URL"))
    args = ap.parse_args()
    if not args.dsn:
        sys.exit("no DSN: pass --dsn or set DATABASE_URL")

    live = all_enforced(args.root)
    if not live:
        # Nothing matched at all means the scan is broken, not that the apps check nothing.
        # Writing that would mark every permission unenforced.
        sys.exit("found no enforced permissions at all -- refusing to write")

    import psycopg2
    with psycopg2.connect(args.dsn) as conn, conn.cursor() as cur:
        cur.execute("""SELECT id, COALESCE(app_prefix, ''), resource_key, action
                         FROM core_platform.cp_permissions
                        WHERE delete_status = 'NOT_DELETED' AND is_active""")
        rows = cur.fetchall()
        enforced = [r[0] for r in rows if (r[1], r[2], r[3]) in live]
        dead = [r for r in rows if (r[1], r[2], r[3]) not in live]

        print(f"catalogue {len(rows)} | enforced {len(enforced)} | checked by nothing {len(dead)}")
        for pid, app, res, act in sorted(dead, key=lambda r: (r[1], r[2], r[3])):
            print(f"   {(app or '(core)'):10} {res}|{act}")

        if args.dry_run:
            return 0
        cur.execute("""UPDATE core_platform.cp_permissions
                          SET is_enforced = (id = ANY(%s))
                        WHERE delete_status = 'NOT_DELETED' AND is_active""",
                    (enforced,))
        conn.commit()
        print(f"\nwrote is_enforced for {len(rows)} permission(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
