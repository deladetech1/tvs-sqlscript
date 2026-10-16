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
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
    }
}

public sealed class AccAccountConfiguration : IEntityTypeConfiguration<AccAccount>
{
    public void Configure(EntityTypeBuilder<AccAccount> b)
    {
        b.ToAccountingTable("acc_accounts");
        b.HasKey(x => x.Id);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.ParentId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Type });
    }
}

public sealed class AccFiscalPeriodConfiguration : IEntityTypeConfiguration<AccFiscalPeriod>
{
    public void Configure(EntityTypeBuilder<AccFiscalPeriod> b)
    {
        b.ToAccountingTable("acc_fiscal_periods");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.StartDate, x.EndDate }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status });
    }
}

public sealed class AccJournalEntryConfiguration : IEntityTypeConfiguration<AccJournalEntry>
{
    public void Configure(EntityTypeBuilder<AccJournalEntry> b)
    {
        b.ToAccountingTable("acc_journal_entries");
        b.HasKey(x => x.Id);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Date });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.SourceType });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.JournalId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.AccountId });
    }
}

public sealed class AccDimensionConfiguration : IEntityTypeConfiguration<AccDimension>
{
    public void Configure(EntityTypeBuilder<AccDimension> b)
    {
        b.ToAccountingTable("acc_dimensions");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Kind, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Kind });
    }
}

public sealed class AccCurrencyConfiguration : IEntityTypeConfiguration<AccCurrency>
{
    public void Configure(EntityTypeBuilder<AccCurrency> b)
    {
        b.ToAccountingTable("acc_currencies");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Code }).IsUnique();
    }
}

public sealed class AccTaxCodeConfiguration : IEntityTypeConfiguration<AccTaxCode>
{
    public void Configure(EntityTypeBuilder<AccTaxCode> b)
    {
        b.ToAccountingTable("acc_tax_codes");
        b.HasKey(x => x.Id);
        b.Property(x => x.Rate).HasPrecision(8, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Kind });
    }
}

public sealed class AccAccountingRuleConfiguration : IEntityTypeConfiguration<AccAccountingRule>
{
    public void Configure(EntityTypeBuilder<AccAccountingRule> b)
    {
        b.ToAccountingTable("acc_accounting_rules");
        b.HasKey(x => x.Id);
        b.Property(x => x.SampleJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.SourceId, x.Event }).IsUnique();
        b.HasMany(x => x.Lines).WithOne(x => x.Rule!).HasForeignKey(x => x.RuleId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccAccountingRuleLineConfiguration : IEntityTypeConfiguration<AccAccountingRuleLine>
{
    public void Configure(EntityTypeBuilder<AccAccountingRuleLine> b)
    {
        b.ToAccountingTable("acc_accounting_rule_lines");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.RuleId });
    }
}

public sealed class AccAuditEventConfiguration : IEntityTypeConfiguration<AccAuditEvent>
{
    public void Configure(EntityTypeBuilder<AccAuditEvent> b)
    {
        b.ToAccountingTable("acc_audit_events");
        b.HasKey(x => x.Id);
        b.Property(x => x.ChangesJson).HasColumnType("jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.OccurredAt });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EntityType, x.EntityId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Action });
    }
}

public sealed class AccCustomerConfiguration : IEntityTypeConfiguration<AccCustomer>
{
    public void Configure(EntityTypeBuilder<AccCustomer> b)
    {
        b.ToAccountingTable("acc_customers");
        b.HasKey(x => x.Id);
        b.Property(x => x.CreditLimit).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name });
    }
}

public sealed class AccSupplierConfiguration : IEntityTypeConfiguration<AccSupplier>
{
    public void Configure(EntityTypeBuilder<AccSupplier> b)
    {
        b.ToAccountingTable("acc_suppliers");
        b.HasKey(x => x.Id);
        b.Property(x => x.CreditLimit).HasPrecision(18, 2);
        b.Property(x => x.CustomFieldsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Code }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.CustomerId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.IssueDate });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.State });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.InvoiceId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.SupplierId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.IssueDate });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.State });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BillId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.DocumentId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.CreditNoteId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.DocumentId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.SupplierCreditId });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Direction, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.DocumentId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.PartyId });
    }
}

public sealed class AccBankAccountConfiguration : IEntityTypeConfiguration<AccBankAccount>
{
    public void Configure(EntityTypeBuilder<AccBankAccount> b)
    {
        b.ToAccountingTable("acc_bank_accounts");
        b.HasKey(x => x.Id);
        b.Property(x => x.StatementBalance).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.GlAccountId }).IsUnique();
    }
}

public sealed class AccBankStatementLineConfiguration : IEntityTypeConfiguration<AccBankStatementLine>
{
    public void Configure(EntityTypeBuilder<AccBankStatementLine> b)
    {
        b.ToAccountingTable("acc_bank_statement_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BankAccountId, x.Date });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.MatchedJournalId });
    }
}

public sealed class AccExchangeRateConfiguration : IEntityTypeConfiguration<AccExchangeRate>
{
    public void Configure(EntityTypeBuilder<AccExchangeRate> b)
    {
        b.ToAccountingTable("acc_exchange_rates");
        b.HasKey(x => x.Id);
        b.Property(x => x.Rate).HasPrecision(18, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.CurrencyCode, x.Date, x.Source }).IsUnique();
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.PeriodId }).IsUnique();
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.RevaluationId });
    }
}

public sealed class AccCustomFieldConfiguration : IEntityTypeConfiguration<AccCustomField>
{
    public void Configure(EntityTypeBuilder<AccCustomField> b)
    {
        b.ToAccountingTable("acc_custom_fields");
        b.HasKey(x => x.Id);
        b.Property(x => x.OptionsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Entity, x.Key }).IsUnique();
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name });
    }
}

public sealed class AccFieldMappingConfiguration : IEntityTypeConfiguration<AccFieldMapping>
{
    public void Configure(EntityTypeBuilder<AccFieldMapping> b)
    {
        b.ToAccountingTable("acc_field_mappings");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.SourceId, x.Entity, x.TargetField }).IsUnique();
    }
}

public sealed class AccImportBatchConfiguration : IEntityTypeConfiguration<AccImportBatch>
{
    public void Configure(EntityTypeBuilder<AccImportBatch> b)
    {
        b.ToAccountingTable("acc_import_batches");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status });
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
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BatchId });
    }
}
