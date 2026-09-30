#!/usr/bin/env python3
"""Every R.X / A.X a Python app uses must exist in its generated permission module.

Regenerating a module with the wrong flags silently removes names. It happened: both
MyStoreGuard and LoanDrift enforce permission-currency-get, which belongs to Core Platform
(app_prefix ''), so it only appears in their modules via --also-include. A regeneration
without that flag dropped R.CURRENCY from both, and every currency endpoint answered

    500  type object 'R' has no attribute 'CURRENCY'

The boot-time audit does not catch this: it compares the module against cp_permissions and
both agreed. What broke was the module against the CODE.

    scripts/check_permission_refs.py ../../mystoreguard/tvs-mystoreguard-bk

Exits non-zero when a name is used and not defined.
"""
import ast, pathlib, re, sys

def defined(module: pathlib.Path) -> dict:
    tree = ast.parse(module.read_text(encoding="utf-8"))
    return {
        cls: {
            t.id
            for n in tree.body if isinstance(n, ast.ClassDef) and n.name == cls
            for s in n.body if isinstance(s, ast.Assign)
            for t in s.targets if isinstance(t, ast.Name)
        }
        for cls in ("R", "A", "T")
    }

def main(root: str) -> int:
    src_root = pathlib.Path(root) / "app" / "src"
    module = src_root / "utils" / "permissions.py"
    if not module.exists():
        sys.exit(f"no generated module at {module}")
    have = defined(module)

    missing: dict[str, set] = {}
    for f in src_root.rglob("*.py"):
        if f.resolve() == module.resolve():
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        # Only files that import these names mean the permission module's R/A/T. `T` in
        # particular is also a db-settings table class elsewhere, and matching it there
        # produced forty false positives the first time this was run by hand.
        imported = re.search(r'from src\.utils\.permissions import ([^\n]+)', text)
        if not imported:
            continue
        names = {n.strip() for n in imported.group(1).split(",")}
        # Comments are not code. `# R.USER_ROLES stops existing` is a sentence about a risk.
        code = "\n".join(l.split("#", 1)[0] for l in text.splitlines())
        for cls in ("R", "A", "T"):
            if cls not in names:
                continue
            for m in re.finditer(rf'\b{cls}\.([A-Z][A-Z0-9_]*)\b', code):
                if m.group(1) not in have[cls]:
                    missing.setdefault(f"{cls}.{m.group(1)}", set()).add(str(f.relative_to(root)))

    if not missing:
        print(f"{root}: every permission name used in code exists in the module")
        return 0
    print(f"{root}: {len(missing)} name(s) used in code but missing from the module:")
    for name, files in sorted(missing.items()):
        print(f"  {name:28} {', '.join(sorted(files))}")
    return 1

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
