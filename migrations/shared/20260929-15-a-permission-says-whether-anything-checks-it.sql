-- Whether any endpoint checks a permission, recorded where it can be seen
--
-- A permission can exist, be granted to a role, appear on every screen that lists it, and be
-- checked by nothing. Expense Administrator held all five `expense` permissions while every
-- expense endpoint checked `settings` -- so the role could not manage an expense, and the
-- catalogue said it should.
--
-- 47 of 502 permissions are in that state. The database cannot work this out: it is a
-- property of the code. scripts/mark_enforced_permissions.py measures it across the four app
-- repos and writes it here, and the permissions screen shows it.
--
-- NULL means "not audited since this column was added" and is deliberately distinct from
-- false. A permission nobody has measured is not the same as a permission nothing checks, and
-- showing them the same way would make the first look like a defect.

BEGIN;

ALTER TABLE core_platform.cp_permissions
    ADD COLUMN IF NOT EXISTS is_enforced boolean;

COMMENT ON COLUMN core_platform.cp_permissions.is_enforced IS
    'Whether any endpoint checks this permission. Measured from the app repos by '
    'tvs-sqlscript/scripts/mark_enforced_permissions.py; NULL means not yet audited.';

COMMIT;
