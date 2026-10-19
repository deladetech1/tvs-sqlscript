namespace Trovesuite.Database.Accounting.Entities;

/// <summary>One row per business (its books) — base currency, prefixes, FX accounts, defaults.</summary>
public class AccOrgSettings
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    // Who the business is (name, legal name, country, address, email, phone) is Core Platform's
    // (cp_businesses / cp_organizations), read per request. These columns are no longer written and are
    // kept, nullable, only so the rows written before still read (migration IdentityFromCorePlatform).
    public string? LegalName { get; set; }
    public string? TradingName { get; set; }
    public string Tin { get; set; } = "";
    public string? Country { get; set; }
    public string BaseCurrency { get; set; } = "GHS";
    public int FiscalYearStartMonth { get; set; } = 1;
    public string FiscalYearStart { get; set; } = "01-01";
    public string? Address { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    /// <summary>IANA zone the business keeps its day in; empty means the tenant's zone in Core Platform, else UTC.</summary>
    public string TimeZone { get; set; } = "";
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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
    public string BusId { get; set; } = default!;
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

public class AccCustomer
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string City { get; set; } = "";
    public string? Tin { get; set; }
    public int PaymentTermsDays { get; set; } = 30;
    public decimal CreditLimit { get; set; }
    public string Status { get; set; } = "ACTIVE";
    public string? ExternalReference { get; set; }
    public string Source { get; set; } = "MANUAL";
    public string Currency { get; set; } = "GHS";
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
    /// <summary>The app the record was first entered in (cp_parties.source_app); read-only here.</summary>
    public string SourceApp { get; set; } = "";
}

public class AccSupplier
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string City { get; set; } = "";
    public string? Tin { get; set; }
    public int PaymentTermsDays { get; set; } = 30;
    public decimal CreditLimit { get; set; }
    public string Status { get; set; } = "ACTIVE";
    public string? ExternalReference { get; set; }
    public string Source { get; set; } = "MANUAL";
    public string Currency { get; set; } = "GHS";
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
    /// <summary>The app the record was first entered in (cp_parties.source_app); read-only here.</summary>
    public string SourceApp { get; set; } = "";
}

public class AccSalesInvoice
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string CustomerId { get; set; } = default!;
    public DateOnly IssueDate { get; set; }
    public DateOnly DueDate { get; set; }
    public string State { get; set; } = "DRAFT";
    public string Currency { get; set; } = "GHS";
    public decimal ExchangeRate { get; set; } = 1;
    public decimal AmountPaid { get; set; }
    public decimal AmountPaidBase { get; set; }
    public string? JournalId { get; set; }
    public string? BranchId { get; set; }
    public string? Notes { get; set; }
    public string SourceType { get; set; } = "MANUAL";
    public string? SourceReference { get; set; }
    public string? SourceDocumentId { get; set; }
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccSalesInvoiceLine> Lines { get; set; } = [];
}

public class AccSalesInvoiceLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string InvoiceId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public string TaxCodeId { get; set; } = default!;
    public string AccountId { get; set; } = default!;

    public AccSalesInvoice? Invoice { get; set; }
}

public class AccPurchaseBill
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string SupplierId { get; set; } = default!;
    public string SupplierReference { get; set; } = default!;
    public DateOnly IssueDate { get; set; }
    public DateOnly DueDate { get; set; }
    public string State { get; set; } = "DRAFT";
    public string Currency { get; set; } = "GHS";
    public decimal ExchangeRate { get; set; } = 1;
    public decimal AmountPaid { get; set; }
    public decimal AmountPaidBase { get; set; }
    public string? JournalId { get; set; }
    public string? BranchId { get; set; }
    public string? Notes { get; set; }
    public string SourceType { get; set; } = "MANUAL";
    public string? SourceReference { get; set; }
    public string? SourceDocumentId { get; set; }
    public string CustomFieldsJson { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccPurchaseBillLine> Lines { get; set; } = [];
}

public class AccPurchaseBillLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string BillId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public string TaxCodeId { get; set; } = default!;
    public string AccountId { get; set; } = default!;

    public AccPurchaseBill? Bill { get; set; }
}

