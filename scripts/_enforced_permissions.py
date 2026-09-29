"""The (app, resource, action) triples some endpoint actually checks."""
import ast, pathlib, re
def _names(root):
    tree = ast.parse((pathlib.Path(root) / "app/src/utils/permissions.py").read_text())
    return {f"{n.name}.{s.targets[0].id}": s.value.value
            for n in tree.body if isinstance(n, ast.ClassDef) and n.name in ("R", "A")
            for s in n.body if isinstance(s, ast.Assign) and isinstance(s.value, ast.Constant)}
def python_app(root, prefix):
    nm = _names(root); used = set()
    pat = re.compile(r'perm\(\s*(R\.[A-Z0-9_]+)\s*,\s*(A\.[A-Z0-9_]+)', re.S)
    for f in (pathlib.Path(root) / "app/src").rglob("*.py"):
        if f.name == "permissions.py": continue
        for m in pat.finditer(f.read_text(encoding="utf-8", errors="replace")):
            r, a = nm.get(m.group(1)), nm.get(m.group(2))
            if r and a: used.add((prefix, r, a))
    return used
def dotnet_app(root):
    src = pathlib.Path(root) / "app/src"
    mod = (src / "Shared/Authorization/ZelosHrPermissions.cs").read_text()
    pairs = {}
    for cls in re.finditer(r'public static class (\w+)\s*\{(.*?)\n    \}', mod, re.S):
        for c in re.finditer(r'public const string (\w+)\s*=\s*"([^"]+)"', cls.group(2)):
            pairs[(cls.group(1), c.group(1))] = c.group(2)
    used = set()
    for f in src.rglob("*.cs"):
        if f.name == "ZelosHrPermissions.cs": continue
        for m in re.finditer(r'ZelosHrPermissions\.([A-Za-z]+)\.([A-Za-z]+)',
                             f.read_text(encoding="utf-8", errors="replace")):
            p = pairs.get((m.group(1), m.group(2)))
            if p:
                bits = p.split("|"); used.add((bits[0], bits[1], bits[2]))
    return used
def all_enforced(base="."):
    b = pathlib.Path(base)
    return (python_app(b / "mystoreguard/tvs-mystoreguard-bk", "msg")
            | python_app(b / "loandrift/tvs-loandrift-bk", "loandrift")
            | python_app(b / "coreplatform/tvs-coreplatform-bk", "")
            | dotnet_app(b / "zeloshr/tvs-zeloshr-admin-bk"))
