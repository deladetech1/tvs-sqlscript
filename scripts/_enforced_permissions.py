"""The (app, resource, action) triples some endpoint actually checks."""
import ast, pathlib, re
def _names(root):
    tree = ast.parse((pathlib.Path(root) / "app/src/utils/permissions.py").read_text())
    return {f"{n.name}.{s.targets[0].id}": s.value.value
            for n in tree.body if isinstance(n, ast.ClassDef) and n.name in ("R", "A")
            for s in n.body if isinstance(s, ast.Assign) and isinstance(s.value, ast.Constant)}
def python_app(root, prefix):
    """Permissions the code actually uses -- not merely ones a file names.

    Matching `perm(R.X, A.Y)` anywhere counted MyStoreGuard's

        USE_PERMISSION = perm(R.CUSTOM_FIELDS, A.GET)

    as enforced. It is a leftover constant nothing reads, so the audit reported a permission
    as checked when nothing checked it -- the exact failure the audit exists to find.

    Requiring the call to be an argument to a known check function was too strict the other
    way, and wrongly cleared nine working permissions: BACKDATE_PERMISSION is a module
    constant read from another file, and `required_permission` is a local assigned in one
    function and passed to the check in the next line of several others.

    So the rule is narrow and about reachability, not idiom: a permission counts unless its
    only appearance is an assignment to a name that nothing anywhere ever reads. That catches
    the dead constant and clears everything a person actually wired up, whatever idiom they
    used to wire it.
    """
    nm = _names(root)
    src_root = pathlib.Path(root) / "app/src"
    trees = {}
    for f in src_root.rglob("*.py"):
        if f.name == "permissions.py":
            continue
        try:
            trees[f] = ast.parse(f.read_text(encoding="utf-8", errors="replace"))
        except SyntaxError:
            continue

    # Every name the app ever READS, across all its files.
    read_names = set()
    for tree in trees.values():
        for n in ast.walk(tree):
            if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load):
                read_names.add(n.id)

    def resolve(node):
        """The (resource, action) a `perm(R.X, A.Y, ...)` call names, if it is one."""
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "perm" and len(node.args) >= 2):
            return None
        parts = []
        for a in node.args[:2]:
            if not isinstance(a, ast.Attribute) or not isinstance(a.value, ast.Name):
                return None
            parts.append(nm.get(f"{a.value.id}.{a.attr}"))
        return tuple(parts) if all(parts) else None

    used = set()
    for tree in trees.values():
        # Names this file assigns a permission to, so an assignment can be judged separately
        # from an inline use.
        assigned = {}
        for n in ast.walk(tree):
            if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
                got = resolve(n.value)
                if got:
                    assigned.setdefault(id(n.value), n.targets[0].id)
        for n in ast.walk(tree):
            got = resolve(n)
            if not got:
                continue
            name = assigned.get(id(n))
            if name is not None and name not in read_names:
                continue        # written once, read never
            used.add((prefix, got[0], got[1]))
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
def accounting_app(root):
    """Permissions an Accounting API endpoint grants access on.

    Each endpoint carries `[RequiresAccountingPermission(AccountingPermissions.X)]`, which also
    accepts the ids in the attribute's own `Legacy = ...` list (and, while the API had them, the older
    ids in `AccountingPermissions.LegacyAliases[X]`). A grant of any of them works, so all of them count.
    Ids are split the way the Accounting seed (02_permissions.sql) sets resource_key and action.

    Anything this cannot read raises instead of being skipped: a partial set would be written to
    is_enforced as "checked by nothing" for every permission it missed.
    """
    src = pathlib.Path(root) / "app/src"
    auth = src / "Shared/Authorization"
    mod_path = auth / "AccountingPermissions.cs"
    mod = mod_path.read_text(encoding="utf-8")
    ids = dict(re.findall(r'public const string (\w+)\s*=\s*"([^"]+)"', mod))
    # The API retired its LegacyAliases (WI-19); if they come back they are read, and an unreadable block raises.
    aliases = {}
    if "LegacyAliases" in mod:
        block = re.search(r'LegacyAliases\s*=\s*new Dictionary<string, string\[\]>\s*\{(.*?)\n\s*\};', mod, re.S)
        if not block:
            raise ValueError(f"{mod_path}: LegacyAliases present but unreadable")
        aliases = {k: re.findall(r'\w+', v) for k, v in re.findall(r'\[(\w+)\]\s*=\s*\[([^\]]*)\]', block.group(1))}

    def code_of(text):
        # Comments are not code: a commented-out attribute checks nothing.
        text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
        return "\n".join(l.split("//", 1)[0] for l in text.splitlines())

    attribute = re.compile(r'\[RequiresAccountingPermission\(AccountingPermissions\.(\w+)(.*?)\)\]')
    legacy_arg = re.compile(r'Legacy\s*=\s*(?:new\s*(?:string\s*)?\[\]\s*\{([^}]*)\}|\[([^\]]*)\])')
    names, seen = set(), 0
    for f in src.rglob("*.cs"):
        if f.parent.resolve() == auth.resolve():
            continue
        code = code_of(f.read_text(encoding="utf-8", errors="replace"))
        found = list(attribute.finditer(code))
        # Every use must be one this reads: a split, aliased or list-form attribute would be missed.
        uses = len(re.findall(r'\bRequiresAccountingPermission(?:Attribute)?\s*\(', code))
        if uses != len(found):
            raise ValueError(f"{f}: {uses} RequiresAccountingPermission use(s), {len(found)} readable")
        for m in found:
            seen += 1
            names.add(m.group(1))
            rest = m.group(2).strip()
            legacy = legacy_arg.search(rest)
            if rest and not legacy:
                raise ValueError(f"{f}: unreadable arguments {rest!r}")
            names.update(re.findall(r'AccountingPermissions\.(\w+)', legacy.group(1) or legacy.group(2) or "")
                         if legacy else aliases.get(m.group(1), []))
    if not seen:
        raise ValueError(f"{src}: no RequiresAccountingPermission attributes found")

    used = set()
    for n in names:
        m = re.fullmatch(r'permission-accounting-(.+)-([a-z]+)', ids.get(n, ""))
        if not m:
            raise ValueError(f"{mod_path}: AccountingPermissions.{n} is not a permission-accounting-<resource>-<action> id")
        used.add(("accounting", m.group(1), m.group(2)))
    return used


def all_enforced(base="."):
    b = pathlib.Path(base)
    return (python_app(b / "mystoreguard/tvs-mystoreguard-bk", "msg")
            | python_app(b / "loandrift/tvs-loandrift-bk", "loandrift")
            | python_app(b / "coreplatform/tvs-coreplatform-bk", "")
            | dotnet_app(b / "zeloshr/tvs-zeloshr-admin-bk")
            | accounting_app(b / "accounting/tvs-accounting-bk"))
