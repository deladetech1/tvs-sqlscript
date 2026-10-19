"""Does every Loandrift money path tell the books, once, with Loandrift's own figures?

# WHY THIS EXISTS

20261019-41 publishes Loandrift's ledger to Accounting from a deferred trigger on
loandrift.ld_journal_entries (docs/POSTINGS.md §5). This runs Loandrift's REAL service code
(disburse, repay with a penalty outstanding, repay again, reverse, write off, recover, savings
deposit and withdrawal, a manual journal) against a database migrated with 38-41, commits for
real, and after EVERY step checks:

  - the step published exactly the events it should, once (a write that fails: nothing; a manual
    journal: nothing);
  - each event's lines are exactly the Loandrift journal it describes, by account key;
  - the figures Loandrift itself reports: outstanding principal (independently: approved - the
    principal part of every live repayment), interest, fees and penalties collected, cash by channel.

It then writes the captured events, with those figures as expectations, to tvs-accounting-bk
tests/Accounting.Api.Tests/Fixtures/Postings/ld_events.json, where Accounting's tests post them
with its real posting code and check the books agree.

Run (the DSN must be a throwaway copy of dev-db with 38-41 applied; it COMMITS):

    python3 scripts/test_ld_accounting_events.py "host=127.0.0.1 port=5544 user=debrah dbname=ld_t1" \\
        [path to tvs-loandrift-bk] [path to tvs-accounting-bk]
"""
import json
import os
import sys
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LD = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "loandrift" / "tvs-loandrift-bk"
ACC = Path(sys.argv[3]) if len(sys.argv) > 3 else ROOT / "accounting" / "tvs-accounting-bk"
DSN = sys.argv[1]
sys.path.insert(0, str(LD / "app"))
os.chdir(LD / "app")

import psycopg2  # noqa: E402
from psycopg2.extras import RealDictCursor  # noqa: E402

LOAN_REF = "LN-20260905-000009"   # APPROVED on dev: 5,000 principal, 6,000 flat interest, 500 processing fee
SAVINGS = "svacc_a25981456ae0ac261f0913da751aed2f2d13b1a71ba5c796fa806a571"
CENT = Decimal("0.01")
fails, passes = [], 0


def D(v):
    return Decimal(str(v or 0)).quantize(CENT, rounding=ROUND_HALF_UP)


def check(label, got, want):
    global passes
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {label}" + ("" if ok else f": got {got!r}, want {want!r}"))
    if ok:
        passes += 1
    else:
        fails.append(label)


def q(sql, params=()):
    with psycopg2.connect(DSN) as c, c.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()] if cur.description else None


class _Pool:
    def getconn(self):
        conn = psycopg2.connect(DSN)
        conn.autocommit = False
        return conn

    def putconn(self, conn, close=False):
        try:
            conn.close()
        except Exception:
            pass


def use_database():
    import trovesuite.configs.database as tvsdb
    pool = _Pool()
    tvsdb.get_connection_pool = lambda: pool
    tvsdb._note_unscoped_access = lambda *a, **k: None
    from src.entities.shared.sh_service import ActivityLogService
    ActivityLogService.log_activity = staticmethod(lambda *a, **k: None)


class Feed:
    """The ld.* events since the last look, and the books as they post them (by Loandrift key)."""

    def __init__(self):
        self.mark = q("SELECT coalesce(max(id), 0) AS m FROM core_platform.cp_events")[0]["m"]
        self.all = []
        self.by_key = defaultdict(Decimal)   # debit positive

    def since(self):
        rows = q("SELECT id, kind, subject_id, bus_id, payload FROM core_platform.cp_events "
                 "WHERE id > %s AND source_app = 'loandrift' ORDER BY id", (self.mark,))
        if rows:
            self.mark = rows[-1]["id"]
        for e in rows:
            for l in e["payload"].get("lines", []):
                self.by_key[l["account_key"]] += D(l["debit"]) - D(l["credit"])
        self.all += rows
        return rows


def journal_lines(entry_id):
    rows = q("""SELECT a.system_key AS k, l.debit, l.credit FROM loandrift.ld_journal_lines l
                JOIN loandrift.ld_chart_of_accounts a ON a.id = l.account_id WHERE l.journal_entry_id = %s
                ORDER BY l.line_number""", (entry_id,))
    return [(r["k"], str(D(r["debit"])), str(D(r["credit"]))) for r in rows]


def event_lines(e):
    return [(l["account_key"], l["debit"], l["credit"]) for l in e["payload"]["lines"]]


