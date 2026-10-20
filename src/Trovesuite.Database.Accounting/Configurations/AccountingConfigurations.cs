using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Accounting.Entities;

namespace Trovesuite.Database.Accounting.Configurations;

internal static class AccountingTableExtensions
{
    internal static EntityTypeBuilder<T> ToAccountingTable<T>(this EntityTypeBuilder<T> b, string tableName)
        where T : class => b.ToTable(tableName, AccountingDbContext.SchemaName);
}

public sealed class AccOrgSettingsConfiguration : IEntityTypeConfiguration<AccOrgSettings>
{
    public void Configure(EntityTypeBuilder<AccOrgSettings> b)
    {
        b.ToAccountingTable("acc_org_settings");
        b.HasKey(x => x.Id);
        b.Property(x => x.FxRateTolerancePct).HasPrecision(8, 4);
        b.Property(x => x.ApprovalThreshold).HasPrecision(18, 2);
        b.Property(x => x.TimeZone).HasDefaultValue("");
        b.Property(x => x.AutoDepreciation).HasDefaultValue(false);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId }).IsUnique();
    }
}

public sealed class AccAccountConfiguration : IEntityTypeConfiguration<AccAccount>
{
    public void Configure(EntityTypeBuilder<AccAccount> b)
    {
        b.ToAccountingTable("acc_accounts");
        b.HasKey(x => x.Id);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.ParentId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Type });
    }
}

public sealed class AccFiscalPeriodConfiguration : IEntityTypeConfiguration<AccFiscalPeriod>
{
    public void Configure(EntityTypeBuilder<AccFiscalPeriod> b)
    {
        b.ToAccountingTable("acc_fiscal_periods");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StartDate, x.EndDate }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });
    }
}

public sealed class AccJournalEntryConfiguration : IEntityTypeConfiguration<AccJournalEntry>
{
    public void Configure(EntityTypeBuilder<AccJournalEntry> b)
    {
        b.ToAccountingTable("acc_journal_entries");
        b.HasKey(x => x.Id);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Date });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SourceType });
        // A journal posted from another app's event names the event (evt:<cp_events.id>): one journal per event.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SourceDocumentId }).IsUnique()
            .HasFilter("source_document_id LIKE 'evt:%'")
            .HasDatabaseName("ux_acc_journal_entries_event");
        b.HasMany(x => x.Lines).WithOne(x => x.Journal!).HasForeignKey(x => x.JournalId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccJournalLineConfiguration : IEntityTypeConfiguration<AccJournalLine>
{
    public void Configure(EntityTypeBuilder<AccJournalLine> b)
    {
        b.ToAccountingTable("acc_journal_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Debit).HasPrecision(18, 2);
        b.Property(x => x.Credit).HasPrecision(18, 2);
        b.Property(x => x.AmountFc).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.JournalId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.AccountId });
    }
}

public sealed class AccDimensionConfiguration : IEntityTypeConfiguration<AccDimension>
{
    public void Configure(EntityTypeBuilder<AccDimension> b)
    {
        b.ToAccountingTable("acc_dimensions");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Kind, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Kind });
    }
}

public sealed class AccCurrencyConfiguration : IEntityTypeConfiguration<AccCurrency>
{
    public void Configure(EntityTypeBuilder<AccCurrency> b)
    {
        b.ToAccountingTable("acc_currencies");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Code }).IsUnique();
    }
}

public sealed class AccTaxCodeConfiguration : IEntityTypeConfiguration<AccTaxCode>
{
    public void Configure(EntityTypeBuilder<AccTaxCode> b)
    {
        b.ToAccountingTable("acc_tax_codes");
        b.HasKey(x => x.Id);
        b.Property(x => x.Rate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Kind });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CoreTaxRateId }).IsUnique().HasFilter("core_tax_rate_id IS NOT NULL");
    }
}

