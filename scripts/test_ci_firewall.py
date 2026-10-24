"""ci_firewall.py (the runner's temporary BYOD firewall rule) and its wiring into apply.yml / silos.yml.

    pip install pytest pyyaml && pytest scripts/test_ci_firewall.py

The same ci_firewall.py lives in deladetech1/tvs-iac scripts/onboard/ (onboard /
register jobs); its tests there are the same as the first half of this file.

No network: ARM, Entra and GitHub's token endpoint are replaced by fakes.
"""
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import ci_firewall as fw  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SID = ("/subscriptions/149c2fed-e354-4dd3-9fd8-4c0448ccaf71/resourceGroups/acme-db-rg/providers/"
       "Microsoft.DBforPostgreSQL/flexibleServers/acme-sql")
ACCESS = {"client_id": "4A89FDBD-0000-4000-8000-000000000001", "tenant_id": "efad3705-4b30-4134-af68-31071661da78",
          "server_id": SID}


# --------------------------------------------------------------- names
def test_rule_name_is_ours_unique_and_valid():
    n = fw.rule_name("39880084878", "2", "apply", 1761200000)
    assert n == "trovesuite-ci-39880084878-2-apply-1761200000"
    assert n.startswith("trovesuite-")  # offboard removes every trovesuite-* rule
    weird = fw.rule_name("1", "1", "1-2 direct (BYOD)", 1761200000)
    import re
    assert re.fullmatch(r"[A-Za-z0-9_-]{1,128}", weird)
    assert fw.rule_epoch(weird) == 1761200000
    assert len(fw.rule_name("9" * 200, "1", "j" * 200, 1761200000)) <= 128


def test_sweep_only_touches_our_old_ci_rules():
    now = 1761200000
    rules = [{"name": "allow-internet"}, {"name": "AllowAzureServices"}, {"name": "client-ip"},
             {"name": "trovesuite-azure-services"},
             {"name": f"trovesuite-ci-1-1-apply-{now - 7 * 3600}"},     # leftover
             {"name": f"trovesuite-ci-2-1-apply-{now - 600}"},          # another job, running now
             {"name": f"trovesuite-ci-3-1-apply-{now - 9 * 3600}"}]     # the one we keep (ours)
    assert fw.stale_rules(rules, now, keep=f"trovesuite-ci-3-1-apply-{now - 9 * 3600}") == \
        [f"trovesuite-ci-1-1-apply-{now - 7 * 3600}"]


def test_access_file_is_checked():
    assert fw.parse_access(json.dumps(ACCESS))["client_id"] == ACCESS["client_id"].lower()
    for bad in ({**ACCESS, "client_id": "x"}, {**ACCESS, "server_id": "acme-sql"}, {"client_id": ACCESS["client_id"]}):
        with pytest.raises(fw.FirewallError):
            fw.parse_access(json.dumps(bad))
    with pytest.raises(fw.FirewallError):
        fw.parse_access("not json")


def test_runner_ip_is_public_ipv4_with_fallbacks():
    answers = {fw.IP_SERVICES[0]: "<html>", fw.IP_SERVICES[1]: "10.0.0.4\n", fw.IP_SERVICES[2]: "20.68.1.2\n"}
    assert fw.runner_ip(lambda u: answers[u]) == "20.68.1.2"
    with pytest.raises(fw.FirewallError):
        fw.runner_ip(lambda u: "0.0.0.0")


def test_errors_name_the_fix():
    m = fw.explain_aad("AADSTS700213: No matching federated identity", "cid", "tid",
                       "repo:deladetech1/tvs-sqlscript:ref:refs/heads/master")
    assert "repo:deladetech1/tvs-sqlscript:ref:refs/heads/master" in m and "byte for byte" in m
    assert "wrong tenant" in fw.explain_aad("AADSTS700016", "cid", "tid", "s")
    m = fw.explain_arm(403, "PUT", "firewallRules/x", "cid", SID)
    assert "Trovesuite CI firewall (acme-sql)" in m


# --------------------------------------------------------------- ARM flow (fake)
class FakeServer:
    """A flexible server's firewallRules collection; drop_first simulates 'accepted, then dropped'."""

    def __init__(self, rules=None, drop_first=False, deny=None):
        self.rules = dict(rules or {})
        self.drop_first, self.deny, self.calls = drop_first, deny, []

    def call(self, method, path, body=None, ok404=False):
        self.calls.append((method, path.rsplit("/", 1)[-1]))
        if self.deny == method:
            raise fw.FirewallError(fw.explain_arm(403, method, path, "cid", SID))
        name = path.rsplit("/", 1)[-1]
        if method == "PUT":
            if self.drop_first:
                self.drop_first = False
                return {}
            self.rules[name] = {"name": name, "properties": body["properties"]}
            return {}
        if method == "DELETE":
            self.rules.pop(name, None)
            return {}
        if name == "firewallRules":
            return {"value": list(self.rules.values())}
        r = self.rules.get(name)
        if r is None and not ok404:
            raise fw.FirewallError("404")
        return r


def arm_on(server):
    a = fw.Arm("tok", "cid", SID, sleep=lambda s: None)
    a.call = server.call
    return a


def test_open_waits_until_the_rule_shows_and_resends_a_dropped_put(monkeypatch):
    t = [0.0]
    monkeypatch.setattr(fw.time, "time", lambda: t[0])
    srv = FakeServer(drop_first=True)
    a = arm_on(srv)
    a.sleep = lambda s: t.__setitem__(0, t[0] + s)
    fw.open_rule(a, "trovesuite-ci-1-1-apply-1761200000", "20.68.1.2", timeout=900, settle=0)
    assert srv.rules["trovesuite-ci-1-1-apply-1761200000"]["properties"] == \
        {"startIpAddress": "20.68.1.2", "endIpAddress": "20.68.1.2"}
    assert [c for c in srv.calls if c[0] == "PUT"].__len__() == 2  # the dropped one was sent again


