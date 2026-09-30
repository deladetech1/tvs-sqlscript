#!/usr/bin/env python3
"""Find roles that cannot finish the job they exist to do.

A role used to be granted its own resource and nothing around it, so the screen loaded and
the first request on it returned 403. A sales person could take a sale but not look up the
customer to put it against; whoever managed products could not upload a product image or see
a supplier. Nothing failed at deploy time, because nothing connects a screen to the
permissions its endpoints require -- which is what this does.

It reads three things and joins them:

  1. every controller's AST, for the `perm(R.X, A.Y[, T.Z])` calls inside each route;
  2. every frontend service, for which hook calls which URL;
  3. every frontend route, for which hooks its own files use -- its components, but NOT
     nested routes, or src/app/page.tsx looks like it needs all 166 permissions in the app.

A screen belongs to a role when the role can ACT on one of the resources that screen writes
to. "Act" means an action core_platform.cp_actions does not mark read-only -- read that flag
from the database rather than listing verbs here, because a hand-written list once missed
`statistics` and made the read-only Viewer Admin look as though it needed every write in
MyStoreGuard.

Usage:

    export DATABASE_URL='postgresql://user:pass@host:5432/db?sslmode=require'
    scripts/audit_role_permissions.py \
        --backend ../../mystoreguard/tvs-mystoreguard-bk \
        --frontend ../../mystoreguard/tvs-mystoreguard-ft \
        --app-prefix msg --roles 'role-msg-%'

Exit status is 1 when anything is missing, so it can gate a pipeline.
"""
import argparse
import ast
import os
import re
import sys

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    sys.exit("psycopg2 is required: pip install psycopg2-binary")

HOOK = re.compile(r"\buse([A-Z]\w*?)(Query|Mutation)\b")


# ---------------------------------------------------------------- backend

def backend_routes(root):
    """[{path, perms}] -- every route and the permissions it requires."""
    out = []
    entities = os.path.join(root, "app/src/entities")
    for dirpath, _, files in os.walk(entities):
        for f in files:
            if not f.endswith("_controller.py"):
                continue
            src = open(os.path.join(dirpath, f), encoding="utf-8").read()
            try:
                tree = ast.parse(src)
            except SyntaxError:
                continue
            m = re.search(r'APIRouter\([^)]*prefix\s*=\s*"([^"]*)"', src, re.S)
            prefix = m.group(1) if m else ""
            for node in ast.walk(tree):
                if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                path = None
                for dec in node.decorator_list:
                    call = dec if isinstance(dec, ast.Call) else None
                    fn = call.func if call else dec
                    if isinstance(fn, ast.Attribute) and fn.attr in (
                            "get", "post", "put", "patch", "delete"):
                        arg = call.args[0].value if (
                            call and call.args and isinstance(call.args[0], ast.Constant)
                        ) else ""
                        path = prefix + arg
                if path is None:
                    continue
                perms = set()
                for sub in ast.walk(node):
                    if (isinstance(sub, ast.Call) and isinstance(sub.func, ast.Name)
                            and sub.func.id == "perm"):
                        parts = [a.attr if isinstance(a, ast.Attribute) else str(a.value)
                                 for a in sub.args
                                 if isinstance(a, (ast.Attribute, ast.Constant))]
                        if parts:
                            perms.add(".".join(parts))
                out.append({"path": path, "perms": sorted(perms)})
    return out


def rat_constants(root):
    """The R / A / T classes in the app's generated permission module."""
    path = os.path.join(root, "app/src/utils/permissions.py")
    tree = ast.parse(open(path, encoding="utf-8").read())
    out = {}
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name in ("R", "A", "T"):
            out[node.name] = {
                t.id: st.value.value
                for st in node.body if isinstance(st, ast.Assign)
                and isinstance(st.value, ast.Constant)
                for t in st.targets if isinstance(t, ast.Name)
            }
    return out.get("R", {}), out.get("A", {}), out.get("T", {})


# --------------------------------------------------------------- frontend

def norm(url):
    return "/" + re.sub(r"\$\{[^}]*\}|\{[^}]*\}", "*", url.split("?")[0]).strip("/")


def service_hooks(ft_root):
    """hook name -> url template"""
    out = {}
    sdir = os.path.join(ft_root, "src/services")
    if not os.path.isdir(sdir):
        return out
    for f in os.listdir(sdir):
        if not f.endswith(".ts"):
            continue
        src = open(os.path.join(sdir, f), encoding="utf-8").read()
        for m in re.finditer(r"(\w+)\s*:\s*build\.(query|mutation)\s*<", src):
            name, kind = m.group(1), m.group(2)
            u = re.search(r"url\s*:\s*[`\"']([^`\"']+)",
                          src[m.end(): m.end() + 1400])
            if u:
                out["use" + name[0].upper() + name[1:]
                    + ("Query" if kind == "query" else "Mutation")] = u.group(1)
    return out


