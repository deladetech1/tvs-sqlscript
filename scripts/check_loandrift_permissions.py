"""Compare mounted LoanDrift API/UI permission IDs against SQL seed definitions.
Run from a workspace containing tvs-sqlscript and package/tvs-loandrift.
This is a source audit; it does not connect to or change a database.
"""
import ast
from pathlib import Path
import re

SQL = Path(__file__).resolve().parents[1]
APP = SQL.parent / 'package/tvs-loandrift'
BACKEND = APP / 'tvs-loandrift-bk/app'
FRONTEND = APP / 'tvs-loandrift-ft/src'
pattern = r'permission-loandrift-[a-z0-9-]+'
known = set()
for path in SQL.rglob('*.sql'):
    known.update(re.findall(r"\('(permission-loandrift-[a-z0-9-]+)'\s*,", path.read_text()))
# Only mounted controllers participate; legacy/unmounted copies are not API routes.
controllers = []
for node in ast.parse((BACKEND / 'main.py').read_text()).body:
    if isinstance(node, ast.ImportFrom) and node.module and node.module.startswith('src.entities.'):
        path = BACKEND / (node.module.replace('.', '/') + '.py')
        if path.exists():
            controllers.append(path)
files = controllers + [FRONTEND / 'utils/permissions.ts', BACKEND / 'src/entities/inbox/inbox_service.py']
missing = []
for path in files:
    for permission in sorted(set(re.findall(pattern, path.read_text())) - known):
        missing.append(f'{path.name}: {permission}')
if missing:
    raise SystemExit('Unseeded permissions:\n' + '\n'.join(missing))
print(f'PASS {len(controllers)} mounted controller modules and frontend catalogue; all permission IDs are seeded')