def test_open_times_out_loudly(monkeypatch):
    t = [0.0]
    monkeypatch.setattr(fw.time, "time", lambda: t[0])
    srv = FakeServer()
    srv.call = lambda m, p, body=None, ok404=False: None if m == "GET" else {}
    a = arm_on(srv)
    a.sleep = lambda s: t.__setitem__(0, t[0] + s)
    with pytest.raises(fw.FirewallError, match="did not appear"):
        fw.open_rule(a, "trovesuite-ci-x", "20.68.1.2", timeout=60, settle=0)


def test_close_removes_only_its_rule():
    srv = FakeServer({"allow-internet": {"name": "allow-internet"}, "trovesuite-ci-1": {"name": "trovesuite-ci-1"}})
    fw.close_rule(arm_on(srv), "trovesuite-ci-1")
    assert list(srv.rules) == ["allow-internet"]
    assert all(c[1] != "allow-internet" for c in srv.calls if c[0] == "DELETE")


def _patch_network(monkeypatch, srv):
    monkeypatch.setattr(fw, "runner_ip", lambda: "20.68.1.2")
    monkeypatch.setattr(fw, "github_oidc", lambda: "oidc")
    monkeypatch.setattr(fw, "arm_token", lambda c, t, a: "tok")
    real = fw.Arm

    class A(real):
        def __init__(self, *args, **kw):
            super().__init__(*args, **kw)
            self.sleep = lambda s: None
            self.call = srv.call
    monkeypatch.setattr(fw, "Arm", A)


def test_open_then_close_end_to_end(tmp_path, monkeypatch):
    srv = FakeServer({"AllowAzureServices": {"name": "AllowAzureServices"}})
    _patch_network(monkeypatch, srv)
    monkeypatch.setenv("GITHUB_RUN_ID", "777")
    monkeypatch.setenv("GITHUB_RUN_ATTEMPT", "1")
    monkeypatch.setenv("GITHUB_JOB", "apply")
    acc, state = tmp_path / "a.json", tmp_path / "s.json"
    acc.write_text(json.dumps(ACCESS))
    assert fw.main(["open", "--access-file", str(acc), "--state", str(state)]) == 0
    mine = [n for n in srv.rules if n.startswith("trovesuite-ci-777-1-apply-")]
    assert len(mine) == 1 and json.loads(state.read_text())["rule"] == mine[0]
    assert fw.main(["close", "--state", str(state)]) == 0
    assert list(srv.rules) == ["AllowAzureServices"] and not state.exists()
    # A second close (or a job that never opened) is a no-op, not a failure.
    assert fw.main(["close", "--state", str(state)]) == 0


def test_open_fails_clearly_without_the_right(tmp_path, monkeypatch, capsys):
    srv = FakeServer(deny="PUT")
    _patch_network(monkeypatch, srv)
    acc, state = tmp_path / "a.json", tmp_path / "s.json"
    acc.write_text(json.dumps(ACCESS))
    assert fw.main(["open", "--access-file", str(acc), "--state", str(state)]) == 1
    out = capsys.readouterr().out
    assert "cannot open a firewall rule" in out and "Trovesuite CI firewall (acme-sql)" in out
    # The state was written BEFORE the PUT, so the always() close still tries to remove it.
    assert state.exists()


# --------------------------------------------------------------- workflow shape
yaml = pytest.importorskip("yaml")


def _steps():
    return yaml.safe_load((ROOT / ".github/workflows/apply.yml").read_text())["jobs"]["apply"]["steps"]


def test_apply_opens_after_our_login_and_before_any_sql_and_closes_last():
    steps = _steps()
    names = [s.get("name", s.get("uses", "")) for s in steps]
    i_open = names.index("Runner access (open)")
    i_resolve = names.index("Resolve the connection string")
    i_cmd = names.index("${{ inputs.command }}")
    i_iso = names.index("Isolation report")
    i_list = names.index("migrations-list")
    assert i_resolve < i_open < i_cmd < i_iso < i_list
    assert "inputs.byod_access_uri != ''" in steps[i_open]["if"] and "'plan'" in steps[i_open]["if"]
    last = steps[-1]
    assert last["name"] == "Runner access (close)"
    assert last["if"].startswith("always()")
    assert "ci_firewall.py close" in last["run"]


def test_missing_access_secret_warns_any_other_vault_error_fails():
    run = next(s for s in _steps() if s.get("name") == "Runner access (open)")["run"]
    i = run.index("SecretNotFound")
    assert "::warning::" in run[i:i + 400] and "exit 0" in run[i:i + 900]
    assert "::error::cannot read" in run


def test_byod_access_is_an_input_and_silos_pass_it():
    wf = yaml.safe_load((ROOT / ".github/workflows/apply.yml").read_text())
    on = wf.get("on", wf.get(True))
    assert on["workflow_call"]["inputs"]["byod_access_uri"]["default"] == ""
    silos = yaml.safe_load((ROOT / ".github/workflows/silos.yml").read_text())
    assert silos["jobs"]["apply"]["with"]["byod_access_uri"] == "${{ matrix.byod_access_uri }}"


def test_same_file_as_tvs_iac_when_checked_out_side_by_side():
    other = ROOT.parent / "tvs-iac" / "scripts" / "onboard" / "ci_firewall.py"
    if not other.exists():
        pytest.skip("tvs-iac not next to this checkout")
    assert other.read_text() == (Path(__file__).parent / "ci_firewall.py").read_text()
