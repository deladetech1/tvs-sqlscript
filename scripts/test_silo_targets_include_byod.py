#!/usr/bin/env python3
"""Does the silo workflow find a BYOD client's database?

Run:  python3 scripts/test_silo_targets_include_byod.py

# WHY THIS EXISTS

SILO_BYOD was missing from silos.yml entirely. The discovery query selected
only SILO_SHARED and SILO_DEDICATED, so a BYOD client could have a correct
route, correct credentials in our vault, and a database with no tables in it --
and nothing anywhere said so. A tier list that is out of date is usually loud;
this one was silent.

So the selection logic is lifted out of the workflow and run here, rather than
being exercised only by dispatching the real thing against a real database.

The credential is the other half. For the silos WE build, Terraform writes
migrator-db-url-<silo> and the name is composed from the key. For BYOD there is
no Terraform, no per-app role and no migrator secret -- the single credential
the client gave us is the route's db_secret_uri, and composing the usual name
would point at a secret that does not exist, failing later with a vault 404
that reads like a permissions problem.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WF = ROOT / ".github" / "workflows" / "silos.yml"

FAILS = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + ("" if ok else f"\n        {detail}"))
    if not ok:
        FAILS.append(label)


src = WF.read_text()

# ---------------------------------------------------- the query finds all three
m = re.search(r"AND tier IN \(([^)]*)\)", src)
check("the discovery query names every silo tier",
      m is not None and all(t in m.group(1) for t in
                            ("'SILO_SHARED'", "'SILO_DEDICATED'", "'SILO_BYOD'")),
      m.group(1) if m else "no tier list found")

check("...and selects the column BYOD's credential lives in",
      "db_secret_uri" in src.split("python3 -")[0],
      "db_secret_uri is not in the SELECT, so the BYOD branch has nothing to use")

# ---------------------------------------------------- run the real selection
block = re.search(r"python3 - <<'PY' >> \"\$GITHUB_OUTPUT\"\n(.*?)\n          PY\n",
                  src, re.S)
if not block:
    print("could not find the selection script in the workflow")
    raise SystemExit(1)
body = "\n".join(l[10:] if l.startswith(" " * 10) else l
                 for l in block.group(1).splitlines())
# It writes to GITHUB_OUTPUT via print; capture instead.
body = body.replace("import json, os, sys", "import json, os, sys")


def run(rows, kind="all", target="all"):
    """The workflow's own selection, with the environment it reads."""
    import io
    import contextlib
    env = {
        "KIND": kind, "TARGET": target, "KV": "tvs-dev-kv",
        "ROWS": "\n".join(rows),
    }
    import os as _os
    old = dict(_os.environ)
    _os.environ.update(env)
    out, err = io.StringIO(), io.StringIO()
    code = 0
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            exec(compile(body, "<silos.yml>", "exec"), {"__name__": "__main__"})
    except SystemExit as e:
        code = e.code or 0
    finally:
        _os.environ.clear()
        _os.environ.update(old)
    return code, out.getvalue(), err.getvalue()


# host | tier | db_name | silo_key | db_secret_uri | db_server_fqdn
SHARED = "itech.dev.trovesuite.com|SILO_SHARED|silo-itech-dev|itech||tvs-dev-pg"
DEDI = "accesspoint.dev.trovesuite.com|SILO_DEDICATED|silo-accesspoint-dev|accesspoint||ap-pg"
BYOD = ("kofi.dev.trovesuite.com|SILO_BYOD|their_db|kofi|"
        "https://tvs-dev-kv.vault.azure.net/secrets/db-byod-kofi|kofi-pg")
# BGCLT's shape: per-app logins, so the row names its silo and no single secret;
# six hosts, one database.
BGCLT = [f"{h}|SILO_BYOD|bgclt|bgclt||bgclt-prod-sql.postgres.database.azure.com"
         for h in ("bgclt.trovesuite.com", "cp.prod.backend.bgclt.com", "erp.bgclt.com",
                   "msg.app.frontend.bgclt.com", "msg.prod.backend.bgclt.com",
                   "mystoreguard.frontend.bgclt.com")]
