namespace Trovesuite.Database.Accounting.Entities;

// Recurring invoices and bills, fixed assets, budgets (migration RecurringAssetsBudgets). tvs-accounting-bk keeps the same
// model in Persistence/Entities/PlanningEntities.cs and Persistence/PlanningModel.cs.

/// <summary>A recurring invoice or bill: what to issue (party, lines, currency) and when (the schedule).</summary>
public class AccRecurringTemplate
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string Name { get; set; } = default!;
    /// <summary>INVOICE or BILL.</summary>
    public string Kind { get; set; } = default!;
    public string PartyId { get; set; } = default!;
    public string Currency { get; set; } = default!;
    public decimal ExchangeRate { get; set; } = 1;
    public string? BranchId { get; set; }
    public string? Notes { get; set; }
    /// <summary>Bills: the supplier's reference each bill gets, followed by the occurrence date.</summary>
    public string? SupplierReference { get; set; }
    public int PaymentTermsDays { get; set; }
    /// <summary>WEEKLY, MONTHLY, QUARTERLY, YEARLY or CUSTOM (every <see cref="IntervalCount"/> <see cref="IntervalUnit"/>).</summary>
    public string Frequency { get; set; } = "MONTHLY";
    public int IntervalCount { get; set; } = 1;
    /// <summary>DAY, WEEK, MONTH or YEAR.</summary>
    public string IntervalUnit { get; set; } = "MONTH";
    /// <summary>Month-based schedules: SAME_DAY (the start date's day), DAY_OF_MONTH or LAST_DAY.</summary>
    public string DayRule { get; set; } = "SAME_DAY";
    public int? DayOfMonth { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    /// <summary>How many documents in all; null runs until <see cref="EndDate"/> or for ever.</summary>
    public int? Occurrences { get; set; }
    public bool AutoApprove { get; set; }
    /// <summary>ACTIVE, PAUSED, ENDED (stopped by hand) or COMPLETED (schedule ran out).</summary>
    public string Status { get; set; } = "ACTIVE";
    /// <summary>Why the next document is waiting (a locked period, an inactive customer...); null when nothing is held.</summary>
    public string? HeldReason { get; set; }
    public DateOnly? HeldDate { get; set; }
    public DateOnly? NextRunDate { get; set; }
    public DateOnly? LastRunDate { get; set; }
    public int GeneratedCount { get; set; }
    /// <summary>The invoice or bill it was made from ("Make recurring"), when it was.</summary>
    public string? SourceDocumentId { get; set; }
    /// <summary>Custom-field values each document gets; values may hold period tokens ({period}, {date}, {seq}...).</summary>
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
    public List<AccRecurringTemplateLine> Lines { get; set; } = [];
}

public class AccRecurringTemplateLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TemplateId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public string TaxCodeId { get; set; } = default!;
    public string AccountId { get; set; } = default!;
    public AccRecurringTemplate? Template { get; set; }
}

/// <summary>One occurrence of a template: the document it produced, or why it was skipped. Unique per template and date.</summary>
public class AccRecurringRun
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TemplateId { get; set; } = default!;
    public DateOnly OccurrenceDate { get; set; }
    public int OccurrenceNo { get; set; }
    /// <summary>GENERATED or SKIPPED (missed while paused).</summary>
    public string Status { get; set; } = "GENERATED";
    public string? DocumentId { get; set; }
    public string? DocumentNumber { get; set; }
    public string? Note { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string? CreatedById { get; set; }
}

