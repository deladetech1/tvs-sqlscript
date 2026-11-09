#!/usr/bin/env python3
"""A temporary firewall rule on a BYOD client's PostgreSQL server for THIS CI runner.

Why: since 2026-10-22 our GitHub jobs run on Blacksmith runners, which are not
Azure addresses, so a client server that admits "Azure services" only refuses
them. Until this existed the only fix was an `allow-internet` rule
(0.0.0.0-255.255.255.255) on the client's server. Instead, a job that must reach
a BYOD database:

    open   PUT firewall rule  trovesuite-ci-<run_id>-<attempt>-<job>-<epoch>
           for exactly this runner's address (/32), wait until it shows
    ...    does its database work
    close  DELETE that rule, in a step with `if: always()`, and wait until it is gone

The rule is written as the CLIENT's app registration (their tenant), signed in
with the job's GitHub OIDC token -- no secret anywhere. The identity needs only
firewallRules read/write/delete (+ server read) on that one server: the custom
role "Trovesuite CI firewall (<server>)" from docs/byod-client-setup.sh, or the
Contributor-on-the-resource-group the onboarding app registration already has.

Standard library only. The SAME file lives in two repositories and must stay
identical: deladetech1/tvs-sqlscript scripts/ci_firewall.py (silos.yml/apply.yml)
and deladetech1/tvs-iac scripts/onboard/ci_firewall.py (onboard/register).

Access file (JSON, ids only, no secret -- our vault holds it as byod-access-<silo>):
    {"client_id": "<app id>", "tenant_id": "<their tenant>",
     "server_id": "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.DBforPostgreSQL/flexibleServers/<name>"}

    python ci_firewall.py open  --access-file a.json --state $RUNNER_TEMP/ci-firewall.json
    python ci_firewall.py close --state $RUNNER_TEMP/ci-firewall.json
"""
from __future__ import annotations

import argparse
import base64
import ipaddress
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable, Optional

PREFIX = "trovesuite-ci-"
PG_API = "2024-08-01"
ARM = "https://management.azure.com"
STALE_AFTER = 6 * 3600          # a trovesuite-ci-* rule older than this is a leftover (jobs time out long before)
GUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
SERVER_ID = re.compile(r"^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/"
                       r"Microsoft\.DBforPostgreSQL/flexibleServers/[A-Za-z0-9-]+$", re.I)
IP_SERVICES = ("https://api.ipify.org", "https://checkip.amazonaws.com", "https://ifconfig.me/ip")


class FirewallError(RuntimeError):
    """A failure to say plainly in the job log -- the job stops on it."""


def log(msg: str) -> None:
    print(msg, flush=True)


def gh(kind: str, msg: str) -> None:
    """::error:: / ::warning:: / ::notice:: in Actions, plain text elsewhere."""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::{kind}::{msg}", flush=True)
    else:
        print(f"{kind.upper()} {msg}", flush=True)


def mask(value: str) -> None:
    if value and os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::add-mask::{value}", flush=True)


# --------------------------------------------------------------- pure parts
def rule_name(run_id: str, attempt: str, job: str, now: float) -> str:
    """trovesuite-ci-<run_id>-<attempt>-<job>-<epoch>: unique per job, sweepable by age.

    Azure allows [A-Za-z0-9_-], 1-128 characters. The epoch is LAST so the age can
    be read back from the name (firewall rules carry no timestamp of their own).
    """
    clean = lambda s: re.sub(r"[^A-Za-z0-9_]+", "_", str(s or "x")).strip("_")[:40] or "x"  # noqa: E731
    return f"{PREFIX}{clean(run_id)}-{clean(attempt)}-{clean(job)}-{int(now)}"[:128]


def rule_epoch(name: str) -> Optional[int]:
    if not name.startswith(PREFIX):
        return None
    tail = name.rsplit("-", 1)[-1]
    return int(tail) if tail.isdigit() and len(tail) == 10 else None


