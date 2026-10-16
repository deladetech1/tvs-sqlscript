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
