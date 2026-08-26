namespace Trovesuite.Database.MyStoreGuard.Entities;

/// <summary>
/// One rule answering, for some slice of the catalogue at some set of locations:
/// may this be sold on installment, and if so on what terms?
///
/// Deliberately has NO priority column and no "stops other policies" flag.
/// Resolution is: any matching DENY denies the item; otherwise the most SPECIFIC
/// matching ALLOW supplies the terms (SKU beats PRODUCT beats TAG beats LABEL
/// beats CATEGORY beats BRAND beats ALL_PRODUCTS). That makes the allow/deny
/// verdict order-independent, so a priority number would have nothing to order.
///
/// Contrast msg_return_policies and msg_pricing_rules, which both carry a
/// priority AND a stops_other flag — the flag is dead in both, because their
/// resolvers take a single winner and "stop the others" cannot then do anything.
/// </summary>
public class InstallmentPolicy
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;

    public string Name { get; set; } = default!;
    public string? Description { get; set; }

    // ---- A. verdict ----
    public string PolicyMode { get; set; } = "ALLOW";

    // ---- B. targeting (locations live in InstallmentPolicyLocation) ----
    public string PolicyTargetType { get; set; } = default!;
    public string? PolicyTargetId { get; set; }

    /// <summary>
    /// What the attached product list means: ALL ignores it, INCLUDE narrows
    /// the policy to only those products, EXCLUDE holds it back from them.
    ///
    /// A second dial rather than another target type, because it answers a
    /// different question. The target says what KIND of thing this policy is
    /// about; the list says which of them, and a shop usually wants "this
    /// category, except the two lines we never finance".
    /// </summary>
    public string ProductScope { get; set; } = "ALL";
    /// <summary>
    /// The band is tested against the LINE TOTAL of the item this policy
    /// matched, not the cart total. A policy targets one product, so an
    /// unrelated item in the same basket must not change whether it applies.
    /// </summary>
    public decimal? MinItemAmount { get; set; }
    public decimal? MaxItemAmount { get; set; }

    // ---- C. down payment ----
    public bool InitialPaymentRequired { get; set; } = true;
    public string? InitialPaymentFormula { get; set; }
    public decimal? InitialPaymentMin { get; set; }
    public decimal? InitialPaymentMax { get; set; }

    // ---- D. plan (frequency/term options live in InstallmentPlanOption) ----
    /// <summary>
    /// Null on a DENY policy, which never prices anything. It used to be
    /// NOT NULL, so a deny stored the string "0" — a sentinel that then looked
    /// like a formula to anything reading the row back.
    /// </summary>
    public string? InstallmentFormula { get; set; }
    public int FirstDueOffsetDays { get; set; }
    public bool AllowCustomStartDate { get; set; }
    public string? EarlySettlementFormula { get; set; }

    // ---- E. approval (approver list lives in InstallmentPolicyApprover) ----
    public bool ApprovalRequired { get; set; }
    public string ApprovalMode { get; set; } = "ANY";
    public decimal? ApprovalThresholdAmount { get; set; }
    public int? ApprovalMinTermCount { get; set; }
    public bool ApprovalOnMissingGuarantor { get; set; }
    public bool ApprovalOnCustomerArrears { get; set; }
    public bool ReminderEnabled { get; set; }
    public int ReminderIntervalMinutes { get; set; } = 1440;
    public int ReminderMaxCount { get; set; } = 5;

    // ---- E2. money taken before a decision exists ----
    //
    // Off by default, and deliberately so: a deposit taken before approval must
    // be given back if the answer is no, and money owed to a customer that
    // nobody is chasing is how cash quietly goes missing. Turning this on is
    // what brings the refund settings below into play.
    public bool AllowPaymentBeforeApproval { get; set; }

    /// <summary>
    /// How often to chase an unreturned refund, and how many times. Zero means
    /// never stop — unlike an approval, which can sit unanswered, money owed to
    /// a customer has no acceptable resting state.
    /// </summary>
    public bool RefundReminderEnabled { get; set; } = true;
    public int RefundReminderIntervalMinutes { get; set; } = 1440;
    public int RefundReminderMaxCount { get; set; }

    // ---- F. penalty ----
    public bool PenaltyEnabled { get; set; }
    public string? PenaltyKind { get; set; }
    public decimal? PenaltyValue { get; set; }
    public string? PenaltyBasis { get; set; }
    public int PenaltyGraceDays { get; set; }
    public string PenaltyRecurrence { get; set; } = "ONCE_PER_PERIOD";
    public decimal? PenaltyMaxCap { get; set; }

    // ---- security / fulfilment ----
    /// <summary>
    /// Refuse a new plan outright to a customer already behind on another one.
    ///
    /// Distinct from ApprovalOnCustomerArrears, which asks a human to look:
    /// this does not ask, it declines. A shop that keeps lending to someone who
    /// is not paying is not being kind to them.
    /// </summary>
    public bool BlockWhenCustomerOwes { get; set; }
    public int GuarantorsRequiredMin { get; set; }
    public bool GuarantorIdDocumentRequired { get; set; }
    public string ReleaseGoodsOn { get; set; } = "FULL_PAYMENT";

    public bool IsActive { get; set; } = true;
    public DateTime? StartDatetime { get; set; }
    public DateTime? EndDatetime { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

/// <summary>
/// Which locations a policy applies at. NO rows means every location — that
/// keeps the common case a single policy row instead of one per branch.
///
/// This is a scope, ANDed on top of the product target, not another target
/// type. msg_return_policies folds LOCATION into its target enum, which makes
/// "this brand, but only at East Legon" unexpressible.
/// </summary>
/// <summary>
/// A named list of products a policy is narrowed to, or held back from.
///
/// Sits ON TOP of the target, it does not replace it. A policy still targets a
/// category or the whole shop; this says "…but only these ten", or "…except
/// these three". Without it a shop wanting a policy for most of a category had
/// to either write one policy per product or add a DENY policy alongside, and
/// neither reads as what they meant.
///
/// No rows means the list is not in use, exactly as with locations.
/// </summary>
public class InstallmentPolicyProduct
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class InstallmentPolicyLocation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// One frequency a policy offers, plus the exact term counts allowed for it —
/// e.g. MONTHLY with {3, 6, 12}. A cashier picks from the list; 200 is refused
/// because it is not in the array, not because it exceeds some maximum.
/// A policy may offer several frequencies.
/// </summary>
public class InstallmentPlanOption
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    public string Frequency { get; set; } = default!;
    /// <summary>Number of PERIODS, not days. WEEKLY {4,8,12} = 4, 8 or 12 weeks.</summary>
    public int[] AllowedTerms { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// A named number the policy's formulas can reference by name — interest_rate,
/// admin_fee, min_down_pct. This is what lets a formula read like a rate to
/// whoever configures it while staying arbitrary arithmetic underneath.
/// </summary>
public class InstallmentPolicyVariable
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    /// <summary>Formula identifier: letters, digits, underscore; no leading digit.</summary>
    public string VarName { get; set; } = default!;
    public decimal VarValue { get; set; }
    public string? Label { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// Who may declare that a refund has been handed back to the customer.
///
/// Separate from the approver list on purpose: approving a plan and handing
/// cash across a counter are different jobs, and a business may well want the
/// second done by someone who did not make the first decision. Nothing stops
/// the same person being on both lists.
/// </summary>
public class InstallmentPolicyRefundCloser
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    public string UserId { get; set; } = default!;
    public int DisplayOrder { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// Who may approve a plan created under this policy.
///
/// Holds cp_users.id, not an email address. msg_return_policies stores a JSONB
/// list of emails, which silently stops matching the moment a user changes
/// theirs; the address is looked up at send time instead.
/// </summary>
public class InstallmentPolicyApprover
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PolicyId { get; set; } = default!;
    public string UserId { get; set; } = default!;
    public int DisplayOrder { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}