def stale_rules(rules: list, now: float, keep: str, max_age: int = STALE_AFTER) -> list:
    """Names of OUR ci rules (never anyone else's) that are older than max_age."""
    out = []
    for r in rules:
        n = r.get("name", "")
        e = rule_epoch(n)
        if n != keep and e is not None and now - e > max_age:
            out.append(n)
    return out


def parse_access(raw: str) -> dict:
    try:
        a = json.loads(raw)
    except Exception as e:  # noqa: BLE001
        raise FirewallError(f"the access file is not JSON ({type(e).__name__})") from None
    if not isinstance(a, dict):
        raise FirewallError("the access file must be a JSON object")
    for k in ("client_id", "tenant_id"):
        if not GUID.fullmatch(str(a.get(k, ""))):
            raise FirewallError(f"access file: {k} must be a GUID")
    if not SERVER_ID.match(str(a.get("server_id", ""))):
        raise FirewallError("access file: server_id must be the server's full ARM id "
                            "(/subscriptions/.../flexibleServers/<name>)")
    return {"client_id": a["client_id"].lower(), "tenant_id": a["tenant_id"].lower(),
            "server_id": a["server_id"].rstrip("/")}


def valid_ipv4(text: str) -> Optional[str]:
    try:
        ip = ipaddress.ip_address(text.strip())
    except ValueError:
        return None
    if ip.version != 4 or ip.is_private or ip.is_loopback or ip.is_unspecified:
        return None
    return str(ip)


def jwt_claims(token: str) -> dict:
    part = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))


def explain_aad(body: str, client_id: str, tenant: str, subject: str) -> str:
    """Turn the AADSTS code into the fix -- these two are what onboarding a client keeps hitting."""
    if "AADSTS700213" in body or "AADSTS70021" in body:
        return (f"AADSTS700213: app registration {client_id} in tenant {tenant} has no federated credential whose "
                f"subject is exactly '{subject}' (byte for byte -- a trailing space fails the same way). The client "
                f"adds it (docs/byod-client-setup.sh prints the subjects).")
    if "AADSTS700016" in body:
        return (f"AADSTS700016: no app registration {client_id} in tenant {tenant} -- wrong tenant id or client id, "
                f"or the client deleted it.")
    if "AADSTS7000215" in body or "AADSTS50" in body:
        return f"sign-in refused in tenant {tenant}: {body[:300]}"
    return f"sign-in to tenant {tenant} as {client_id} failed: {body[:300]}"


def explain_arm(code: int, method: str, what: str, client_id: str, server_id: str) -> str:
    server = server_id.rsplit("/", 1)[-1]
    if code in (401, 403):
        return (f"{method} {what} -> {code}: app registration {client_id} may not manage firewall rules on {server}. "
                f"The client assigns it the role 'Trovesuite CI firewall ({server})' on that server "
                f"(docs/byod-client-setup.sh), or Contributor on its resource group.")
    if code == 404:
        return f"{method} {what} -> 404: server {server_id} is not visible to {client_id} (deleted, or wrong id)."
    return f"{method} {what} -> {code}"


# --------------------------------------------------------------- network
def http(req: urllib.request.Request, timeout: int = 60) -> tuple[int, str]:
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")


def runner_ip(fetch: Callable[[str], str] = None) -> str:
    fetch = fetch or (lambda u: http(urllib.request.Request(u, headers={"User-Agent": "trovesuite-ci"}), 20)[1])
    seen = []
    for url in IP_SERVICES:
        try:
            ip = valid_ipv4(fetch(url) or "")
        except Exception:  # noqa: BLE001
            ip = None
        if ip:
            return ip
        seen.append(url)
    raise FirewallError(f"could not learn this runner's public IPv4 address (asked {', '.join(seen)})")