def screens(ft_root, hooks, by_path):
    """route -> the permissions everything on it requires"""
    app = os.path.join(ft_root, "src/app")
    result = {}
    for dirpath, _, files in os.walk(app):
        if "page.tsx" not in files:
            continue
        route = "/" + os.path.relpath(dirpath, app).replace(os.sep, "/")
        blob = ""
        for dp, subdirs, fs in os.walk(dirpath):
            if dp != dirpath and "page.tsx" in fs:
                subdirs[:] = []          # a route of its own
                continue
            for f in fs:
                if f.endswith((".ts", ".tsx")):
                    blob += open(os.path.join(dp, f), encoding="utf-8",
                                 errors="ignore").read()
        need = set()
        for m in HOOK.finditer(blob):
            url = hooks.get(m.group(0))
            if url:
                need |= by_path.get(norm(url), set())
        result[route] = need
    return result


# ------------------------------------------------------------------ audit

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", required=True)
    ap.add_argument("--frontend", required=True)
    ap.add_argument("--app-prefix", action="append", default=[],
                    help="repeatable; Core Platform owns both '' and 'cp'")
    ap.add_argument("--roles", required=True, help="LIKE pattern, e.g. 'role-msg-%%'")
    ap.add_argument("--exclude", action="append", default=[],
                    help="substring; roles containing it are skipped")
    ap.add_argument("--utility", action="append", default=["file"],
                    help="a resource that confers no ownership; repeatable")
    ap.add_argument("--reads-only", action="store_true",
                    help="list only the missing reads, which are the ones worth granting")
    args = ap.parse_args()

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("set DATABASE_URL")
    conn = psycopg2.connect(dsn)
    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    cur.execute("select id, app_prefix, resource_key, action, coalesce(target,'') target, "
                "scope from core_platform.cp_permissions")
    tup2id, id2tup = {}, {}
    for r in cur.fetchall():
        key = (r["app_prefix"], r["resource_key"], r["action"], r["target"], r["scope"])
        tup2id[key] = r["id"]
        id2tup[r["id"]] = key

    cur.execute("select action from core_platform.cp_actions where is_read_only")
    reads = {r[0] for r in cur.fetchall()}

    cur.execute("select rp.role_id, rp.permission_id from core_platform.cp_role_permissions rp "
                "join core_platform.cp_roles r on r.id = rp.role_id where r.id like %s",
                (args.roles,))
    held = {}
    for rid, pid in cur.fetchall():
        held.setdefault(rid, set()).add(pid)

    R, A, T = rat_constants(args.backend)
    prefixes = args.app_prefix or [""]

    def resolve(name):
        p = name.split(".")
        if len(p) < 2:
            return None
        rk, act = R.get(p[0]), A.get(p[1])
        tg = T.get(p[2], "") if len(p) > 2 else ""
        if rk is None or act is None:
            return None
        for pre in prefixes:
            hit = tup2id.get((pre, rk, act, tg, "any"))
            if hit:
                return hit
        return None

    by_path = {}
    for r in backend_routes(args.backend):
        by_path.setdefault(norm(r["path"]), set()).update(r["perms"])

    need_by_route = {}
    for route, names in screens(args.frontend, service_hooks(args.frontend), by_path).items():
        ids = {resolve(n) for n in names}
        ids.discard(None)
        if ids:
            need_by_route[route] = ids

    gaps, total = {}, 0
    for rid, mine in sorted(held.items()):
        if any(x in rid for x in args.exclude):
            continue
        # A utility resource confers no ownership. `file` is the one that matters: there is
        # no separate "product images" right, so a role that manages anything with an image
        # holds file writes -- and counting those as ownership made every such role look as
        # though it owned every screen in the app that uploads anything. ecommerce-admin
        # was reported as needing the whole product module on that basis.
        can_act = {id2tup[p][1] for p in mine
                   if id2tup[p][2] not in reads and id2tup[p][1] not in args.utility}
        if not can_act:
            continue                     # a reader has no screen of its own
        miss = {}
        for route, need in need_by_route.items():
            writes_here = {id2tup[p][1] for p in need
                           if id2tup[p][2] not in reads and id2tup[p][1] not in args.utility}
            if not (writes_here & can_act):
                continue
            for pid in need - mine:
                miss.setdefault(pid, set()).add(route)
        if args.reads_only:
            miss = {p: r for p, r in miss.items() if id2tup[p][2] in reads}
        if miss:
            gaps[rid] = miss
            total += len(miss)

    for rid, miss in sorted(gaps.items()):
        print(f"\n{rid}")
        for pid, routes in sorted(miss.items(), key=lambda kv: id2tup[kv[0]][1:3]):
            _, rk, act, tg, _ = id2tup[pid]
            kind = "read " if act in reads else "WRITE"
            print(f"   {kind} {rk}+{act}{'+' + tg if tg else ''}"
                  f"    ({sorted(routes)[0]})")

    print(f"\n{len(gaps)} role(s) with gaps, {total} permission(s) missing.")
    print("Reads and the file writes a role's own screens need are worth granting; "
          "adjacent writes usually are not -- a screen hosts more than one feature, and "
          "the sales screen carries store returns.")
    return 1 if gaps else 0


if __name__ == "__main__":
    sys.exit(main())