def step(feed, label, want_kinds):
    es = feed.since()
    check(f"{label}: published {want_kinds}", sorted(e["kind"] for e in es), sorted(want_kinds))
    for e in es:
        if e["kind"] == "ld.posting_error":
            print("     error:", e["payload"].get("error"))
            continue
        check(f"{label}: {e['kind']} lines = Loandrift's journal {e['subject_id'][:14]}", event_lines(e), journal_lines(e["subject_id"]))
        check(f"{label}: {e['kind']} published once", len([x for x in feed.all if x["subject_id"] == e["subject_id"]]), 1)
    return {e["kind"]: e for e in es}


def main():
    use_database()
    from src.entities.capturing.capturing_service import CapturingService
    from src.entities.capturing.capturing_write_dto import DisburseLoanServiceWriteDto
    from src.entities.repayments.repayments_service import RepaymentsService
    from src.entities.repayments.repayments_write_dto import CreateRepaymentServiceWriteDto
    from src.entities.repayments.rp_actions import RepaymentActions
    from src.entities.writeoffs.wo_service import WriteOffs
    from src.entities.savings.sv_service import SavingsService
    from src.entities.savings.sv_write_dto import SavingsDepositWriteDto, SavingsWithdrawalWriteDto
    from src.entities.accounting.acc_service import AccountingService
    from src.entities.accounting.acc_base import Line
    from src.configs.database import DatabaseManager

    loan = q("SELECT * FROM loandrift.ld_loan_details_view WHERE loan_reference = %s", (LOAN_REF,))[0]
    T, O, B, L = loan["tenant_id"], loan["org_id"], loan["bus_id"], loan["loc_id"]
    S = (T, O, B, L)
    U, U2 = loan["created_by"], "uid-ld-accounting-test-approver"
    LID, CID = loan["id"], loan["client_id"]
    approved, interest = D(loan["approved_amount"]), D(loan["interest_amount"])
    fees = D(loan["processing_fees"]) + D(loan["insurance"]) + D(loan["other_charges"])
    party = q("SELECT party_id FROM loandrift.ld_clients WHERE id = %s", (CID,))[0]["party_id"]
    print(f"loan {LOAN_REF}: {approved} principal, {interest} interest, {fees} charges; business {B}")
    feed = Feed()
    expect = []

    def ld_figures(label):
        """What Loandrift itself says, from its operational tables (not its ledger)."""
        reps = q("""SELECT paid_amount, penalty_paid, payment_method FROM loandrift.ld_repayments
                    WHERE loan_id = %s AND delete_status = 'NOT_DELETED'""", (LID,))
        total = approved + interest
        principal_paid = interest_paid = penalties = Decimal("0")
        for r in reps:
            i = D(D(r["paid_amount"]) * interest / total)
            interest_paid += i
            principal_paid += D(r["paid_amount"]) - i
            penalties += D(r["penalty_paid"])
        status = q("SELECT status FROM loandrift.ld_loan_details WHERE id = %s", (LID,))[0]["status"]
        outstanding = Decimal("0") if status == "WRITTEN_OFF" else approved - principal_paid
        wo = q("""SELECT principal_amount FROM loandrift.ld_loan_write_offs WHERE loan_id = %s AND status = 'APPROVED'""", (LID,))
        rec = q("""SELECT coalesce(sum(amount), 0) AS s FROM loandrift.ld_loan_write_off_recoveries WHERE loan_id = %s""", (LID,))[0]["s"]
        figures = {
            "label": label, "after_events": len(feed.all),
            "loans_receivable": str(outstanding),
            "interest_income": str(interest_paid),
            "penalty_income": str(penalties),
            "fee_income": str(fees),
            "written_off": str(D(wo[0]["principal_amount"]) if wo else Decimal("0")),
            "recovered": str(D(rec)),
        }
        check(f"{label}: Loans receivable as published = Loandrift's outstanding principal",
              feed.by_key["LOANS_RECEIVABLE"], outstanding)
        check(f"{label}: interest income as published = Loandrift's interest collected", -feed.by_key["INTEREST_INCOME"], interest_paid)
        check(f"{label}: penalty income as published = Loandrift's penalties collected", -feed.by_key["PENALTY_INCOME"], penalties)
        check(f"{label}: fee income as published = the loan's charges", -feed.by_key["PROCESSING_FEE_INCOME"], fees)
        figures["cash"] = {k: str(v) for k, v in sorted(feed.by_key.items()) if k in ("CASH", "BANK", "MOBILE_MONEY") and v != 0}
        expect.append(figures)

    # ---------------------------------------------------------------- 0. a disbursement that fails
    print("0. a disbursement that fails after Loandrift's journal is written")
    real_post = AccountingService.post_safely

    def failing(cursor, *a, **k):
        entry = real_post(cursor, *a, **k)
        if k.get("source_type") == "EXPENSE":
            raise RuntimeError("simulated failure after the ledger was written")
        return entry
    AccountingService.post_safely = staticmethod(failing)
    r = CapturingService.disburse_loan(DisburseLoanServiceWriteDto(loan_id=LID, mode="MOBILE_MONEY", note="test"), *S, U)
    AccountingService.post_safely = staticmethod(real_post)
    check("0: the disbursement failed", r.success, False)
    check("0: the loan is still approved", q("SELECT status FROM loandrift.ld_loan_details WHERE id = %s", (LID,))[0]["status"], "APPROVED")
    step(feed, "0", [])

    # ---------------------------------------------------------------- 1. disbursement + charges
    print("1. disburse by mobile money")
    r = CapturingService.disburse_loan(DisburseLoanServiceWriteDto(loan_id=LID, mode="MOBILE_MONEY", note="test"), *S, U)
    check("1: disbursed", r.success, True)
    ev = step(feed, "1", ["ld.loan_disbursed", "ld.loan_charges_collected"])
    p = ev["ld.loan_disbursed"]["payload"]
    check("1: loan number, client party, currency, date", (p["document_number"], p["loan_number"], p["party_id"], p["currency"], p["document_type"]),
          (LOAN_REF, LOAN_REF, party, "GHS", "LOAN"))
    check("1: amount = principal", p["amount"], str(approved))
    ld_figures("after disbursement")

    # ---------------------------------------------------------------- 2. a penalty, then a partial repayment
    print("2. a 50.00 late-payment penalty is charged (nightly job), then 1,000.00 cash is paid")
    q("""INSERT INTO loandrift.ld_penalties (tenant_id, id, org_id, bus_id, loc_id, loan_id, client_id, penalty_type,
            penalty_amount, outstanding_amount, status, due_date, days_overdue, trigger, cdatetime)
         VALUES (%s, 'pen-ld-acc-test', %s, %s, %s, %s, %s, 'LATE_PAYMENT', 50, 50, 'OUTSTANDING', current_date::text, 3, 'BATCH_JOB', now())""",
      (T, O, B, L, LID, CID))
    step(feed, "2a (penalty charged: Loandrift posts penalties when paid)", [])
    r = RepaymentsService.create_repayment(CreateRepaymentServiceWriteDto(loan_id=LID, paid_amount=Decimal("1000"), payment_method="CASH"), *S, U)
    check("2: repaid", r.success, True)
    ev = step(feed, "2", ["ld.repayment_received"])
    p = ev["ld.repayment_received"]["payload"]
    rep1 = q("SELECT id, penalty_paid, paid_amount FROM loandrift.ld_repayments WHERE loan_id = %s ORDER BY cdatetime DESC LIMIT 1", (LID,))[0]
    check("2: penalties first (50.00), the rest to the loan", (D(rep1["penalty_paid"]), D(rep1["paid_amount"])), (Decimal("50.00"), Decimal("950.00")))
    i1 = D(Decimal("950") * interest / (approved + interest))
    by = {l["account_key"]: (l["debit"], l["credit"]) for l in p["lines"]}
    check("2: Dr cash 1,000 / Cr penalty 50 / Cr interest / Cr principal",
          (by.get("CASH"), by.get("PENALTY_INCOME"), by.get("INTEREST_INCOME"), by.get("LOANS_RECEIVABLE")),
          (("1000.00", "0.00"), ("0.00", "50.00"), ("0.00", str(i1)), ("0.00", str(Decimal("950.00") - i1))))
    check("2: receipt number", p["document_number"], "RCP-" + rep1["id"].replace("-", "")[-8:].upper())
    ld_figures("after a partial repayment")

    # ---------------------------------------------------------------- 3. another repayment, reversed
    print("3. 2,000.00 by bank transfer, then reversed")
    r = RepaymentsService.create_repayment(CreateRepaymentServiceWriteDto(loan_id=LID, paid_amount=Decimal("2000"), payment_method="BANK_TRANSFER"), *S, U)
    check("3: repaid", r.success, True)
    step(feed, "3a", ["ld.repayment_received"])
    rep2 = q("SELECT id FROM loandrift.ld_repayments WHERE loan_id = %s ORDER BY cdatetime DESC LIMIT 1", (LID,))[0]["id"]
    ld_figures("after a second repayment")
    r = RepaymentActions.reverse(rep2, "Bounced transfer", *S, U)
    check("3: reversed", r.success, True)
    ev = step(feed, "3b", ["ld.repayment_reversed"])
    p = ev["ld.repayment_reversed"]["payload"]
    check("3: the reversal names what it reverses", (p["reversal"], bool(p["reverses_entry_id"]), p["document_type"]), (True, True, "REPAYMENT"))
    ld_figures("after the reversal")

    # ---------------------------------------------------------------- 4. write off, then recover
    print("4. write the loan off, then recover 100.00 in cash")
    r = WriteOffs.request(LID, "Client relocated, unreachable", None, S, U, can_approve=True)
    check("4: write-off requested", r.success, True)
    wo = q("SELECT id, status FROM loandrift.ld_loan_write_offs WHERE loan_id = %s ORDER BY requested_at DESC LIMIT 1", (LID,))[0]
    if wo["status"] == "PENDING":
        step(feed, "4a (requested, not yet approved)", [])
        r = WriteOffs.decide(wo["id"], True, "Agreed", S, U2)
        check("4: write-off approved", r.success, True)
    ev = step(feed, "4", ["ld.loan_written_off"])
    ld_figures("after the write-off")
    r = WriteOffs.recover(wo["id"], Decimal("100"), "CASH", None, "Part recovered", None, S, U)
    check("4: recovery recorded", r.success, True)
    step(feed, "4b", ["ld.write_off_recovered"])
    ld_figures("after a recovery")

    # ---------------------------------------------------------------- 5. savings
    print("5. savings: 300.00 deposited by mobile money, 100.00 withdrawn in cash")
    acct = q("SELECT client_id FROM loandrift.ld_savings_accounts WHERE id = %s", (SAVINGS,))[0]
    r = SavingsService.deposit(SavingsDepositWriteDto(savings_id=SAVINGS, client_id=acct["client_id"], amount=Decimal("300"), payment_method="MOMO"), *S, U)
    check("5: deposited", r.success, True)
    ev = step(feed, "5a", ["ld.savings_deposit"])
    check("5: savings document is the account number", ev["ld.savings_deposit"]["payload"]["document_type"], "SAVINGS")
    r = SavingsService.withdraw(SavingsWithdrawalWriteDto(savings_id=SAVINGS, client_id=acct["client_id"], amount=Decimal("100"), payment_method="CASH"), *S, U)
    check("5: withdrawn", r.success, True)
    step(feed, "5b", ["ld.savings_withdrawal"])
    check("5: client savings as published = deposits - withdrawals", -feed.by_key["SAVINGS_LIABILITY"], Decimal("200.00"))

    # ---------------------------------------------------------------- 6. Loandrift's own bookkeeping is not published
    print("6. a manual journal in Loandrift")
    with DatabaseManager.transaction() as cur:
        AccountingService.post(cur, *S, lines=[Line("OPERATING_EXPENSE", debit=10), Line("CASH", credit=10)],
                               entry_date=None, source_type="MANUAL", description="Petty cash", created_by=U)
    step(feed, "6", [])
    ld_figures("at the end")

    # ---------------------------------------------------------------- 7. nothing is published twice
    print("7. every Loandrift journal since the start was published at most once")
    dup = q("""SELECT subject_id, count(*) FROM core_platform.cp_events WHERE source_app = 'loandrift' AND kind <> 'ld.posting_error'
               GROUP BY 1 HAVING count(*) > 1""")
    check("7: no entry published twice", dup, [])

    out = ACC / "tests" / "Accounting.Api.Tests" / "Fixtures" / "Postings" / "ld_events.json"
    out.write_text(json.dumps({
        "source": "tvs-sqlscript scripts/test_ld_accounting_events.py (Loandrift's real service code, migration 20261019-41)",
        "events": [{"kind": e["kind"], "subject_id": e["subject_id"], "payload": e["payload"]} for e in feed.all],
        "expect": expect,
    }, indent=1, default=str) + "\n")
    print(f"\nwrote {len(feed.all)} events to {out}")
    print(f"{passes} passed, {len(fails)} failed")
    for f in fails:
        print("  FAILED:", f)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