public sealed class AccAccountingRuleConfiguration : IEntityTypeConfiguration<AccAccountingRule>
{
    public void Configure(EntityTypeBuilder<AccAccountingRule> b)
    {
        b.ToAccountingTable("acc_accounting_rules");
        b.HasKey(x => x.Id);
        b.Property(x => x.SampleJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SourceId, x.Event }).IsUnique();
        b.HasMany(x => x.Lines).WithOne(x => x.Rule!).HasForeignKey(x => x.RuleId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccAccountingRuleLineConfiguration : IEntityTypeConfiguration<AccAccountingRuleLine>
{
    public void Configure(EntityTypeBuilder<AccAccountingRuleLine> b)
    {
        b.ToAccountingTable("acc_accounting_rule_lines");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.RuleId });
    }
}

public sealed class AccAuditEventConfiguration : IEntityTypeConfiguration<AccAuditEvent>
{
    public void Configure(EntityTypeBuilder<AccAuditEvent> b)
    {
        b.ToAccountingTable("acc_audit_events");
        b.HasKey(x => x.Id);
        b.Property(x => x.ChangesJson).HasColumnType("jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.OccurredAt });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.EntityType, x.EntityId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Action });
    }
}

public sealed class AccCustomerConfiguration : IEntityTypeConfiguration<AccCustomer>
{
    public void Configure(EntityTypeBuilder<AccCustomer> b)
    {
        // A view of the business's shared records (core_platform.cp_parties) and Accounting's own fields
        // (acc_customer_settings), written through INSTEAD OF triggers: migrations/shared/20261019-37.
        // Mapped as a view so no EF migration ever alters it; the old table is acc_customers_legacy.
        b.ToView("acc_customers", AccountingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.CreditLimit).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb");
    }
}

public sealed class AccSupplierConfiguration : IEntityTypeConfiguration<AccSupplier>
{
    public void Configure(EntityTypeBuilder<AccSupplier> b)
    {
        // A view of the business's shared records (core_platform.cp_parties) and Accounting's own fields
        // (acc_supplier_settings), written through INSTEAD OF triggers: migrations/shared/20261019-37.
        // Mapped as a view so no EF migration ever alters it; the old table is acc_suppliers_legacy.
        b.ToView("acc_suppliers", AccountingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.CreditLimit).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb");
    }
}

public sealed class AccSalesInvoiceConfiguration : IEntityTypeConfiguration<AccSalesInvoice>
{
    public void Configure(EntityTypeBuilder<AccSalesInvoice> b)
    {
        b.ToAccountingTable("acc_sales_invoices");
        b.HasKey(x => x.Id);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.Property(x => x.AmountPaid).HasPrecision(18, 2);
        b.Property(x => x.AmountPaidBase).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CustomerId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.IssueDate });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.State });
        b.HasMany(x => x.Lines).WithOne(x => x.Invoice!).HasForeignKey(x => x.InvoiceId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccSalesInvoiceLineConfiguration : IEntityTypeConfiguration<AccSalesInvoiceLine>
{
    public void Configure(EntityTypeBuilder<AccSalesInvoiceLine> b)
    {
        b.ToAccountingTable("acc_sales_invoice_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Quantity).HasPrecision(18, 3);
        b.Property(x => x.UnitPrice).HasPrecision(18, 2);
        b.Property(x => x.TaxRate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.InvoiceId });
    }
}

public sealed class AccPurchaseBillConfiguration : IEntityTypeConfiguration<AccPurchaseBill>
{
    public void Configure(EntityTypeBuilder<AccPurchaseBill> b)
    {
        b.ToAccountingTable("acc_purchase_bills");
        b.HasKey(x => x.Id);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.Property(x => x.AmountPaid).HasPrecision(18, 2);
        b.Property(x => x.AmountPaidBase).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SupplierId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.IssueDate });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.State });
        b.HasMany(x => x.Lines).WithOne(x => x.Bill!).HasForeignKey(x => x.BillId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccPurchaseBillLineConfiguration : IEntityTypeConfiguration<AccPurchaseBillLine>
{
    public void Configure(EntityTypeBuilder<AccPurchaseBillLine> b)
    {
        b.ToAccountingTable("acc_purchase_bill_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Quantity).HasPrecision(18, 3);
        b.Property(x => x.UnitPrice).HasPrecision(18, 2);
        b.Property(x => x.TaxRate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BillId });
    }
}

public sealed class AccCreditNoteConfiguration : IEntityTypeConfiguration<AccCreditNote>
{
    public void Configure(EntityTypeBuilder<AccCreditNote> b)
    {
        b.ToAccountingTable("acc_credit_notes");
        b.HasKey(x => x.Id);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.Property(x => x.BaseAmount).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.DocumentId });
        b.HasMany(x => x.Lines).WithOne(x => x.CreditNote!).HasForeignKey(x => x.CreditNoteId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccCreditNoteLineConfiguration : IEntityTypeConfiguration<AccCreditNoteLine>
{
    public void Configure(EntityTypeBuilder<AccCreditNoteLine> b)
    {
        b.ToAccountingTable("acc_credit_note_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Quantity).HasPrecision(18, 3);
        b.Property(x => x.UnitPrice).HasPrecision(18, 2);
        b.Property(x => x.TaxRate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CreditNoteId });
    }
}

public sealed class AccSupplierCreditConfiguration : IEntityTypeConfiguration<AccSupplierCredit>
{
    public void Configure(EntityTypeBuilder<AccSupplierCredit> b)
    {
        b.ToAccountingTable("acc_supplier_credits");
        b.HasKey(x => x.Id);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.Property(x => x.BaseAmount).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.DocumentId });
        b.HasMany(x => x.Lines).WithOne(x => x.SupplierCredit!).HasForeignKey(x => x.SupplierCreditId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccSupplierCreditLineConfiguration : IEntityTypeConfiguration<AccSupplierCreditLine>
{
    public void Configure(EntityTypeBuilder<AccSupplierCreditLine> b)
    {
        b.ToAccountingTable("acc_supplier_credit_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Quantity).HasPrecision(18, 3);
        b.Property(x => x.UnitPrice).HasPrecision(18, 2);
        b.Property(x => x.TaxRate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SupplierCreditId });
    }
}

public sealed class AccPaymentConfiguration : IEntityTypeConfiguration<AccPayment>
{
    public void Configure(EntityTypeBuilder<AccPayment> b)
    {
        b.ToAccountingTable("acc_payments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.Property(x => x.BaseAmount).HasPrecision(18, 2);
        b.Property(x => x.FxGainLoss).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Direction, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.DocumentId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PartyId });
    }
}

public sealed class AccBankAccountConfiguration : IEntityTypeConfiguration<AccBankAccount>
{
    public void Configure(EntityTypeBuilder<AccBankAccount> b)
    {
        b.ToAccountingTable("acc_bank_accounts");
        b.HasKey(x => x.Id);
        b.Property(x => x.StatementBalance).HasPrecision(18, 2);
        b.Property(x => x.LastImport).HasColumnType("jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.GlAccountId }).IsUnique();
    }
}

public sealed class AccBankStatementLineConfiguration : IEntityTypeConfiguration<AccBankStatementLine>
{
    public void Configure(EntityTypeBuilder<AccBankStatementLine> b)
    {
        b.ToAccountingTable("acc_bank_statement_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.Source).HasDefaultValue("FEED");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("now()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BankAccountId, x.ImportId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BankAccountId, x.Date });
        // A journal matches at most one statement line (DATA_MODEL 6.2).
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.MatchedJournalId })
            .IsUnique().HasFilter("matched_journal_id IS NOT NULL")
            .HasDatabaseName("ux_acc_bank_statement_lines_matched_journal_id");
    }
}

