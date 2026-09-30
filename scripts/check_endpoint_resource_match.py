#!/usr/bin/env python3
"""Find endpoints guarded by a permission for a DIFFERENT resource than they serve.

This is the bug that let a sales clerk read an organization's audit trail. The audit-log
endpoints each checked the audited entity's own read permission -- /audit-logs/organizations
asked for `organization|get` -- so anyone who could see an organization could see every change
ever made to it. `cp|logs|get` existed the whole time and no endpoint asked for it.

It is the same shape as the installment totals (`installment-plan|statistics` existed and
gated only its own screen) and the Expense Administrator (five `expense` permissions while
every expense endpoint checked `settings`). The catalogue looks right, the grants look right,
and the check is pointed somewhere else.

So: for every route, compare the resource the ROUTER serves against the resource the
permission names. A mismatch is not automatically wrong -- plenty are deliberate, a reporting
screen reads six things -- but every one should be a decision somebody made on purpose.

    scripts/check_endpoint_resource_match.py ../../coreplatform/tvs-coreplatform-bk

Exits non-zero if any route is reachable with no permission check at all.
"""
import argparse, ast, pathlib, re, sys
from collections import defaultdict

HTTP = {"get", "post", "put", "patch", "delete"}
# Reaching these is not a permission decision: they are owner-gated, or deliberately open.
OWNER_GUARDS = {"_is_owner", "is_owner", "_require_owner"}


def router_prefix(tree, src):
    """The prefix of the APIRouter this module defines, e.g. '/audit-logs'."""
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "APIRouter":
            for kw in node.keywords:
                if kw.arg == "prefix":
                    try:
                        return ast.literal_eval(kw.value)
                    except Exception:
                        return None
    return None


def _pair_of(call):
    parts = [a.attr for a in call.args if isinstance(a, ast.Attribute)]
    if len(parts) >= 2:
        return (parts[0], parts[1])
    return (parts[0], "?") if parts else None


def module_constants(tree):
    """`_GET = perm(R.INSTALLMENT_PLAN, A.GET)` at module level.

    MyStoreGuard names every permission once at the top and passes the constant, so a
    scanner that only sees inline perm() calls reports its entire API as ungated. It did:
    311 routes, every one of them actually guarded.
    """
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call) \
                and getattr(node.value.func, "id", "") in ("perm", "perm_id"):
            pair = _pair_of(node.value)
            for t in node.targets:
                if isinstance(t, ast.Name) and pair:
                    out[t.id] = pair
    return out


def _direct_perms(fn, consts):
    out = []
    for n in ast.walk(fn):
        if isinstance(n, ast.Call) and getattr(n.func, "id", "") in ("perm", "perm_id"):
            pair = _pair_of(n)
            if pair:
                out.append(pair)
        elif isinstance(n, ast.Name) and n.id in consts:
            out.append(consts[n.id])
    # A helper's own default: `def _authorize(user, perm_id=VIEW_PERMISSION)`.
    for d in list(fn.args.defaults) + [d for d in fn.args.kw_defaults if d]:
        if isinstance(d, ast.Name) and d.id in consts:
            out.append(consts[d.id])
        elif isinstance(d, ast.Call) and getattr(d.func, "id", "") in ("perm", "perm_id"):
            pair = _pair_of(d)
            if pair:
                out.append(pair)
    return out