def github_oidc() -> str:
    url, bearer = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL"), os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
    if not (url and bearer):
        raise FirewallError("no GitHub OIDC token in this job (it needs `permissions: id-token: write`)")
    code, body = http(urllib.request.Request(url + "&audience=api://AzureADTokenExchange",
                                             headers={"Authorization": f"Bearer {bearer}"}), 30)
    if code != 200:
        raise FirewallError(f"GitHub refused an OIDC token ({code})")
    tok = json.loads(body)["value"]
    mask(tok)
    return tok


def arm_token(client_id: str, tenant: str, assertion: str) -> str:
    """Client-credentials with the GitHub token as the assertion: no az profile, no secret."""
    subject = jwt_claims(assertion).get("sub", "?")
    data = urllib.parse.urlencode({
        "client_id": client_id, "grant_type": "client_credentials", "scope": f"{ARM}/.default",
        "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_assertion": assertion}).encode()
    code, body = http(urllib.request.Request(
        f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token", data=data, method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"}), 30)
    if code != 200:
        raise FirewallError(explain_aad(body, client_id, tenant, subject))
    tok = json.loads(body)["access_token"]
    mask(tok)
    got = jwt_claims(tok).get("tid", "").lower()
    if got != tenant:
        raise FirewallError(f"signed in to tenant {got}, not {tenant}")
    return tok


class Arm:
    def __init__(self, token: str, client_id: str, server_id: str, sleep=None):
        self.token, self.client_id, self.server_id = token, client_id, server_id
        self.sleep = sleep or (lambda s: time.sleep(s))

    def call(self, method: str, path: str, body: Optional[dict] = None, ok404: bool = False):
        url = f"{ARM}{path}?api-version={PG_API}"
        data = json.dumps(body).encode() if body is not None else None
        what = path.split("/providers/")[-1]
        for attempt in range(6):
            req = urllib.request.Request(url, data=data, method=method, headers={
                "Authorization": f"Bearer {self.token}", "Content-Type": "application/json"})
            code, raw = http(req)
            if code < 300:
                return json.loads(raw) if raw.strip() else {}
            if code == 404 and ok404:
                return None
            # 409 = the server is busy with another change (it takes one at a time).
            if (code in (409, 429) or code >= 500) and attempt < 5:
                self.sleep(15 * (attempt + 1))
                continue
            raise FirewallError(explain_arm(code, method, what, self.client_id, self.server_id) + f" {raw[:300]}")

    def rule(self, name: str) -> Optional[dict]:
        return self.call("GET", f"{self.server_id}/firewallRules/{name}", ok404=True)

    def rules(self) -> list:
        return (self.call("GET", f"{self.server_id}/firewallRules") or {}).get("value", [])


def wait_until(check: Callable[[], bool], resend: Optional[Callable[[], None]], timeout: int, sleep=None,
               clock=None, every: int = 10, resend_after: int = 180) -> bool:
    """Poll until check() is true. A change the server accepted and then dropped (it was
    busy) is sent again every resend_after seconds -- each one is an idempotent PUT/DELETE."""
    sleep = sleep or time.sleep
    clock = clock or (lambda: time.time())
    end = last = clock()
    end += timeout
    while clock() < end:
        if check():
            return True
        if resend and clock() - last > resend_after:
            log("  not visible yet -- sending it again")
            resend()
            last = clock()
        sleep(every)
    return check()


def open_rule(arm: Arm, name: str, ip: str, timeout: int = 900, settle: int = 20) -> None:
    body = {"properties": {"startIpAddress": ip, "endIpAddress": ip}}
    put = lambda: arm.call("PUT", f"{arm.server_id}/firewallRules/{name}", body)  # noqa: E731
    put()
    shows = lambda: ((arm.rule(name) or {}).get("properties") or {}).get("startIpAddress") == ip  # noqa: E731
    if not wait_until(shows, put, timeout, sleep=arm.sleep):
        raise FirewallError(f"rule {name} did not appear on {arm.server_id.rsplit('/', 1)[-1]} within {timeout}s")
    arm.sleep(settle)  # the gateway picks a new rule up a few seconds after ARM shows it


