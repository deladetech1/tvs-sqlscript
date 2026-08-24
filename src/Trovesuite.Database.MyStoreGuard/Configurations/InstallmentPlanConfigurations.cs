using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class InstallmentPlanConfiguration : IEntityTypeConfiguration<InstallmentPlan>
{
    public void Configure(EntityTypeBuilder<InstallmentPlan> b)
    {
        b.ToTable("msg_installment_plans");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();

        b.Property(x => x.PolicySnapshot).HasColumnType("jsonb");
        b.Property(x => x.FormulaTrace).HasColumnType("jsonb");
        b.Property(x => x.Status).HasDefaultValue("DRAFT");

        foreach (var col in new[]
                 {
                     nameof(InstallmentPlan.GoodsAmount), nameof(InstallmentPlan.InitialPayment),
                     nameof(InstallmentPlan.FinancedAmount), nameof(InstallmentPlan.InstallmentAmount),
                     nameof(InstallmentPlan.TotalPayable), nameof(InstallmentPlan.FinanceCharge),
                     nameof(InstallmentPlan.AmountPaid), nameof(InstallmentPlan.PenaltiesAccrued),
                     nameof(InstallmentPlan.PenaltiesPaid),
                 })
            b.Property(col).HasColumnType("numeric(18,2)").HasDefaultValue(0m);

        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        // PENDING_APPROVAL / REJECTED are unreachable until phase 4 ships the
        // approval flow. Listed now so adding it is code, not a migration on a
        // table that by then holds live plans.
        b.HasInCheck("status",
            "DRAFT", "PENDING_APPROVAL", "REJECTED", "ACTIVE",
            "COMPLETED", "DEFAULTED", "CANCELLED");
        b.HasInCheck("frequency",
            "DAILY", "WEEKLY", "BI_WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY");

        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_msg_installment_plans_term",
                "term_count >= 1");
            // The identity that must hold for the books to balance. Everything
            // downstream — arrears, the balance on the sale, the receipt —
            // assumes it.
            t.HasCheckConstraint("ck_msg_installment_plans_financed",
                "financed_amount = goods_amount - initial_payment");
            t.HasCheckConstraint("ck_msg_installment_plans_charge",
                "finance_charge = total_payable - goods_amount");
        });

        // One plan per sale. Two would make "the balance on this sale"
        // ambiguous, and nothing in the design wants a second.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.SaleId }).IsUnique();
        // The collections screens and the overdue job both read by status.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status });

        b.WithTenantOrgBusLocFks();
        b.HasOne<Sale>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // Restrict, not Cascade: deleting a policy must not take live plans with
        // it. The snapshot means a plan no longer needs its policy to function,
        // so the FK is provenance and should block a delete that would orphan it.
        b.HasOne<InstallmentPolicy>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PolicyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
        b.HasOne<User>().WithMany().HasForeignKey("ApprovedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("RejectedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class InstallmentScheduleRowConfiguration : IEntityTypeConfiguration<InstallmentScheduleRow>
{
    public void Configure(EntityTypeBuilder<InstallmentScheduleRow> b)
    {
        b.ToTable("msg_installment_schedule");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(18,2)");
        b.Property(x => x.PaidAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("status", "PENDING", "PARTIALLY_PAID", "PAID", "OVERDUE", "WAIVED");

        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_msg_installment_schedule_period", "period_no >= 1");
            // A zero or negative row would print as a payment of nothing.
            t.HasCheckConstraint("ck_msg_installment_schedule_amount", "amount > 0");
            // Allocating more to a row than it is worth would silently absorb
            // money that should have moved to the next period.
            t.HasCheckConstraint("ck_msg_installment_schedule_paid",
                "paid_amount >= 0 AND paid_amount <= amount");
        });

        // Two rows for period 3 would make "the next payment" ambiguous.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.PlanId, x.PeriodNo }).IsUnique();
        // The overdue sweep reads by due date across every plan.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.DueDate, x.Status });

        b.WithTenantOrgBusLocFks();
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class InstallmentAllocationConfiguration : IEntityTypeConfiguration<InstallmentAllocation>
{
    public void Configure(EntityTypeBuilder<InstallmentAllocation> b)
    {
        b.ToTable("msg_installment_allocations");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(18,2)");
        b.Property(x => x.AllocationType).HasDefaultValue("SCHEDULED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("allocation_type", "INITIAL", "SCHEDULED", "OVERPAYMENT");

        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_msg_installment_allocations_amount", "amount > 0");
            // A SCHEDULED allocation with no row, or an INITIAL one with a row,
            // would make the ledger unreadable in opposite directions.
            t.HasCheckConstraint("ck_msg_installment_allocations_shape",
                "(allocation_type = 'SCHEDULED' AND schedule_id IS NOT NULL) OR " +
                "(allocation_type <> 'SCHEDULED' AND schedule_id IS NULL)");
        });

        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.PlanId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.PaymentId });

        b.WithTenantOrgBusLocFks();
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<InstallmentScheduleRow>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "ScheduleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<SalePayment>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PaymentId")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class InstallmentApprovalConfiguration : IEntityTypeConfiguration<InstallmentApproval>
{
    public void Configure(EntityTypeBuilder<InstallmentApproval> b)
    {
        b.ToTable("msg_installment_approvals");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.ReminderCount).HasDefaultValue(0);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("status", "PENDING", "APPROVED", "REJECTED", "SUPERSEDED");

        // One vote per approver per plan. Two would let a single person satisfy
        // an ALL-mode policy on their own.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.PlanId, x.UserId }).IsUnique();
        // The approvals inbox and the reminder job both read by (approver, status).
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.UserId, x.Status });

        b.WithTenantOrgBusLocFks();
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("UserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}