public sealed class AccExchangeRateConfiguration : IEntityTypeConfiguration<AccExchangeRate>
{
    public void Configure(EntityTypeBuilder<AccExchangeRate> b)
    {
        b.ToAccountingTable("acc_exchange_rates");
        b.HasKey(x => x.Id);
        b.Property(x => x.Rate).HasPrecision(18, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CurrencyCode, x.Date, x.Source }).IsUnique();
    }
}

public sealed class AccFxRevaluationConfiguration : IEntityTypeConfiguration<AccFxRevaluation>
{
    public void Configure(EntityTypeBuilder<AccFxRevaluation> b)
    {
        b.ToAccountingTable("acc_fx_revaluations");
        b.HasKey(x => x.Id);
        b.Property(x => x.RatesJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.Property(x => x.NetDifference).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PeriodId }).IsUnique();
        b.HasMany(x => x.Lines).WithOne(x => x.Revaluation!).HasForeignKey(x => x.RevaluationId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccFxRevaluationLineConfiguration : IEntityTypeConfiguration<AccFxRevaluationLine>
{
    public void Configure(EntityTypeBuilder<AccFxRevaluationLine> b)
    {
        b.ToAccountingTable("acc_fx_revaluation_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.AmountFc).HasPrecision(18, 2);
        b.Property(x => x.CarryingBase).HasPrecision(18, 2);
        b.Property(x => x.Rate).HasPrecision(18, 6);
        b.Property(x => x.RevaluedBase).HasPrecision(18, 2);
        b.Property(x => x.Difference).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.RevaluationId });
    }
}

public sealed class AccCustomFieldConfiguration : IEntityTypeConfiguration<AccCustomField>
{
    public void Configure(EntityTypeBuilder<AccCustomField> b)
    {
        b.ToAccountingTable("acc_custom_fields");
        b.HasKey(x => x.Id);
        b.Property(x => x.OptionsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Entity, x.Key }).IsUnique();
    }
}