def helper_perms(tree, consts):
    """What each module-level function checks, so a route that delegates still counts.

    Three real shapes, all of which a naive scan calls ungated: MyStoreGuard's audit logs
    check `logs|get` inside a shared _list_audit_logs the routes call; its reports carry
    the permission as a DEFAULT argument on _authorize; and most controllers name their
    permissions once as module constants. Missing these reported 311 guarded routes as
    having no check at all -- a scanner nobody can trust is worse than none.
    """
    fns = {n.name: n for n in tree.body
           if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
    perms = {name: list(_direct_perms(fn, consts)) for name, fn in fns.items()}
    calls = {name: {getattr(c.func, "id", "") for c in ast.walk(fn)
                    if isinstance(c, ast.Call)} & set(fns)
             for name, fn in fns.items()}
    # Delegation nests -- a route calls _loyalty_list, which calls _list_audit_logs,
    # which is where `logs|get` is actually checked. Resolve to a fixed point, which
    # also makes a cycle terminate instead of recursing.
    for _ in range(len(fns) + 1):
        changed = False
        for name in fns:
            before = len(perms[name])
            for callee in calls[name]:
                if callee != name:
                    for pair in perms[callee]:
                        if pair not in perms[name]:
                            perms[name].append(pair)
            changed |= len(perms[name]) != before
        if not changed:
            break
    return perms


def perms_in(fn, consts, helpers=None):
    """Every (resource, action) this route checks, directly or through a helper."""
    out = _direct_perms(fn, consts)
    for n in ast.walk(fn):
        if isinstance(n, ast.Call):
            name = getattr(n.func, "id", "")
            if helpers and name in helpers and name != fn.name:
                out.extend(helpers[name])
    return out


def always_refuses(fn):
    """A route that raises no matter what -- deleting a security audit row is a 405
    for everybody, owner included. Not a permission decision, so not a finding."""
    for stmt in ast.walk(fn):
        if isinstance(stmt, ast.With):
            body = stmt.body
        elif isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
            body = stmt.body
        else:
            continue
        for st in body:
            if isinstance(st, ast.Raise):
                return True
    return False


def owner_guarded(fn):
    for n in ast.walk(fn):
        if isinstance(n, ast.Call):
            name = getattr(n.func, "id", "") or getattr(n.func, "attr", "")
            if name in OWNER_GUARDS:
                return True
    return False


def norm(text):
    return re.sub(r"[^a-z]", "", (text or "").lower())


def known_resources(repo):
    """Every resource_key this app's generated permission module defines."""
    mod = pathlib.Path(repo, "app", "src", "utils", "permissions.py")
    if not mod.is_file():
        return set()
    out = set()
    for line in mod.read_text().splitlines():
        m = re.match(r'\s{4}[A-Z][A-Z0-9_]*\s*=\s*"([a-z0-9-]+)"', line)
        if m:
            out.add(m.group(1))
        if line.startswith("class A"):      # resources are declared before actions
            break
    return out


def resource_of_path(path, known):
    """The catalogued resource this path is about, longest match wins.

    /audit-logs/organizations is about `logs`; /unit-of-measures is about nothing the
    catalogue names, because a unit of measure is a setting and has no permission of
    its own. That distinction is the whole point: only the first kind can be checking
    the wrong thing.
    """
    flat = norm(path)
    hits = [r for r in known if norm(r) and norm(r) in flat]
    return max(hits, key=len) if hits else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repo")
    ap.add_argument("--quiet", action="store_true", help="only mismatches and ungated routes")
    args = ap.parse_args()

    root = pathlib.Path(args.repo, "app", "src")
    if not root.is_dir():
        sys.exit(f"no app/src under {args.repo}")

    known = known_resources(args.repo)
    mismatches, ungated, total = [], [], 0
    for f in sorted(root.rglob("*_controller.py")):
        src = f.read_text()
        try:
            tree = ast.parse(src, str(f))
        except SyntaxError as e:
            print(f"  !! {f}: {e}")
            continue
        prefix = router_prefix(tree, src)
        consts = module_constants(tree)
        helpers = helper_perms(tree, consts)
        served = norm(prefix)
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            routes = [(getattr(d.func, "attr", "?"), ast.literal_eval(d.args[0]))
                      for d in node.decorator_list
                      if isinstance(d, ast.Call) and getattr(d.func, "attr", "") in HTTP
                      and d.args and isinstance(d.args[0], ast.Constant)]
            if not routes:
                continue
            total += len(routes)
            got = perms_in(node, consts, helpers)
            rel = str(f).split("/app/src/")[-1]
            for method, route in routes:
                if not got:
                    if owner_guarded(node) or always_refuses(node):
                        continue
                    ungated.append((rel, method.upper(), (prefix or "") + route, node.name))
                    continue
                if not served:
                    continue
                # Only flag when the path is ABOUT a resource the catalogue names and
                # the check never mentions it. A route guarded by a broader resource that
                # owns it (units of measure under settings) is a design, not a hole.
                full = (prefix or "") + route
                about = resource_of_path(full, known)
                if not about:
                    continue
                checked = {norm(r) for r, _ in got}
                if norm(about) not in checked:
                    mismatches.append((rel, method.upper(), full, about,
                                       sorted({f"{r}|{a}" for r, a in got})))

    name = pathlib.Path(args.repo).name
    print(f"\n=== {name}: {total} routes ===")
    if mismatches:
        print(f"\n{len(mismatches)} route(s) about one resource, guarded by another:")
        for rel, m, route, about, perms in mismatches:
            print(f"  {m:6} {route:44}")
            print(f"         about `{about}` but checks {', '.join(perms)}   [{rel}]")
    else:
        print("  every guarded route names its own resource")
    if ungated:
        print(f"\n{len(ungated)} route(s) with NO permission check and no owner guard:")
        for rel, m, route, fn in ungated:
            print(f"  {m:6} {route:46} {fn}")
            print(f"         {rel}")
    return 1 if ungated else 0


if __name__ == "__main__":
    sys.exit(main())
