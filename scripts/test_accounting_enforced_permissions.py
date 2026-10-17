#!/usr/bin/env python3
"""The enforcement audit reads Accounting's .NET attributes the way the API applies them.

# WHY THIS EXISTS

mark_enforced_permissions.py writes cp_permissions.is_enforced from what the code checks.
Accounting does not call perm(R.X, A.Y); each endpoint carries

    [RequiresAccountingPermission(AccountingPermissions.X)]

and the attribute also accepts the older ids in AccountingPermissions.LegacyAliases[X], or,
when it sets `Legacy = new[] { ... }`, those instead. Reading only the first id would mark
every legacy grant "checked by nothing" while it still opens the endpoint; reading every
constant in the file would mark a permission checked when no endpoint names it. Both are the
lie the audit exists to catch.

Run:

    python3 scripts/test_accounting_enforced_permissions.py

The second check needs tvs-accounting-bk checked out beside tvs-sqlscript and is skipped
otherwise.
"""
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from _enforced_permissions import accounting_app  # noqa: E402

PERMISSIONS = '''namespace Accounting.Api.Shared.Authorization;
public static class AccountingPermissions
{
    public const string JournalList = "permission-accounting-journal-list";
    public const string JournalAdd = "permission-accounting-journal-add";
    public const string Unused = "permission-accounting-orphan-delete";
    public const string BankAccountList = "permission-accounting-bank-account-list";
    public const string BankList = "permission-accounting-bank-list";
    public const string BankStatementList = "permission-accounting-bank-statement-list";
    public const string RuleList = "permission-accounting-rule-list";
    public const string AccountingRuleList = "permission-accounting-accounting-rule-list";
    public const string Commented = "permission-accounting-ghost-get";

    public static readonly IReadOnlyDictionary<string, string[]> LegacyAliases = new Dictionary<string, string[]>
    {
        [AccountingRuleList] = [RuleList],
        [BankAccountList] = [BankList],
    };
}
'''

CONTROLLER = '''public sealed class Things : ControllerBase
{
    [HttpGet("list")]
    [RequiresAccountingPermission(AccountingPermissions.JournalList)]
    public void A() { }

    [HttpGet("rules")]
    [RequiresAccountingPermission(AccountingPermissions.AccountingRuleList)]
    public void B() { }

    // The endpoint's own Legacy list replaces LegacyAliases: BankList is not accepted here.
    [HttpGet("statements")]
    [RequiresAccountingPermission(AccountingPermissions.BankAccountList, Legacy = new[] { AccountingPermissions.BankStatementList })]
    public void C() { }

    // [RequiresAccountingPermission(AccountingPermissions.Commented)]
    public void D() { }
}
'''


def synthetic():
    with tempfile.TemporaryDirectory() as tmp:
        auth = pathlib.Path(tmp, "app/src/Shared/Authorization")
        auth.mkdir(parents=True)
        (auth / "AccountingPermissions.cs").write_text(PERMISSIONS)
        ctl = pathlib.Path(tmp, "app/src/Entities/things")
        ctl.mkdir(parents=True)
        (ctl / "ThingsController.cs").write_text(CONTROLLER)
        got = accounting_app(tmp)

    want = {
        ("accounting", "journal", "list"),            # named by an attribute
        ("accounting", "accounting-rule", "list"),    # named by an attribute
        ("accounting", "rule", "list"),               # its LegacyAliases entry
        ("accounting", "bank-account", "list"),       # named, with a Legacy list
        ("accounting", "bank-statement", "list"),     # from that Legacy list
    }
    assert got == want, f"\n got  {sorted(got)}\n want {sorted(want)}"
    # Not enforced: a constant no attribute names, an alias the endpoint's Legacy replaced,
    # and an attribute that is only a comment.
    for absent in [("accounting", "journal", "add"), ("accounting", "orphan", "delete"),
                   ("accounting", "bank", "list"), ("accounting", "ghost", "get")]:
        assert absent not in got, absent
    print("synthetic: ok")


def real_repo():
    root = HERE.parent.parent / "tvs-accounting-bk"
    if not (root / "app/src/Shared/Authorization/AccountingPermissions.cs").exists():
        print(f"real repo: skipped ({root} not checked out)")
        return
    got = accounting_app(root)
    seed = (HERE.parent / "src/Trovesuite.Database.Accounting/Sql/Seeds/02_permissions.sql").read_text()
    # The seed's own rule for resource_key and action.
    seeded = {("accounting", m.group(1), m.group(2))
              for m in re.finditer(r"'permission-accounting-(.+?)-([a-z]+)'", seed)}
    assert got, "the scan found nothing: it is broken, not the API"
    missing = got - seeded
    assert not missing, f"enforced but not seeded: {sorted(missing)}"
    print(f"real repo: ok ({len(got)} enforced, all seeded)")


if __name__ == "__main__":
    synthetic()
    real_repo()