public class AccCreditNote
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string PartyId { get; set; } = default!;
    public string DocumentId { get; set; } = default!;
    public DateOnly Date { get; set; }
    public string State { get; set; } = "APPROVED";
    public string Reason { get; set; } = default!;
    public string Currency { get; set; } = "GHS";
    public decimal ExchangeRate { get; set; } = 1;
    public decimal BaseAmount { get; set; }
    public string? JournalId { get; set; }
    public string? BranchId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccCreditNoteLine> Lines { get; set; } = [];
}

public class AccCreditNoteLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string CreditNoteId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public string TaxCodeId { get; set; } = default!;
    public string AccountId { get; set; } = default!;

    public AccCreditNote? CreditNote { get; set; }
}

public class AccSupplierCredit
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string PartyId { get; set; } = default!;
    public string DocumentId { get; set; } = default!;
    public DateOnly Date { get; set; }
    public string State { get; set; } = "APPROVED";
    public string Reason { get; set; } = default!;
    public string? SupplierReference { get; set; }
    public string Currency { get; set; } = "GHS";
    public decimal ExchangeRate { get; set; } = 1;
    public decimal BaseAmount { get; set; }
    public string? JournalId { get; set; }
    public string? BranchId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccSupplierCreditLine> Lines { get; set; } = [];
}

public class AccSupplierCreditLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string SupplierCreditId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public string TaxCodeId { get; set; } = default!;
    public string AccountId { get; set; } = default!;

    public AccSupplierCredit? SupplierCredit { get; set; }
}

