#!/usr/bin/env python3
"""A client may not claim a platform name -- and a real name must still get through.

# WHY THIS EXISTS

20261005-08 holds back the words a client may not have as their subdomain. It has
two ways to be wrong and they pull in opposite directions:

  * too narrow -- a client is handed api.trovesuite.com and the platform's API
    stops resolving. Loud, and an outage.
  * too wide -- a company genuinely called Appleseed or Nsano is told their name
    is unavailable, with no explanation anyone at the company can act on. Quiet,
    and it lands on the person paying.

The second is the one a migration's own checks are least likely to catch, because
nobody writes a check for a name they did not think of. So this test drives the
comparison with the REAL host list off dev and with ordinary company names that
happen to begin with a reserved word.

It also proves the trigger's WHEN clause. Every one of the platform's own hosts
is a reserved name: api.dev.trovesuite.com, www.trovesuite.com,
zeloshr-admin.trovesuite.com. A trigger without "WHEN (NEW.route_kind =
'TENANT')" would refuse the migrations that create them -- not on the deploy that
adds the trigger, but on the next one, which is the failure mode
test_route_migration_order.py was written for.

Run (needs a real postgres server on PATH, not just libpq):

    PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH" \
        python3 scripts/test_reserved_labels.py
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from test_route_migration_order import Cluster, route_migrations  # noqa: E402

# The platform's own hosts, as they stand in dev. Copied rather than queried so the
# test runs with no credentials -- and so that a row someone deletes from dev does
# not quietly stop being covered here.
PLATFORM_HOSTS = [
    "api.dev.trovesuite.com", "api.trovesuite.com", "www.trovesuite.com",
    "cp.backend.trovesuite.com", "cp.dev.backend.trovesuite.com",
    "ld.backend.trovesuite.com", "msg.backend.trovesuite.com",
    "zhr-admin.backend.trovesuite.com", "zhr-employee.backend.dev.trovesuite.com",
    "admin.zeloshr.com", "admin-api.zeloshr.com", "api.zeloshr.com",
    "dev.trovesuite.com", "staging.trovesuite.com", "trovesuite.com",
    "loandrift.trovesuite.com", "mystoreguard.trovesuite.com",
    "zeloshr.dev.trovesuite.com", "zeloshr-admin.trovesuite.com",
    "dev.qpickstore.com", "localhost",
]

# Addresses a client holds, or could reasonably be given. Every one of these must
# be allowed, and the three live ones are the reason the list is not guesswork.
CLIENT_HOSTS = [
    "itech.dev.trovesuite.com",         # live, silo shared
    "accesspoint.dev.trovesuite.com",   # live, silo dedicated
    "bgclt.dev.trovesuite.com",         # live, pooled
    "apinnovations.dev.trovesuite.com",  # begins with api
    "appleseed.dev.trovesuite.com",     # begins with app
    "apparel.dev.trovesuite.com",       # begins with app
    "nsano.dev.trovesuite.com",         # begins with ns -- a real Ghanaian fintech
    "ldfoods.dev.trovesuite.com",       # begins with ld
    "cpcapital.dev.trovesuite.com",     # begins with cp
    "msgroup.dev.trovesuite.com",       # begins with msg
    "testament.dev.trovesuite.com",     # begins with test
    "democratic.dev.trovesuite.com",    # begins with demo
    "mailworks.dev.trovesuite.com",     # begins with mail
    "stationery.dev.trovesuite.com",    # begins with sta
    "dbschenker.dev.trovesuite.com",    # begins with db
    "king.dev.trovesuite.com",
    "supportive.dev.trovesuite.com",    # begins with support
]

# The shapes an exact-match list would have let through. These are the whole reason
# the comparison tokenises rather than comparing the label as one string.
MUST_REFUSE = [
    "api.dev.trovesuite.com",
    "api2.dev.trovesuite.com",
    "api-dev.dev.trovesuite.com",
    "api3-eu.dev.trovesuite.com",
    "www.dev.trovesuite.com",
    "www-1.dev.trovesuite.com",
    "cp-staging.dev.trovesuite.com",
    "cp_staging.dev.trovesuite.com",
    "zeloshr-admin.dev.trovesuite.com",
    "my-api.dev.trovesuite.com",
    "staging.dev.trovesuite.com",
    "POSTMASTER.dev.trovesuite.com",   # case, which the login already folds
    "  billing.dev.trovesuite.com",    # whitespace
]

FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}{(': ' + detail) if detail and not ok else ''}")
    if not ok:
        FAILS.append(label)


def insert(c, host, kind, tenant):
    """Insert a route and say what the database said. Returns (ok, message)."""
    tid = "NULL" if tenant is None else f"'{tenant}'"
    r = c.sql(
        "INSERT INTO control_plane.ctl_tenant_routes "
        "(host, tenant_id, tier, cell_key, status, is_wildcard, route_kind) "
        f"VALUES ('{host}', {tid}, 'POOLED', 'uksouth-dev', 'ACTIVE', false, '{kind}')")
    msg = (r.stderr or "").strip().splitlines()
    return r.returncode == 0, (msg[0] if msg else "")


def main():
    c = Cluster()
    c.start()
    try:
        files = route_migrations()
        failures = c.apply_all(files)
        # The three fixture gaps in test_route_migration_order are pre-existing and
        # are about the billing tables, not the routes. Named so a NEW failure here
        # is not read as one of them.
        known = {"20261004-11-charges-we-add-to-a-clients-bill.sql",
                 "20261004-09-what-a-silo-costs-us.sql",
                 "20261004-12-infrastructure-is-itemised-and-charged.sql"}
        unexpected = [f for f in failures if f[0] not in known]
        check("the migrations apply", not unexpected,
              "; ".join(f"{n} -> {e}" for n, e in unexpected))
        if unexpected:
            return 1

        n = c.value("SELECT count(*) FROM control_plane.ctl_reserved_labels")
        check("the words are held", n.isdigit() and int(n) >= 50, f"{n} rows")

        # ------------------------------------------------- the function, on its own
        for host in CLIENT_HOSTS:
            word = c.value("SELECT coalesce(control_plane.reserved_label("
                           f"control_plane.host_label('{host}')), '')")
            check(f"a real name is allowed: {host}", word == "",
                  f"refused because of {word!r}")

        for host in MUST_REFUSE:
            word = c.value("SELECT coalesce(control_plane.reserved_label("
                           f"control_plane.host_label('{host}')), '')")
            check(f"a platform name is caught: {host.strip()}", word != "",
                  "the function found nothing reserved in it")

        # EVERY platform host is a reserved name. If one is not, the word that
        # protects it is missing from the seed.
        missed = []
        for host in PLATFORM_HOSTS:
            word = c.value("SELECT coalesce(control_plane.reserved_label("
                           f"control_plane.host_label('{host}')), '')")
            if word == "":
                missed.append(host)
        check("every host of ours is a name a client cannot take", not missed,
              ", ".join(missed))

        # ------------------------------------------------------------- the trigger
        ok, msg = insert(c, "api2.dev.trovesuite.com", "TENANT", "tnt_probe")
        check("the trigger refuses a client at api2", not ok, "it was accepted")
        check("...and names the word", "api" in msg and "reserved" in msg, msg)

        ok, msg = insert(c, "apinnovations.dev.trovesuite.com", "TENANT", "tnt_probe")
        check("the trigger admits a client at apinnovations", ok, msg)

        # The WHEN clause. Our own hosts are all reserved names, so without it the
        # next deploy's re-run of the migrations that create them fails.
        refused = []
        for host in PLATFORM_HOSTS:
            if c.value(f"SELECT count(*) FROM control_plane.ctl_tenant_routes "
                       f"WHERE host = '{host}'") != "0":
                continue
            ok, msg = insert(c, host, "PLATFORM", None)
            if not ok:
                refused.append(f"{host} -> {msg}")
        check("our own hosts can still be created", not refused,
              "; ".join(refused[:3]))

        # Renaming into a reserved name is the same mistake arriving by UPDATE.
        r = c.sql("UPDATE control_plane.ctl_tenant_routes SET host = "
                  "'www.dev.trovesuite.com' WHERE host = 'apinnovations.dev.trovesuite.com'")
        check("a client route cannot be renamed onto www", r.returncode != 0,
              "the rename was accepted")

        # ...while a rename to another ordinary name goes through, because a trigger
        # that refuses every rename would also be "passing" the check above.
        r = c.sql("UPDATE control_plane.ctl_tenant_routes SET host = "
                  "'apinnovations2.dev.trovesuite.com' "
                  "WHERE host = 'apinnovations.dev.trovesuite.com'")
        check("an ordinary rename still works", r.returncode == 0,
              (r.stderr or "").strip().splitlines()[0] if r.stderr else "")

        # A reserved word is RELEASABLE, and the release has to survive a deploy.
        # Written both ways round because the obvious release -- DELETE the row --
        # looks like it works and is undone by the next re-run of the seed.
        c.sql("DELETE FROM control_plane.ctl_reserved_labels WHERE label = 'blog'")
        c.apply_all([p for p in files if p.name.startswith("20261005-08")])
        ok, msg = insert(c, "blog.dev.trovesuite.com", "TENANT", "tnt_probe")
        check("a DELETEd word comes back, so DELETE is not the way to release one",
              not ok, "the delete survived the re-run, and this test is now wrong")

        c.sql("UPDATE control_plane.ctl_reserved_labels SET released_at = now() "
              "WHERE label = 'news'")
        ok, msg = insert(c, "news.dev.trovesuite.com", "TENANT", "tnt_probe")
        check("releasing a word lets a client have it", ok, msg)
        c.apply_all([p for p in files if p.name.startswith("20261005-08")])
        still = c.value("SELECT count(*) FROM control_plane.ctl_reserved_labels "
                        "WHERE label = 'news' AND released_at IS NOT NULL")
        check("...and the next deploy does not take it back", still == "1",
              f"the release did not survive the re-run ({still})")
        ok, msg = insert(c, "news2.dev.trovesuite.com", "TENANT", "tnt_probe")
        check("...so the client can still be set up again afterwards", ok, msg)
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
