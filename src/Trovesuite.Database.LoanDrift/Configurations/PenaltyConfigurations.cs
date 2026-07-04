using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift.Configurations;

public sealed class PenaltySettingsConfiguration : IEntityTypeConfiguration<PenaltySettings>
{
    public void Configure(EntityTypeBuilder<PenaltySettings> b)
    {
        b.ToTable("ld_penalty_settings");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Config).HasColumnType("jsonb");
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId }).IsUnique();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class PenaltySettingsHistoryConfiguration : IEntityTypeConfiguration<PenaltySettingsHistory>
{
    public void Configure(EntityTypeBuilder<PenaltySettingsHistory> b)
    {
        b.ToTable("ld_penalty_settings_history");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PreviousSettings).HasColumnType("jsonb");
        b.Property(x => x.NewSettings).HasColumnType("jsonb");
        b.Property(x => x.ChangedAt).HasColumnType("timestamptz");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantOrgBusLocFks();
        b.HasOne<User>().WithMany().HasForeignKey("ChangedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class PenaltyConfiguration : IEntityTypeConfiguration<Penalty>
{
    public void Configure(EntityTypeBuilder<Penalty> b)
    {
        b.ToTable("ld_penalties");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PenaltyType).HasDefaultValue("LATE_PAYMENT");
        b.Property(x => x.Status).HasDefaultValue("OUTSTANDING");
        b.Property(x => x.Trigger).HasDefaultValue("BATCH_JOB");
        foreach (var col in new[] { "PenaltyAmount", "WaivedAmount", "PaidAmount", "OutstandingAmount" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.AppliedRate).HasColumnType("numeric(10,4)").HasDefaultValue(0m);
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.HasInCheck("penalty_type", "LATE_PAYMENT", "MISSED_PAYMENT", "DEFAULT", "EARLY_REPAYMENT", "BOUNCED_PAYMENT");
        b.HasInCheck("status", "OUTSTANDING", "PARTIALLY_PAID", "CLEARED", "WAIVED");
        b.HasInCheck("trigger", "BATCH_JOB", "MANUAL", "STATUS_CHANGE");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class PenaltyWaiverConfiguration : IEntityTypeConfiguration<PenaltyWaiver>
{
    public void Configure(EntityTypeBuilder<PenaltyWaiver> b)
    {
        b.ToTable("ld_penalty_waivers");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        foreach (var col in new[] { "WaiverAmount", "ApprovedAmount" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.PenaltyId });
        b.HasInCheck("status", "PENDING", "APPROVED", "REJECTED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.HasOne<Penalty>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PenaltyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("RequestedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("ApprovedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}
