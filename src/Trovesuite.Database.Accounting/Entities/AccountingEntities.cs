namespace Trovesuite.Database.Accounting.Entities;

/// <summary>One row per tenant/org — base currency, prefixes, FX accounts, defaults.</summary>
public class AccOrgSettings
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string LegalName { get; set; } = "";
    public string TradingName { get; set; } = "";
    public string Tin { get; set; } = "";
    public string Country { get; set; } = "GH";
    public string BaseCurrency { get; set; } = "GHS";
    public int FiscalYearStartMonth { get; set; } = 1;
    public string FiscalYearStart { get; set; } = "01-01";
    public string Address { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public decimal ApprovalThreshold { get; set; } = 50000;
    public bool RequireApprovalForManualJournals { get; set; } = true;
    public bool BlockPostingToLockedPeriods { get; set; } = true;
    public DateOnly? ConversionDate { get; set; }
    public string JournalPrefix { get; set; } = "JE-";
    public string InvoicePrefix { get; set; } = "INV-";
    public string BillPrefix { get; set; } = "BILL-";
    public string? FxRealisedAccountId { get; set; }
    public string? FxUnrealisedAccountId { get; set; }
    public decimal FxRateTolerancePct { get; set; } = 2;
    public string? DefaultSalesAccountId { get; set; }
    public string? DefaultPurchaseAccountId { get; set; }
    public string? DefaultSalesTaxCodeId { get; set; }
    public string? DefaultPurchaseTaxCodeId { get; set; }
    public string? OpeningBalanceJournalId { get; set; }
    public bool SetupComplete { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccAccount
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Type { get; set; } = default!;
    public string Subtype { get; set; } = default!;
    public string? ParentId { get; set; }
    public bool IsGroup { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsControl { get; set; }
    public bool IsBank { get; set; }
    public string? Description { get; set; }
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccFiscalPeriod
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string Status { get; set; } = "OPEN";
    public int FiscalYear { get; set; }
    public DateTimeOffset? LockedAt { get; set; }
    public string? LockedById { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccJournalEntry
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public DateOnly Date { get; set; }
    public string Memo { get; set; } = default!;
    public string? Reference { get; set; }
    public string Status { get; set; } = "DRAFT";
    public string SourceType { get; set; } = "MANUAL";
    public string? SourceReference { get; set; }
    public string? SourceDocumentId { get; set; }
    public string? BranchId { get; set; }
    public DateTimeOffset? PostedAt { get; set; }
    public string? PostedById { get; set; }
    public string? ApprovedById { get; set; }
    public string? ReversalOfId { get; set; }
    public string? ReversedById { get; set; }
    public string? ReverseReason { get; set; }
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccJournalLine> Lines { get; set; } = [];
}

public class AccJournalLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string JournalId { get; set; } = default!;
    public int LineNo { get; set; }
    public string AccountId { get; set; } = default!;
    public string? Description { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public string? BranchId { get; set; }
    public string? CostCentreId { get; set; }
    public string? Currency { get; set; }
    public decimal? AmountFc { get; set; }

    public AccJournalEntry? Journal { get; set; }
}

public class AccDimension
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Kind { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccCurrency
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Symbol { get; set; } = default!;
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccTaxCode
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public decimal Rate { get; set; }
    public string Kind { get; set; } = default!;
    public string? OutputAccountId { get; set; }
    public string? InputAccountId { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccAccountingRule
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Event { get; set; } = default!;
    public string SourceId { get; set; } = default!;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public int PostingsCount { get; set; }
    public string SampleJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccAccountingRuleLine> Lines { get; set; } = [];
}

public class AccAccountingRuleLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string RuleId { get; set; } = default!;
    public int LineNo { get; set; }
    public string AccountId { get; set; } = default!;
    public string Side { get; set; } = default!;
    public string AmountBasis { get; set; } = default!;
    public string? Description { get; set; }

    public AccAccountingRule? Rule { get; set; }
}

/// <summary>Append-only product audit trail (not application request logs).</summary>
public class AccAuditEvent
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public DateTimeOffset OccurredAt { get; set; }
    public string Action { get; set; } = default!;
    public string EntityType { get; set; } = default!;
    public string EntityId { get; set; } = default!;
    public string? EntityLabel { get; set; }
    public string Summary { get; set; } = default!;
    public string? ActorId { get; set; }
    public string? ActorName { get; set; }
    public string? ChangesJson { get; set; }
}
