using System.Text.Json;

namespace Trovesuite.Database.MyStoreGuard.Entities;

/// <summary>
/// A live installment plan: one per sale.
///
/// Everything the policy said at the moment of sale is SNAPSHOTTED here, and
/// the snapshot — not the policy row — is what later arithmetic reads. Loandrift
/// learned this the expensive way: without it, an admin editing an interest rate
/// silently rewrites every schedule ever generated under that policy.
/// </summary>
public class InstallmentPlan
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string SaleId { get; set; } = default!;
    /// <summary>Provenance only. Never re-read for maths — that is what PolicySnapshot is for.</summary>
    public string PolicyId { get; set; } = default!;
    /// <summary>The whole policy, parent and children, exactly as it was.</summary>
    public JsonDocument PolicySnapshot { get; set; } = default!;

    public string Status { get; set; } = "DRAFT";

    public string Frequency { get; set; } = default!;
    public int TermCount { get; set; }
    public DateOnly StartDate { get; set; }

    /// <summary>The goods, before any finance charge — equals msg_sales.total_amount.</summary>
    public decimal GoodsAmount { get; set; }
    public decimal InitialPayment { get; set; }
    /// <summary>GoodsAmount - InitialPayment.</summary>
    public decimal FinancedAmount { get; set; }
    /// <summary>One period, before the final row absorbs the rounding residual.</summary>
    public decimal InstallmentAmount { get; set; }
    /// <summary>InitialPayment + every scheduled row.</summary>
    public decimal TotalPayable { get; set; }
    /// <summary>TotalPayable - GoodsAmount. Interest income, NOT sales revenue.</summary>
    public decimal FinanceCharge { get; set; }

    public decimal AmountPaid { get; set; }
    /// <summary>
    /// Interest forgiven when a customer cleared the plan early.
    ///
    /// Held separately so the plan's own figures stay exactly as they were
    /// priced. Without it, amount_paid would sit permanently below
    /// total_payable and the plan would read as still owing the discount.
    /// A settled plan satisfies: amount_paid + settlement_discount = total_payable.
    /// </summary>
    public decimal SettlementDiscount { get; set; }
    public decimal PenaltiesAccrued { get; set; }
    public decimal PenaltiesPaid { get; set; }

    /// <summary>
    /// The resolved variable context and each intermediate value, so "how did we
    /// get GHS 397.71?" is answerable. Cheap now, impossible to retrofit once
    /// plans exist.
    /// </summary>
    public JsonDocument? FormulaTrace { get; set; }

    public DateTimeOffset? ApprovedAt { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTimeOffset? RejectedAt { get; set; }
    public string? RejectedBy { get; set; }
    public string? RejectionReason { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }
    public DateTimeOffset? DefaultedAt { get; set; }
    public DateTimeOffset? CancelledAt { get; set; }

    // ---- money owed back to the customer ----
    //
    // A plan rejected after money was taken leaves the shop holding cash that
    // is not theirs. REJECTED alone does not say that, and a status that does
    // not say it is a status nobody acts on — so the refund carries its own
    // state, and stays PENDING until a person says otherwise.
    //
    // NONE     nothing was taken, or nothing is owed
    // PENDING  money is held that belongs to the customer
    // RETURNED someone has handed it back and said so
    public string RefundStatus { get; set; } = "NONE";
    public decimal RefundAmount { get; set; }
    public DateTimeOffset? RefundClosedAt { get; set; }
    public string? RefundClosedBy { get; set; }
    public string? RefundNote { get; set; }

    /// <summary>Last time the chasers were emailed, and how often they have been.</summary>
    public DateTimeOffset? RefundRemindedAt { get; set; }
    public int RefundReminderCount { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

/// <summary>
/// One due date on a plan. This is the collections ledger: arrears, overdue
/// status and (from phase 5) penalties are all derived from these rows, never
/// stored independently of them.
/// </summary>
public class InstallmentScheduleRow
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PlanId { get; set; } = default!;

    /// <summary>1-based. Period N is the last one and carries the residual.</summary>
    public int PeriodNo { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal Amount { get; set; }
    public decimal PaidAmount { get; set; }
    public string Status { get; set; } = "PENDING";
    public DateTimeOffset? PaidAt { get; set; }
    /// <summary>
    /// When the customer was last nudged about this period. Stamped by the
    /// reminder job so a period is chased once, not every morning it stays due.
    /// </summary>
    public DateTimeOffset? RemindedAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Which schedule row a payment went to, and how much of it.
///
/// Payments themselves still live in msg_sale_payments — one payments ledger,
/// not two. This only records how each one was spread, so every cedi is
/// traceable to a period instead of being inferred from running totals.
/// </summary>
public class InstallmentAllocation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PlanId { get; set; } = default!;
    public string PaymentId { get; set; } = default!;

    /// <summary>
    /// Null for the initial payment, which is taken at the till and belongs to
    /// no scheduled period.
    /// </summary>
    public string? ScheduleId { get; set; }
    /// <summary>INITIAL, SCHEDULED or OVERPAYMENT.</summary>
    public string AllocationType { get; set; } = "SCHEDULED";
    public decimal Amount { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// One approver's decision on one plan.
///
/// A row per approver rather than a single decision on the plan, because
/// approval_mode = ALL needs to know who has and has not voted, and because
/// "who approved this, and when" is the question asked afterwards.
/// </summary>
public class InstallmentApproval
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PlanId { get; set; } = default!;

    /// <summary>cp_users.id, snapshotted from the policy's approver list at creation.</summary>
    public string UserId { get; set; } = default!;

    /// <summary>
    /// PENDING, APPROVED, REJECTED or SUPERSEDED. SUPERSEDED is what the other
    /// approvers get once an ANY-mode plan has been decided — it stops them
    /// being reminded about something already settled.
    /// </summary>
    public string Status { get; set; } = "PENDING";
    public string? Comment { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }

    /// <summary>Reminder bookkeeping. Phase 4's timer function reads these.</summary>
    public int ReminderCount { get; set; }
    public DateTimeOffset? LastRemindedAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}