BYOD_NO_CRED = "kofi.dev.trovesuite.com|SILO_BYOD|their_db|||kofi-pg"

code, out, err = run([SHARED, DEDI, BYOD])
check("all three are selected by 'all'", code == 0 and out.count('"host"') == 3,
      f"code={code} out={out[:300]} err={err[:200]}")
check("...and the BYOD one is in the matrix", "kofi.dev.trovesuite.com" in out,
      out[:300])

# THE CREDENTIAL. Composing migrator-db-url-kofi would name a secret Terraform
# never wrote, because Terraform never touched this client's database.
check("BYOD uses the credential on the route",
      "secrets/db-byod-kofi" in out and "migrator-db-url-kofi" not in out,
      out[:400])
check("...while our own silos still use their migrator secret",
      "migrator-db-url-itech" in out and "migrator-db-url-accesspoint" in out,
      out[:400])

# FAILS CLOSED. A BYOD row naming neither a secret nor a silo has nothing to
# migrate with, and saying so beats a vault 404 three jobs later.
code, out, err = run([BYOD_NO_CRED])
check("a BYOD route with neither db_secret_uri nor silo_key is refused",
      code != 0 and "silo_key" in err, f"code={code} err={err[:300]}")

# PER-APP LOGINS (B3): silo_key and no db_secret_uri. The apps compose
# db-url-<app>-bgclt; migrations use the client's owner login, copied into our
# vault as migrator-db-url-bgclt. And six hosts are ONE database: one job, not six
# racing each other through the same migrations.
code, out, err = run(BGCLT, kind="byod")
check("a BYOD route with only a silo_key migrates with migrator-db-url-<silo>",
      code == 0 and "secrets/migrator-db-url-bgclt" in out, f"code={code} err={err[:300]} out={out[:300]}")
check("...once per database, however many hosts it has",
      out.count('"host"') == 1 and '"host": "bgclt.trovesuite.com"' in out, out[:400])
code, out, err = run(BGCLT + [SHARED, DEDI, BYOD])
check("'all' is one job per database", code == 0 and out.count('"host"') == 4, out[:600])
code, out, err = run(BGCLT, kind="byod", target="erp.bgclt.com")
check("a target names its database through any of its hosts",
      code == 0 and out.count('"host"') == 1 and "erp.bgclt.com" in out, out[:300])

# The kind filter has to know the new tier, or `kind=byod` selects nothing and
# the run goes green having done nothing.
code, out, err = run([SHARED, DEDI, BYOD], kind="byod")
check("kind=byod selects exactly the BYOD silos",
      code == 0 and out.count('"host"') == 1 and "kofi" in out,
      f"code={code} out={out[:300]} err={err[:200]}")
code, out, err = run([SHARED, DEDI, BYOD], kind="shared")
check("kind=shared still selects only the shared one",
      code == 0 and out.count('"host"') == 1 and "itech" in out, out[:300])

# And the dropdown must name silos that exist, or choosing one fails the
# check against ctl_tenant_routes rather than deploying.
opts = re.search(r"Which silo \(add new ones.*?options:\n(.*?)\n      module:",
                 src, re.S)
# The OPTION LINES only. The first version of this check looked at the whole
# block, which now contains a comment explaining the old names -- so the check
# failed on the explanation of the thing it was checking for.
option_lines = [l.strip()[2:] for l in (opts.group(1).splitlines() if opts else [])
                if l.strip().startswith("- ")]
check("the target dropdown names the silos that exist",
      "itech.dev.trovesuite.com" in option_lines
      and "bgclt.trovesuite.com" in option_lines
      and not any("siloshared" in o or "silodedicated" in o for o in option_lines),
      str(option_lines))

print()
if FAILS:
    print(f"BROKEN: {len(FAILS)} case(s)")
    sys.exit(1)
print("OK -- a BYOD client's database is found, with the only credential we have for it")
