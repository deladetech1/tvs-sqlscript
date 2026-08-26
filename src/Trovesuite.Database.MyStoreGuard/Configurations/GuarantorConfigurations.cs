using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class GuarantorConfiguration : IEntityTypeConfiguration<Guarantor>
{
    public void Configure(EntityTypeBuilder<Guarantor> b)
    {
        b.ToTable("msg_guarantors");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Fullname).HasColumnType("varchar(255)");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CustomerId });

        b.WithTenantOrgBusFks();
        b.WithCustomerFk(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class GuarantorContactConfiguration : IEntityTypeConfiguration<GuarantorContact>
{
    public void Configure(EntityTypeBuilder<GuarantorContact> b)
    {
        b.ToTable("msg_guarantor_contacts");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsPrimary).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("kind", "email", "phone");

        // Exactly one primary per kind, enforced here rather than hoped for in
        // code: two primaries would make "the guarantor's number" ambiguous, and
        // whichever got dialled would be arbitrary.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.GuarantorId, x.Kind })
            .IsUnique()
            .HasFilter("is_primary");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.GuarantorId });

        b.WithTenantOrgBusFks();
        b.HasOne<Guarantor>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "GuarantorId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class GuarantorDocumentConfiguration : IEntityTypeConfiguration<GuarantorDocument>
{
    public void Configure(EntityTypeBuilder<GuarantorDocument> b)
    {
        b.ToTable("msg_guarantor_documents");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.GuarantorId });

        b.WithTenantOrgBusFks();
        b.HasOne<Guarantor>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "GuarantorId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class SaleGuarantorConfiguration : IEntityTypeConfiguration<SaleGuarantor>
{
    public void Configure(EntityTypeBuilder<SaleGuarantor> b)
    {
        b.ToTable("msg_sale_guarantors");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Snapshot).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.SaleId, x.GuarantorId })
            .IsUnique();

        b.WithTenantOrgBusLocFks();
        b.HasOne<Sale>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // Restrict: the snapshot means a sale no longer needs the guarantor
        // record, but deleting one that backed a live plan should still be
        // blocked rather than quietly leaving the plan unsecured.
        b.HasOne<Guarantor>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "GuarantorId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class InstallmentPenaltyConfiguration : IEntityTypeConfiguration<InstallmentPenalty>
{
    public void Configure(EntityTypeBuilder<InstallmentPenalty> b)
    {
        b.ToTable("msg_installment_penalties");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(18,2)");
        b.Property(x => x.PaidAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.Status).HasDefaultValue("OUTSTANDING");
        b.Property(x => x.Snapshot).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("status", "OUTSTANDING", "PARTIALLY_PAID", "CLEARED", "WAIVED");

        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_msg_installment_penalties_amount", "amount > 0");
            t.HasCheckConstraint("ck_msg_installment_penalties_paid",
                "paid_amount >= 0 AND paid_amount <= amount");
        });

        // ONCE_PER_PERIOD means at most one penalty per period, ever. Enforced
        // here so a job that runs twice cannot charge twice.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ScheduleId, x.DaysLate })
            .IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PlanId, x.Status });

        b.WithTenantOrgBusLocFks();
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<InstallmentScheduleRow>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "ScheduleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaCreateUpdateUserFks();
        b.HasOne<User>().WithMany().HasForeignKey("WaivedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}
