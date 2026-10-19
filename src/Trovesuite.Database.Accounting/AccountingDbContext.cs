using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Accounting.Entities;

namespace Trovesuite.Database.Accounting;

public class AccountingDbContext : DbContext
{
    public const string SchemaName = "accounting";

    public AccountingDbContext(DbContextOptions<AccountingDbContext> options) : base(options) { }

    public DbSet<AccOrgSettings> OrgSettings => Set<AccOrgSettings>();
    public DbSet<AccAccount> Accounts => Set<AccAccount>();
    public DbSet<AccFiscalPeriod> FiscalPeriods => Set<AccFiscalPeriod>();
    public DbSet<AccJournalEntry> JournalEntries => Set<AccJournalEntry>();
    public DbSet<AccJournalLine> JournalLines => Set<AccJournalLine>();
    public DbSet<AccDimension> Dimensions => Set<AccDimension>();
    public DbSet<AccCurrency> Currencies => Set<AccCurrency>();
    public DbSet<AccTaxCode> TaxCodes => Set<AccTaxCode>();
    public DbSet<AccAccountingRule> AccountingRules => Set<AccAccountingRule>();
    public DbSet<AccAccountingRuleLine> AccountingRuleLines => Set<AccAccountingRuleLine>();
    public DbSet<AccAuditEvent> AuditEvents => Set<AccAuditEvent>();
    public DbSet<AccCustomer> Customers => Set<AccCustomer>();
    public DbSet<AccSupplier> Suppliers => Set<AccSupplier>();
    public DbSet<AccSalesInvoice> SalesInvoices => Set<AccSalesInvoice>();
    public DbSet<AccSalesInvoiceLine> SalesInvoiceLines => Set<AccSalesInvoiceLine>();
    public DbSet<AccPurchaseBill> PurchaseBills => Set<AccPurchaseBill>();
    public DbSet<AccPurchaseBillLine> PurchaseBillLines => Set<AccPurchaseBillLine>();
    public DbSet<AccCreditNote> CreditNotes => Set<AccCreditNote>();
    public DbSet<AccCreditNoteLine> CreditNoteLines => Set<AccCreditNoteLine>();
    public DbSet<AccSupplierCredit> SupplierCredits => Set<AccSupplierCredit>();
    public DbSet<AccSupplierCreditLine> SupplierCreditLines => Set<AccSupplierCreditLine>();
    public DbSet<AccPayment> Payments => Set<AccPayment>();
    public DbSet<AccBankAccount> BankAccounts => Set<AccBankAccount>();
    public DbSet<AccBankStatementLine> BankStatementLines => Set<AccBankStatementLine>();
    public DbSet<AccExchangeRate> ExchangeRates => Set<AccExchangeRate>();
    public DbSet<AccFxRevaluation> FxRevaluations => Set<AccFxRevaluation>();
    public DbSet<AccFxRevaluationLine> FxRevaluationLines => Set<AccFxRevaluationLine>();
    public DbSet<AccCustomField> CustomFields => Set<AccCustomField>();
    public DbSet<AccDataSource> DataSources => Set<AccDataSource>();
    public DbSet<AccFieldMapping> FieldMappings => Set<AccFieldMapping>();
    public DbSet<AccImportBatch> ImportBatches => Set<AccImportBatch>();
    public DbSet<AccImportRecord> ImportRecords => Set<AccImportRecord>();
    public DbSet<AccPostingInbox> PostingInbox => Set<AccPostingInbox>();
    public DbSet<AccPostingAccount> PostingAccounts => Set<AccPostingAccount>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AccountingDbContext).Assembly);

        // The books are per BUSINESS: every row names the business it belongs to, never just the
        // organisation (a pharmacy and a hardware shop in one organisation keep separate books).
        foreach (var entity in modelBuilder.Model.GetEntityTypes())
        {
            // Views (acc_customers / acc_suppliers over cp_parties) hold no constraints.
            if (entity.FindProperty("BusId") is null || entity.GetTableName() is null) continue;
            entity.AddCheckConstraint($"ck_{entity.GetTableName()}_bus_id", "btrim(bus_id) <> ''");
        }

        base.OnModelCreating(modelBuilder);
    }
}
