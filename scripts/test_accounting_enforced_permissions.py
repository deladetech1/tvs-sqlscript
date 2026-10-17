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

The real-repo check needs tvs-accounting-bk checked out beside tvs-sqlscript (not the
monorepo layout mark_enforced_permissions.py uses) and says "skipped" otherwise.
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
    public const string GlList = "permission-accounting-gl-list";
    public const string PeriodList = "permission-accounting-period-list";
    public const string FiscalList = "permission-accounting-fiscal-list";

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

    /* [RequiresAccountingPermission(AccountingPermissions.Commented)] */
    [HttpGet("e")]
    [RequiresAccountingPermission(AccountingPermissions.JournalAdd, Legacy = new string[] { AccountingPermissions.GlList })]
    public void E() { }

    [HttpGet("f")]
    [RequiresAccountingPermission(AccountingPermissions.PeriodList, Legacy = [AccountingPermissions.FiscalList])]
    public void F() { }

    // Mentions of the type are not uses.
    private static readonly Type Kind = typeof(RequiresAccountingPermissionAttribute);
}
'''


def scan(permissions=PERMISSIONS, controller=CONTROLLER):
    with tempfile.TemporaryDirectory() as tmp:
        auth = pathlib.Path(tmp, "app/src/Shared/Authorization")
        auth.mkdir(parents=True)
        (auth / "AccountingPermissions.cs").write_text(permissions)
        ctl = pathlib.Path(tmp, "app/src/Entities/things")
        ctl.mkdir(parents=True)
        (ctl / "ThingsController.cs").write_text(controller)
        return accounting_app(tmp)


def synthetic():
    got = scan()
    want = {
        ("accounting", "journal", "list"),            # named by an attribute
        ("accounting", "accounting-rule", "list"),    # named by an attribute
        ("accounting", "rule", "list"),               # its LegacyAliases entry
        ("accounting", "bank-account", "list"),       # named, with a Legacy list
        ("accounting", "bank-statement", "list"),     # from that Legacy list
        ("accounting", "journal", "add"),             # named, Legacy = new string[] { ... }
        ("accounting", "gl", "list"),                 # from that list
        ("accounting", "period", "list"),             # named, Legacy = [ ... ]
        ("accounting", "fiscal", "list"),             # from that list
    }
    assert got == want, f"\n got  {sorted(got)}\n want {sorted(want)}"
    # Not enforced: a constant no attribute names, an alias the endpoint's Legacy replaced,
    # and an attribute that is only a comment (// or /* */).
    for absent in [("accounting", "orphan", "delete"), ("accounting", "bank", "list"), ("accounting", "ghost", "get")]:
        assert absent not in got, absent
    print("synthetic: ok")


def refuses(label, **kw):
    try:
        scan(**kw)
    except ValueError as e:
        print(f"refuses {label}: ok ({str(e).split(': ', 1)[-1]})")
        return
    raise AssertionError(f"scan accepted {label}; a partial set would be written as 'checked by nothing'")


def loud_failures():
    one = "[RequiresAccountingPermission(AccountingPermissions.JournalList)]\n"
    refuses("an attribute split over lines",
            controller="[RequiresAccountingPermission(\n    AccountingPermissions.JournalList)]\n")
    refuses("an attribute in a combined list",
            controller="[HttpGet, RequiresAccountingPermission(AccountingPermissions.JournalList)]\n")
    refuses("an unknown constant", controller="[RequiresAccountingPermission(AccountingPermissions.Nope)]\n")
    refuses("an argument it cannot read",
            controller="[RequiresAccountingPermission(AccountingPermissions.JournalList, Other = 1)]\n")
    refuses("a missing LegacyAliases block",
            permissions=PERMISSIONS.split("    public static readonly")[0] + "}\n", controller=one)
    refuses("no attributes at all", controller="public class Empty { }\n")


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
    # Every seeded permission is checked by some endpoint today. If one stops being checked,
    # this fails on purpose: say why in the seed, or remove the permission.
    assert got == seeded, (f"enforced but not seeded: {sorted(got - seeded)}\n"
                           f"seeded but checked by nothing: {sorted(seeded - got)}")
    print(f"real repo: ok ({len(got)} enforced = {len(seeded)} seeded)")


if __name__ == "__main__":
    synthetic()
    loud_failures()
    real_repo()