public sealed class AccDataSourceConfiguration : IEntityTypeConfiguration<AccDataSource>
{
    public void Configure(EntityTypeBuilder<AccDataSource> b)
    {
        b.ToAccountingTable("acc_data_sources");
        b.HasKey(x => x.Id);
        b.Property(x => x.EntitiesJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.Property(x => x.ConnectionJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Name });
    }
}

public sealed class AccFieldMappingConfiguration : IEntityTypeConfiguration<AccFieldMapping>
{
    public void Configure(EntityTypeBuilder<AccFieldMapping> b)
    {
        b.ToAccountingTable("acc_field_mappings");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.SourceId, x.Entity, x.TargetField }).IsUnique();
    }
}

public sealed class AccImportBatchConfiguration : IEntityTypeConfiguration<AccImportBatch>
{
    public void Configure(EntityTypeBuilder<AccImportBatch> b)
    {
        b.ToAccountingTable("acc_import_batches");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasMany(x => x.Records).WithOne(x => x.Batch!).HasForeignKey(x => x.BatchId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccImportRecordConfiguration : IEntityTypeConfiguration<AccImportRecord>
{
    public void Configure(EntityTypeBuilder<AccImportRecord> b)
    {
        b.ToAccountingTable("acc_import_records");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.PayloadJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BatchId });
    }
}

public sealed class AccPostingInboxConfiguration : IEntityTypeConfiguration<AccPostingInbox>
{
    public void Configure(EntityTypeBuilder<AccPostingInbox> b)
    {
        b.ToAccountingTable("acc_posting_inbox");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.PayloadJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("now()");
        b.ToTable(t => t.HasCheckConstraint("ck_acc_posting_inbox_status", "status IN ('PENDING','POSTED','FAILED','SKIPPED')"));
        // One row per event: reading the same event twice (a crash between storing and acking) stores nothing new.
        b.HasIndex(x => x.EventId).IsUnique();
        // One event, one journal.
        b.HasIndex(x => x.JournalId).IsUnique().HasFilter("journal_id IS NOT NULL");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.EventAt });
        b.HasIndex(x => new { x.Status, x.TenantId, x.BusId });
    }
}

public sealed class AccPostingAccountConfiguration : IEntityTypeConfiguration<AccPostingAccount>
{
    public void Configure(EntityTypeBuilder<AccPostingAccount> b)
    {
        b.ToAccountingTable("acc_posting_accounts");
        b.HasKey(x => x.Id);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("now()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("now()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Role }).IsUnique();
    }
}
