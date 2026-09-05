using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class CreditScoreConfiguration : IEntityTypeConfiguration<CreditScore>
{
    public void Configure(EntityTypeBuilder<CreditScore> b)
    {
        b.ToTable("msg_credit_scores");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();

        b.Property(x => x.Breakdown).HasColumnType("jsonb");
        b.Property(x => x.SettingsSnapshot).HasColumnType("jsonb");
        b.Property(x => x.IsManualAdjustment).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("band", "VERY_POOR", "POOR", "FAIR", "GOOD", "EXCELLENT");
        b.ToTable(t =>
        {
            // 0–1000. A score outside that is a bug in the engine, and one
            // stored row is enough to make every distribution report wrong.
            t.HasCheckConstraint("ck_msg_credit_scores_range",
                "score >= 0 AND score <= 1000");
            // An adjustment is somebody overriding the engine, so it has to say
            // who it moved from and why.
            t.HasCheckConstraint("ck_msg_credit_scores_adjustment",
                "is_manual_adjustment = false OR "
                + "(previous_score IS NOT NULL AND adjustment_reason IS NOT NULL)");
        });

        // The two questions asked of this table: this customer's latest score,
        // and the spread across everybody.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CustomerId, x.Cdatetime });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Band });

        b.WithTenantOrgBusLocFks();
        // Cascade, not the SetNull default. A credit score is a judgement about one
        // customer and means nothing without them, so it goes when they go — the same
        // choice guarantors make. SetNull cannot work here at all: the foreign key is
        // composite, so Postgres nulls tenant_id, org_id and bus_id along with
        // customer_id, and all three are NOT NULL and in the primary key.
        b.WithCustomerFk(DeleteBehavior.Cascade);
        // plan_id → msg_installment_plans. Nullable: a score can be taken to
        // decide a plan, or just to look somebody up.
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class CreditScoreSettingConfiguration
    : IEntityTypeConfiguration<CreditScoreSetting>
{
    public void Configure(EntityTypeBuilder<CreditScoreSetting> b)
    {
        b.ToTable("msg_credit_score_settings");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();

        b.Property(x => x.WeightRepaymentHistory).HasDefaultValue(45);
        b.Property(x => x.WeightPlanHistory).HasDefaultValue(25);
        b.Property(x => x.WeightOutstandingLoad).HasDefaultValue(20);
        b.Property(x => x.WeightRelationship).HasDefaultValue(10);
        b.Property(x => x.BandExcellentMin).HasDefaultValue(800);
        b.Property(x => x.BandGoodMin).HasDefaultValue(650);
        b.Property(x => x.BandFairMin).HasDefaultValue(500);
        b.Property(x => x.BandPoorMin).HasDefaultValue(350);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.ToTable(t =>
        {
            // The weights must total 100, or the score is not out of anything.
            t.HasCheckConstraint("ck_msg_credit_score_settings_weights",
                "weight_repayment_history + weight_plan_history + "
                + "weight_outstanding_load + weight_relationship = 100");
            // Bands have to climb, or a score falls into two of them.
            t.HasCheckConstraint("ck_msg_credit_score_settings_bands",
                "band_poor_min < band_fair_min AND band_fair_min < band_good_min "
                + "AND band_good_min < band_excellent_min");
            // Refusing above the point where you merely ask for approval would
            // make the approval threshold unreachable.
            t.HasCheckConstraint("ck_msg_credit_score_settings_gates",
                "block_min_score IS NULL OR approval_min_score IS NULL "
                + "OR block_min_score <= approval_min_score");
        });

        // One set of weights per business.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId }).IsUnique();

        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class CreditScoreSettingHistoryConfiguration
    : IEntityTypeConfiguration<CreditScoreSettingHistory>
{
    public void Configure(EntityTypeBuilder<CreditScoreSettingHistory> b)
    {
        b.ToTable("msg_credit_score_settings_history");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OldSettings).HasColumnType("jsonb");
        b.Property(x => x.NewSettings).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Cdatetime });

        b.WithTenantOrgBusLocFks();
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}