/// <summary>A kind of fixed asset and the accounts its assets post to.</summary>
public class AccAssetCategory
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    /// <summary>STRAIGHT_LINE or REDUCING_BALANCE: the default for new assets.</summary>
    public string Method { get; set; } = "STRAIGHT_LINE";
    public int UsefulLifeMonths { get; set; } = 60;
    /// <summary>Reducing balance: the annual rate in percent (e.g. 25).</summary>
    public decimal? ReducingRate { get; set; }
    public string AssetAccountId { get; set; } = default!;
    public string AccumulatedAccountId { get; set; } = default!;
    public string ExpenseAccountId { get; set; } = default!;
    public string DisposalAccountId { get; set; } = default!;
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccFixedAsset
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string CategoryId { get; set; } = default!;
    public decimal Cost { get; set; }
    public decimal ResidualValue { get; set; }
    public DateOnly AcquisitionDate { get; set; }
    public DateOnly InServiceDate { get; set; }
    public string Method { get; set; } = "STRAIGHT_LINE";
    public int UsefulLifeMonths { get; set; }
    public decimal? ReducingRate { get; set; }
    public string? SupplierId { get; set; }
    public string? BillId { get; set; }
    public string? Location { get; set; }
    public string? SerialNumber { get; set; }
    /// <summary>The acquisition journal (Dr asset cost, Cr <see cref="FundingAccountId"/>), when the register posted one.</summary>
    public string? AcquisitionJournalId { get; set; }
    public string? FundingAccountId { get; set; }
    /// <summary>ACTIVE, DISPOSED or WRITTEN_OFF.</summary>
    public string Status { get; set; } = "ACTIVE";
    public DateOnly? DisposalDate { get; set; }
    public decimal? DisposalProceeds { get; set; }
    public string? DisposalAccountId { get; set; }
    public decimal? DisposalGainLoss { get; set; }
    public string? DisposalJournalId { get; set; }
    public string? DisposalReason { get; set; }
    /// <summary>Depreciation charged before the books began, brought forward in its opening journal.</summary>
    public decimal OpeningAccumulatedDepreciation { get; set; }
    /// <summary>The day the books began, for an asset acquired before it.</summary>
    public DateOnly? OpeningDate { get; set; }
    public string? OpeningJournalId { get; set; }
    /// <summary>Depreciation recalculated from this month: BasisAmount over BasisMonths (a revaluation or an opening figure).</summary>
    public DateOnly? BasisMonth { get; set; }
    public decimal? BasisAmount { get; set; }
    public int? BasisMonths { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

/// <summary>One month's depreciation of one asset, posted in a run's journal. Unique per asset and month.</summary>
/// <summary>A revaluation of one asset (IAS 16, elimination method) or the transfer of its surplus on disposal.</summary>
public class AccAssetRevaluation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string AssetId { get; set; } = default!;
    /// <summary>REVALUATION or SURPLUS_TRANSFER.</summary>
    public string Kind { get; set; } = "REVALUATION";
    public DateOnly Date { get; set; }
    public decimal CostBefore { get; set; }
    public decimal AccumulatedEliminated { get; set; }
    public decimal CarryingBefore { get; set; }
    public decimal FairValue { get; set; }
    public decimal SurplusChange { get; set; }
    public decimal PnlChange { get; set; }
    public string? SurplusAccountId { get; set; }
    public string? PnlAccountId { get; set; }
    public int RemainingMonths { get; set; }
    /// <summary>Null when the revaluation had nothing to post.</summary>
    public string? JournalId { get; set; }
    public string? Notes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string? CreatedById { get; set; }
}

public class AccAssetDepreciation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string AssetId { get; set; } = default!;
    /// <summary>The first day of the month depreciated.</summary>
    public DateOnly PeriodMonth { get; set; }
    public decimal Amount { get; set; }
    public string JournalId { get; set; } = default!;
    /// <summary>The run that posted it; null for the disposal month (posted by the disposal journal).</summary>
    public string? RunId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>One depreciation journal: a month of every asset's depreciation in one business's books.</summary>
public class AccDepreciationRun
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    /// <summary>The first day of the month the journal is dated in (its last day).</summary>
    public DateOnly PeriodMonth { get; set; }
    public string JournalId { get; set; } = default!;
    public decimal Total { get; set; }
    public int AssetCount { get; set; }
    /// <summary>MANUAL or AUTOMATIC.</summary>
    public string Trigger { get; set; } = "MANUAL";
    /// <summary>Months of locked periods whose depreciation was caught up in this journal.</summary>
    public string? CaughtUp { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string? CreatedById { get; set; }
}

/// <summary>A budget for one fiscal year: a version, draft or approved (one approved per year).</summary>
public class AccBudget
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    /// <summary>fy_&lt;start year&gt;, as GET /fiscal-years/list names years.</summary>
    public string FiscalYearId { get; set; } = default!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public int Version { get; set; } = 1;
    /// <summary>DRAFT, APPROVED or SUPERSEDED.</summary>
    public string Status { get; set; } = "DRAFT";
    public string? Notes { get; set; }
    public DateTimeOffset? ApprovedAt { get; set; }
    public string? ApprovedById { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
    public List<AccBudgetLine> Lines { get; set; } = [];
}

/// <summary>One account's (and optionally one dimension's) twelve monthly amounts, in the year's month order.</summary>
public class AccBudgetLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string BudgetId { get; set; } = default!;
    public string AccountId { get; set; } = default!;
    public string? DimensionId { get; set; }
    public decimal M01 { get; set; }
    public decimal M02 { get; set; }
    public decimal M03 { get; set; }
    public decimal M04 { get; set; }
    public decimal M05 { get; set; }
    public decimal M06 { get; set; }
    public decimal M07 { get; set; }
    public decimal M08 { get; set; }
    public decimal M09 { get; set; }
    public decimal M10 { get; set; }
    public decimal M11 { get; set; }
    public decimal M12 { get; set; }
    public AccBudget? Budget { get; set; }
}