/// <summary>Customer receipts and supplier payments. Direction is RECEIPT or PAYMENT.</summary>
public class AccPayment
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Direction { get; set; } = default!;
    public string Number { get; set; } = default!;
    public string PartyId { get; set; } = default!;
    public string DocumentId { get; set; } = default!;
    public DateOnly Date { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "GHS";
    public decimal ExchangeRate { get; set; } = 1;
    public decimal BaseAmount { get; set; }
    public decimal FxGainLoss { get; set; }
    public string Method { get; set; } = default!;
    public string BankAccountId { get; set; } = default!;
    public string? Reference { get; set; }
    public string? JournalId { get; set; }
    public string State { get; set; } = "POSTED";
    public string? VoidReason { get; set; }
    public DateTimeOffset? VoidedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccBankAccount
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Bank { get; set; } = default!;
    public string AccountNumber { get; set; } = default!;
    public string GlAccountId { get; set; } = default!;
    public string Currency { get; set; } = "GHS";
    public decimal StatementBalance { get; set; }
    public DateOnly StatementDate { get; set; }
    public DateTimeOffset? LastReconciledAt { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    /// <summary>Latest statement import, kept so it can be undone (jsonb).</summary>
    public string? LastImport { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccBankStatementLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string BankAccountId { get; set; } = default!;
    public DateOnly Date { get; set; }
    public string Description { get; set; } = default!;
    public decimal Amount { get; set; }
    public string Status { get; set; } = "UNMATCHED";
    public string? MatchedJournalId { get; set; }
    public string? SuggestedJournalId { get; set; }
    public string? Reference { get; set; }
    public string? ImportId { get; set; }
    /// <summary><c>FEED</c> or <c>FILE</c>.</summary>
    public string Source { get; set; } = "FEED";
    public string? ExcludeReason { get; set; }
    public DateTimeOffset? ReconciledAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccExchangeRate
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string CurrencyCode { get; set; } = default!;
    public DateOnly Date { get; set; }
    public decimal Rate { get; set; }
    public string Source { get; set; } = "MANUAL";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccFxRevaluation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PeriodId { get; set; } = default!;
    public DateOnly AsAt { get; set; }
    public string RatesJson { get; set; } = "{}";
    public decimal NetDifference { get; set; }
    public string JournalId { get; set; } = default!;
    public string ReversalJournalId { get; set; } = default!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccFxRevaluationLine> Lines { get; set; } = [];
}

public class AccFxRevaluationLine
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string RevaluationId { get; set; } = default!;
    public string Kind { get; set; } = default!;
    public string Currency { get; set; } = default!;
    public string Label { get; set; } = default!;
    public string AccountId { get; set; } = default!;
    public decimal AmountFc { get; set; }
    public decimal CarryingBase { get; set; }
    public decimal Rate { get; set; }
    public decimal RevaluedBase { get; set; }
    public decimal Difference { get; set; }

    public AccFxRevaluation? Revaluation { get; set; }
}

public class AccCustomField
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Entity { get; set; } = default!;
    public string Key { get; set; } = default!;
    public string Label { get; set; } = default!;
    public string Type { get; set; } = default!;
    public string Scope { get; set; } = "FINANCIAL";
    public string OptionsJson { get; set; } = "[]";
    public bool Required { get; set; }
    public string? Description { get; set; }
    public string? DefaultValue { get; set; }
    public bool IsActive { get; set; } = true;
    public int Position { get; set; }
    public bool ShowInList { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccDataSource
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Provider { get; set; } = default!;
    public string Kind { get; set; } = default!;
    public string Status { get; set; } = "NOT_CONNECTED";
    public string Description { get; set; } = "";
    public string SyncDirection { get; set; } = "INBOUND";
    public string Schedule { get; set; } = "Manual";
    public string EntitiesJson { get; set; } = "[]";
    public DateTimeOffset? LastRunAt { get; set; }
    public string? LastRunStatus { get; set; }
    public int RecordsSynced { get; set; }
    public int ErrorCount { get; set; }
    public string ConnectionJson { get; set; } = "{}";
    public string? StatusMessage { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AccFieldMapping
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string SourceId { get; set; } = default!;
    public string Entity { get; set; } = default!;
    public string SourceField { get; set; } = default!;
    public string TargetField { get; set; } = default!;
    public string Transform { get; set; } = "—";
    public bool Required { get; set; }
}

public class AccImportBatch
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string? SourceId { get; set; }
    public string Number { get; set; } = default!;
    public string Entity { get; set; } = "Journals";
    public string? FileName { get; set; }
    public string? JournalId { get; set; }
    public string Name { get; set; } = default!;
    public string Status { get; set; } = "NEEDS_REVIEW";
    public int RowsReceived { get; set; }
    public int RowsPosted { get; set; }
    public int RowsHeld { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }

    public List<AccImportRecord> Records { get; set; } = [];
}

public class AccImportRecord
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string BatchId { get; set; } = default!;
    public int LineNo { get; set; }
    public string Reference { get; set; } = "";
    public string Summary { get; set; } = "";
    public decimal Amount { get; set; }
    public string Status { get; set; } = "VALID";
    public string? Error { get; set; }
    public bool Posted { get; set; }
    public string PayloadJson { get; set; } = "{}";

    public AccImportBatch? Batch { get; set; }
}

/// <summary>
/// One event another Trovesuite app published (core_platform.cp_events) that the books post: a MyStoreGuard sale, a
/// payment, a return. Kept per business; one row per event (event_id), one journal per row. See docs/POSTINGS.md.
/// </summary>
public class AccPostingInbox
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    /// <summary>core_platform.cp_events.id, unique in this database.</summary>
    public long EventId { get; set; }
    public string SourceApp { get; set; } = default!;
    public string Kind { get; set; } = default!;
    public string SubjectId { get; set; } = default!;
    public string DocumentNumber { get; set; } = "";
    public DateOnly? DocumentDate { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "";
    public string PayloadJson { get; set; } = "{}";
    /// <summary>PENDING, POSTED, FAILED or SKIPPED.</summary>
    public string Status { get; set; } = "PENDING";
    public string? Reason { get; set; }
    public string? JournalId { get; set; }
    public int Attempts { get; set; }
    public DateTimeOffset EventAt { get; set; }
    public DateTimeOffset? LastAttemptAt { get; set; }
    public DateTimeOffset? PostedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

/// <summary>
/// Which account a posting role (SALES_REVENUE, CASH, TAX:&lt;tax id&gt;, ...) posts to in one business's books. A role
/// without a row posts to the standard account by code; a row is the business's own choice (Settings → Posting accounts).
/// </summary>
public class AccPostingAccount
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Role { get; set; } = default!;
    public string AccountId { get; set; } = default!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}
