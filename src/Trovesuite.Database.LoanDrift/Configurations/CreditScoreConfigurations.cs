using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift.Configurations;

public sealed class CreditScoreSettingsConfiguration : IEntityTypeConfiguration<CreditScoreSettings>
{
    public void Configure(EntityTypeBuilder<CreditScoreSettings> b)
    {
        b.ToTable("ld_credit_score_settings");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Config).HasColumnType("jsonb");
        b.ApplyAuditDefaults();
        // One active settings row per (tenant, org, bus, loc).
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId }).IsUnique();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class CreditScoreSettingsHistoryConfiguration : IEntityTypeConfiguration<CreditScoreSettingsHistory>
{
    public void Configure(EntityTypeBuilder<CreditScoreSettingsHistory> b)
    {
        b.ToTable("ld_credit_score_settings_history");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PreviousSettings).HasColumnType("jsonb");
        b.Property(x => x.NewSettings).HasColumnType("jsonb");
        b.Property(x => x.ChangedAt).HasColumnType("timestamptz");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantOrgBusLocFks();
        // changed_by → cp_users(id, tenant_id)
        b.HasOne<Trovesuite.Database.CorePlatform.Entities.User>().WithMany()
            .HasForeignKey("ChangedBy", "TenantId")
            .HasPrincipalKey(nameof(Trovesuite.Database.CorePlatform.Entities.User.Id),
                             nameof(Trovesuite.Database.CorePlatform.Entities.User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class CreditScoreConfiguration : IEntityTypeConfiguration<CreditScore>
{
    public void Configure(EntityTypeBuilder<CreditScore> b)
    {
        b.ToTable("ld_credit_scores");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Band).HasDefaultValue("VERY_POOR");
        b.Property(x => x.Trigger).HasDefaultValue("CAPTURE");
        foreach (var col in new[] { "DtiRatio", "UtilizationRate", "CollateralCoverageRatio", "OnTimePaymentRate" })
            b.Property(col).HasColumnType("numeric(8,4)").HasDefaultValue(0m);
        foreach (var col in new[] { "NetWorth", "TotalArrears" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.Breakdown).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ClientId });
        b.HasInCheck("band", "EXCELLENT", "GOOD", "FAIR", "POOR", "VERY_POOR");
        b.HasInCheck("trigger", "CAPTURE", "REPAYMENT", "DEFAULT", "COMPLETION", "MANUAL", "SCHEDULED");
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