def close_rule(arm: Arm, name: str, timeout: int = 600) -> None:
    delete = lambda: arm.call("DELETE", f"{arm.server_id}/firewallRules/{name}", ok404=True)  # noqa: E731
    delete()
    if not wait_until(lambda: arm.rule(name) is None, delete, timeout, sleep=arm.sleep):
        raise FirewallError(f"rule {name} is still on {arm.server_id.rsplit('/', 1)[-1]} after {timeout}s")


def sweep(arm: Arm, keep: str, now: float) -> list:
    """Best effort: remove trovesuite-ci-* rules left by jobs that died before their close step."""
    gone = []
    for n in stale_rules(arm.rules(), now, keep):
        try:
            close_rule(arm, n, timeout=300)
            gone.append(n)
        except FirewallError as e:
            gh("warning", f"could not remove the leftover rule {n}: {e}")
    return gone


def summary(line: str) -> None:
    p = os.environ.get("GITHUB_STEP_SUMMARY")
    if p:
        with open(p, "a") as f:
            f.write(line + "\n")


# --------------------------------------------------------------- commands
def cmd_open(a) -> int:
    with open(a.access_file) as f:
        acc = parse_access(f.read())
    server = acc["server_id"].rsplit("/", 1)[-1]
    now = time.time()
    name = rule_name(os.environ.get("GITHUB_RUN_ID", "local"), os.environ.get("GITHUB_RUN_ATTEMPT", "1"),
                     a.job or os.environ.get("GITHUB_JOB", "job"), now)
    ip = runner_ip()
    token = arm_token(acc["client_id"], acc["tenant_id"], github_oidc())
    arm = Arm(token, acc["client_id"], acc["server_id"])
    # The state goes down BEFORE the PUT: if this step dies after Azure accepted the
    # rule, the always() close step still knows what to remove.
    with open(a.state, "w") as f:
        json.dump({**acc, "rule": name, "ip": ip}, f)
    log(f"opening {name} ({ip}/32) on {server} as {acc['client_id']} ...")
    open_rule(arm, name, ip, timeout=a.timeout)
    gh("notice", f"temporary firewall rule {name} ({ip}/32) open on {server}; removed when this job ends")
    summary(f"- firewall: `{name}` ({ip}/32) opened on `{server}` (removed in the job's final step)")
    gone = sweep(arm, name, now)
    if gone:
        log(f"removed leftover rules: {', '.join(gone)}")
    return 0


def cmd_close(a) -> int:
    if not os.path.exists(a.state):
        log("no temporary firewall rule was opened in this job -- nothing to remove")
        return 0
    with open(a.state) as f:
        st = json.load(f)
    acc = parse_access(json.dumps(st))
    server = acc["server_id"].rsplit("/", 1)[-1]
    token = arm_token(acc["client_id"], acc["tenant_id"], github_oidc())
    close_rule(Arm(token, acc["client_id"], acc["server_id"]), st["rule"])
    os.remove(a.state)
    log(f"removed {st['rule']} from {server}")
    summary(f"- firewall: `{st['rule']}` removed from `{server}`")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    o = sub.add_parser("open")
    o.add_argument("--access-file", required=True)
    o.add_argument("--state", required=True)
    o.add_argument("--job", default="")
    o.add_argument("--timeout", type=int, default=900)
    c = sub.add_parser("close")
    c.add_argument("--state", required=True)
    a = ap.parse_args(argv)
    try:
        return cmd_open(a) if a.cmd == "open" else cmd_close(a)
    except FirewallError as e:
        if a.cmd == "close":
            gh("error", f"the temporary firewall rule was NOT removed: {e} -- remove trovesuite-ci-* rules on the "
                        f"client's server by hand (offboarding also removes every trovesuite-* rule)")
        else:
            gh("error", f"cannot open a firewall rule for this runner: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
