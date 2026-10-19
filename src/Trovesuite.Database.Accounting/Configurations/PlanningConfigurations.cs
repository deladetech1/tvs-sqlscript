using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Accounting.Entities;

namespace Trovesuite.Database.Accounting.Configurations;

// Recurring documents, fixed assets and budgets. The unique indexes make generation and depreciation idempotent:
// one document per template and occurrence date, one charge per asset and month, one depreciation journal per month
// per business, one approved budget per fiscal year.

public sealed class AccRecurringTemplateConfiguration : IEntityTypeConfiguration<AccRecurringTemplate>
{
    public void Configure(EntityTypeBuilder<AccRecurringTemplate> b)
    {
        b.ToAccountingTable("acc_recurring_templates");
        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_acc_recurring_templates_kind", "kind IN ('INVOICE','BILL')");
            t.HasCheckConstraint("ck_acc_recurring_templates_status", "status IN ('ACTIVE','PAUSED','ENDED','COMPLETED')");
        });
        b.HasKey(x => x.Id);
        b.Property(x => x.ExchangeRate).HasPrecision(18, 6);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status, x.NextRunDate });
        b.HasMany(x => x.Lines).WithOne(x => x.Template!).HasForeignKey(x => x.TemplateId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccRecurringTemplateLineConfiguration : IEntityTypeConfiguration<AccRecurringTemplateLine>
{
    public void Configure(EntityTypeBuilder<AccRecurringTemplateLine> b)
    {
        b.ToAccountingTable("acc_recurring_template_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Quantity).HasPrecision(18, 4);
        b.Property(x => x.UnitPrice).HasPrecision(18, 4);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.TemplateId });
    }
}

public sealed class AccRecurringRunConfiguration : IEntityTypeConfiguration<AccRecurringRun>
{
    public void Configure(EntityTypeBuilder<AccRecurringRun> b)
    {
        b.ToAccountingTable("acc_recurring_runs");
        b.ToTable(t => t.HasCheckConstraint("ck_acc_recurring_runs_status", "status IN ('GENERATED','SKIPPED')"));
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TemplateId, x.OccurrenceDate }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.TemplateId });
    }
}

public sealed class AccAssetCategoryConfiguration : IEntityTypeConfiguration<AccAssetCategory>
{
    public void Configure(EntityTypeBuilder<AccAssetCategory> b)
    {
        b.ToAccountingTable("acc_asset_categories");
        b.HasKey(x => x.Id);
        b.Property(x => x.ReducingRate).HasPrecision(9, 4);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Code }).IsUnique();
    }
}

public sealed class AccFixedAssetConfiguration : IEntityTypeConfiguration<AccFixedAsset>
{
    public void Configure(EntityTypeBuilder<AccFixedAsset> b)
    {
        b.ToAccountingTable("acc_fixed_assets");
        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_acc_fixed_assets_status", "status IN ('ACTIVE','DISPOSED','WRITTEN_OFF')");
            t.HasCheckConstraint("ck_acc_fixed_assets_method", "method IN ('STRAIGHT_LINE','REDUCING_BALANCE')");
        });
        b.HasKey(x => x.Id);
        b.Property(x => x.Cost).HasPrecision(18, 2);
        b.Property(x => x.ResidualValue).HasPrecision(18, 2);
        b.Property(x => x.ReducingRate).HasPrecision(9, 4);
        b.Property(x => x.DisposalProceeds).HasPrecision(18, 2);
        b.Property(x => x.DisposalGainLoss).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Number }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CategoryId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });
    }
}

public sealed class AccAssetDepreciationConfiguration : IEntityTypeConfiguration<AccAssetDepreciation>
{
    public void Configure(EntityTypeBuilder<AccAssetDepreciation> b)
    {
        b.ToAccountingTable("acc_asset_depreciation");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.HasIndex(x => new { x.AssetId, x.PeriodMonth }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PeriodMonth });
    }
}

public sealed class AccDepreciationRunConfiguration : IEntityTypeConfiguration<AccDepreciationRun>
{
    public void Configure(EntityTypeBuilder<AccDepreciationRun> b)
    {
        b.ToAccountingTable("acc_depreciation_runs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Total).HasPrecision(18, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PeriodMonth }).IsUnique();
    }
}

public sealed class AccBudgetConfiguration : IEntityTypeConfiguration<AccBudget>
{
    public void Configure(EntityTypeBuilder<AccBudget> b)
    {
        b.ToAccountingTable("acc_budgets");
        b.ToTable(t => t.HasCheckConstraint("ck_acc_budgets_status", "status IN ('DRAFT','APPROVED','SUPERSEDED')"));
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.FiscalYearId, x.Version }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.FiscalYearId }).IsUnique()
            .HasFilter("status = 'APPROVED'").HasDatabaseName("ux_acc_budgets_approved");
        b.HasMany(x => x.Lines).WithOne(x => x.Budget!).HasForeignKey(x => x.BudgetId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AccBudgetLineConfiguration : IEntityTypeConfiguration<AccBudgetLine>
{
    public void Configure(EntityTypeBuilder<AccBudgetLine> b)
    {
        b.ToAccountingTable("acc_budget_lines");
        b.HasKey(x => x.Id);
        foreach (var m in new[] { "M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08", "M09", "M10", "M11", "M12" })
            b.Property<decimal>(m).HasPrecision(18, 2);
        b.HasIndex(x => new { x.BudgetId, x.AccountId, x.DimensionId }).IsUnique().AreNullsDistinct(false);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BudgetId });
    }
}
