using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class InstallmentPolicyConfiguration : IEntityTypeConfiguration<InstallmentPolicy>
{
    public void Configure(EntityTypeBuilder<InstallmentPolicy> b)
    {
        b.ToTable("msg_installment_policies");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");

        b.Property(x => x.PolicyMode).HasDefaultValue("ALLOW");

        b.Property(x => x.MinItemAmount).HasColumnType("decimal(14,2)");
        b.Property(x => x.MaxItemAmount).HasColumnType("decimal(14,2)");

        b.Property(x => x.InitialPaymentRequired).HasDefaultValue(true);
        b.Property(x => x.InitialPaymentMin).HasColumnType("decimal(14,2)");
        b.Property(x => x.InitialPaymentMax).HasColumnType("decimal(14,2)");

        b.Property(x => x.FirstDueOffsetDays).HasDefaultValue(0);
        b.Property(x => x.AllowCustomStartDate).HasDefaultValue(false);

        b.Property(x => x.ApprovalRequired).HasDefaultValue(false);
        b.Property(x => x.ApprovalMode).HasDefaultValue("ANY");
        b.Property(x => x.ApprovalThresholdAmount).HasColumnType("decimal(14,2)");
        b.Property(x => x.ApprovalOnMissingGuarantor).HasDefaultValue(false);
        b.Property(x => x.ApprovalOnCustomerArrears).HasDefaultValue(false);
        b.Property(x => x.ReminderEnabled).HasDefaultValue(false);
        b.Property(x => x.ReminderIntervalMinutes).HasDefaultValue(1440);
        b.Property(x => x.ReminderMaxCount).HasDefaultValue(5);

        b.Property(x => x.PenaltyEnabled).HasDefaultValue(false);
        b.Property(x => x.PenaltyValue).HasColumnType("decimal(14,4)");
        b.Property(x => x.PenaltyGraceDays).HasDefaultValue(0);
        b.Property(x => x.PenaltyRecurrence).HasDefaultValue("ONCE_PER_PERIOD");
        b.Property(x => x.PenaltyMaxCap).HasColumnType("decimal(14,2)");

        b.Property(x => x.GuarantorsRequiredMin).HasDefaultValue(0);
        b.Property(x => x.GuarantorIdDocumentRequired).HasDefaultValue(false);
        b.Property(x => x.ReleaseGoodsOn).HasDefaultValue("FULL_PAYMENT");

        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        // No LOCATION here on purpose — location is a separate scope table, so a
        // policy can target a brand AND be limited to two branches at once.
        b.HasInCheck("policy_target_type",
            "ALL_PRODUCTS", "PRODUCT", "SKU", "TAG", "LABEL", "CATEGORY", "BRAND");
        b.HasInCheck("policy_mode", "ALLOW", "DENY");
        b.HasInCheck("approval_mode", "ANY", "ALL");
        // NULL is not listed and does not need to be: a CHECK passes when its
        // expression evaluates to NULL, so `col IN (...)` already permits NULL.
        // Spelling NULL into the IN list would read as though it were doing
        // something, and `x IN (NULL)` is never TRUE anyway. Whether NULL is
        // actually acceptable is decided by ck_..._penalty_shape below.
        b.HasInCheck("penalty_kind", "FIXED", "PERCENTAGE");
        b.HasInCheck("penalty_basis",
            "INSTALLMENT_AMOUNT", "OUTSTANDING_BALANCE", "SALE_TOTAL");
        b.HasInCheck("penalty_recurrence", "ONCE_PER_PERIOD", "DAILY_WHILE_LATE");
        b.HasInCheck("release_goods_on", "FULL_PAYMENT", "INITIAL_PAYMENT", "APPROVAL");

        // Shape rules the API must not be the only thing enforcing.
        b.ToTable(t =>
        {
            // A required down payment with no formula cannot produce an amount.
            t.HasCheckConstraint("ck_msg_installment_policies_initial_formula",
                "initial_payment_required = false OR initial_payment_formula IS NOT NULL");

            // An ALLOW policy has to be able to price a plan; a DENY never
            // prices anything, so it carries no formula at all.
            t.HasCheckConstraint("ck_msg_installment_policies_allow_formula",
                "policy_mode <> 'ALLOW' OR installment_formula IS NOT NULL");

            // A percentage penalty needs something to be a percentage OF.
            t.HasCheckConstraint("ck_msg_installment_policies_penalty_shape",
                "penalty_enabled = false OR (" +
                "  (penalty_kind = 'FIXED' AND penalty_value IS NOT NULL) OR " +
                "  (penalty_kind = 'PERCENTAGE' AND penalty_value IS NOT NULL " +
                "     AND penalty_basis IS NOT NULL))");

            // Daily accrual with no ceiling is how a GHS 3,000 plan becomes a
            // consumer-protection complaint. Required here, not hinted at in the UI.
            t.HasCheckConstraint("ck_msg_installment_policies_penalty_cap",
                "penalty_recurrence <> 'DAILY_WHILE_LATE' OR penalty_enabled = false " +
                "OR penalty_max_cap IS NOT NULL");

            t.HasCheckConstraint("ck_msg_installment_policies_amount_band",
                "min_item_amount IS NULL OR max_item_amount IS NULL " +
                "OR max_item_amount >= min_item_amount");

            t.HasCheckConstraint("ck_msg_installment_policies_date_window",
                "start_datetime IS NULL OR end_datetime IS NULL " +
                "OR end_datetime >= start_datetime");
        });

        // The resolver reads by (scope, active, target type) on every cart
        // change, so it gets its own index rather than relying on the PK.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.IsActive, x.PolicyTargetType });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PolicyTargetType, x.PolicyTargetId });

        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InstallmentPolicyLocationConfiguration : IEntityTypeConfiguration<InstallmentPolicyLocation>
{
    public void Configure(EntityTypeBuilder<InstallmentPolicyLocation> b)
    {
        b.ToTable("msg_installment_policy_locations");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        // One row per (policy, location). A duplicate would double-count nothing
        // but would let the same location be removed once and still match.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PolicyId, x.LocId }).IsUnique();

        b.WithTenantOrgBusFks();
        b.WithCompositeFk<InstallmentPolicyLocation, Location>("LocId");
        b.HasOne<InstallmentPolicy>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PolicyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class InstallmentPlanOptionConfiguration : IEntityTypeConfiguration<InstallmentPlanOption>
{
    public void Configure(EntityTypeBuilder<InstallmentPlanOption> b)
    {
        b.ToTable("msg_installment_plan_options");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.AllowedTerms).HasColumnType("integer[]");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("frequency",
            "DAILY", "WEEKLY", "BI_WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY");

        // An empty array offers a frequency with no terms to pick — the frequency
        // would appear in the drawer and then refuse every value the cashier types.
        //
        // Only emptiness is checked here. "every term >= 1" needs a per-element
        // test, and Postgres forbids the subquery (unnest) that would take; the
        // API enforces positivity instead. Element NULLs cannot arise: the column
        // is integer[] and the API builds it from a validated list of ints.
        b.ToTable(t =>
            t.HasCheckConstraint("ck_msg_installment_plan_options_terms",
                "array_length(allowed_terms, 1) >= 1"));

        // One row per frequency per policy: two MONTHLY rows would make "the
        // terms for monthly" ambiguous.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PolicyId, x.Frequency }).IsUnique();

        b.WithTenantOrgBusFks();
        b.HasOne<InstallmentPolicy>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PolicyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class InstallmentPolicyVariableConfiguration : IEntityTypeConfiguration<InstallmentPolicyVariable>
{
    public void Configure(EntityTypeBuilder<InstallmentPolicyVariable> b)
    {
        b.ToTable("msg_installment_policy_variables");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.VarName).HasColumnType("varchar(100)");
        b.Property(x => x.VarValue).HasColumnType("decimal(18,6)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        // Two variables of the same name would make the formula context depend
        // on row order.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PolicyId, x.VarName }).IsUnique();

        b.WithTenantOrgBusFks();
        b.HasOne<InstallmentPolicy>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PolicyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class InstallmentPolicyApproverConfiguration : IEntityTypeConfiguration<InstallmentPolicyApprover>
{
    public void Configure(EntityTypeBuilder<InstallmentPolicyApprover> b)
    {
        b.ToTable("msg_installment_policy_approvers");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DisplayOrder).HasDefaultValue(0);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        // Listing someone twice would make approval_mode = ALL need two votes
        // from one person.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PolicyId, x.UserId }).IsUnique();

        b.WithTenantOrgBusFks();
        b.HasOne<InstallmentPolicy>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PolicyId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // Restrict, not Cascade: silently dropping an approver when their user
        // record goes would leave an ALL-mode policy quietly easier to satisfy.
        b.HasOne<User>().WithMany().HasForeignKey("UserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}
