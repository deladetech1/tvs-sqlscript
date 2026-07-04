using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift.Configurations;

internal static class SavingsInvestmentDefaults
{
    /// <summary>
    /// Composite FK (TenantId, OrgId, BusId, LocId, SavingsId) → ld_savings_accounts(TenantId, OrgId, BusId, LocId, Id).
    /// </summary>
    public static EntityTypeBuilder<T> WithSavingsAccountFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<SavingsAccount>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SavingsId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>
    /// Composite FK (TenantId, OrgId, BusId, LocId, InvestmentId) → ld_investments(TenantId, OrgId, BusId, LocId, Id).
    /// </summary>
    public static EntityTypeBuilder<T> WithInvestmentFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Investment>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "InvestmentId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }
}

// =====================================================
// SAVINGS
// =====================================================

public sealed class SavingsProductConfiguration : IEntityTypeConfiguration<SavingsProduct>
{
    public void Configure(EntityTypeBuilder<SavingsProduct> b)
    {
        b.ToTable("ld_savings_products");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.ProductType).HasDefaultValue("REGULAR_SAVINGS");
        b.Property(x => x.DefaultInterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.MinimumBalance).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.DormancyDays).HasDefaultValue(180);
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.ApplyAuditDefaults();
        b.HasInCheck("product_type", "REGULAR_SAVINGS", "FIXED_SAVINGS", "TARGET_SAVINGS",
                                     "DAILY_SAVINGS", "GROUP_SAVINGS");
        b.HasInCheck("default_interest_period", "DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY", null!);
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SavingsAccountConfiguration : IEntityTypeConfiguration<SavingsAccount>
{
    public void Configure(EntityTypeBuilder<SavingsAccount> b)
    {
        b.ToTable("ld_savings_accounts");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        foreach (var col in new[]
        {
            "CurrentBalance", "TotalDeposits", "TotalWithdrawals", "TotalInterestEarned",
            "MinimumBalance", "TargetAmount"
        })
            b.Property(col).HasColumnType("numeric(20,6)");
        foreach (var col in new[] { "CurrentBalance", "TotalDeposits", "TotalWithdrawals", "TotalInterestEarned", "MinimumBalance" })
            b.Property(col).HasDefaultValue(0m);
        b.Property(x => x.InterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.AccountNumber }).IsUnique();
        b.HasInCheck("status", "PENDING", "ACTIVE", "DORMANT", "FROZEN", "CLOSED");
        b.HasInCheck("interest_period", "DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY", null!);
        b.HasDeleteStatusCheck();
        b.HasOne<SavingsProduct>().WithMany().HasForeignKey(x => x.SavingsProductId).OnDelete(DeleteBehavior.SetNull);
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SavingsTransactionConfiguration : IEntityTypeConfiguration<SavingsTransaction>
{
    public void Configure(EntityTypeBuilder<SavingsTransaction> b)
    {
        b.ToTable("ld_savings_transactions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.TransactionType).HasDefaultValue("DEPOSIT");
        b.Property(x => x.IsEarlyWithdrawal).HasDefaultValue(false);
        foreach (var col in new[] { "Amount", "BalanceBefore", "BalanceAfter" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.OccurredAt).HasColumnType("timestamptz");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("transaction_type", "DEPOSIT", "WITHDRAWAL", "INTEREST");
        b.HasInCheck("payment_method", "CASH", "MOMO", "CHEQUE", "BANK_TRANSFER", "OTHERS", null!);
        b.WithTenantOrgBusLocFks();
        b.WithSavingsAccountFk();
        b.WithClientFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

// =====================================================
// INVESTMENTS
// =====================================================

public sealed class InvestmentProductConfiguration : IEntityTypeConfiguration<InvestmentProduct>
{
    public void Configure(EntityTypeBuilder<InvestmentProduct> b)
    {
        b.ToTable("ld_investment_products");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.ProductType).HasDefaultValue("FIXED_DEPOSIT");
        b.Property(x => x.DefaultInterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.EarlyTerminationPenaltyRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.ApplyAuditDefaults();
        b.HasInCheck("product_type", "FIXED_DEPOSIT", "TREASURY_BILL", "MONEY_MARKET",
                                     "BOND", "SUSU_INVESTMENT");
        b.HasInCheck("default_interest_period", "MONTHLY", "QUARTERLY", "ANNUALLY", "AT_MATURITY", null!);
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InvestmentConfiguration : IEntityTypeConfiguration<Investment>
{
    public void Configure(EntityTypeBuilder<Investment> b)
    {
        b.ToTable("ld_investments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("REGISTERED");
        foreach (var col in new[]
        {
            "PrincipalAmount", "ExpectedInterest", "ExpectedTotalPayable", "PeriodicReturn",
            "ActualReturn", "PenaltyAmount"
        })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.InterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.EarlyTerminationPenaltyRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.TermMonths).HasDefaultValue(0);
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.AccountNumber }).IsUnique();
        b.HasInCheck("status", "REGISTERED", "FUNDED", "ACTIVE", "MATURED", "COMPLETED", "TERMINATED");
        b.HasInCheck("interest_period", "MONTHLY", "QUARTERLY", "ANNUALLY", "AT_MATURITY", null!);
        b.HasDeleteStatusCheck();
        b.HasOne<InvestmentProduct>().WithMany().HasForeignKey(x => x.InvestmentProductId).OnDelete(DeleteBehavior.SetNull);
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InvestmentTransactionConfiguration : IEntityTypeConfiguration<InvestmentTransaction>
{
    public void Configure(EntityTypeBuilder<InvestmentTransaction> b)
    {
        b.ToTable("ld_investment_transactions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.TransactionType).HasDefaultValue("FUNDING");
        foreach (var col in new[] { "Amount", "PenaltyAmount" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.OccurredAt).HasColumnType("timestamptz");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("transaction_type", "FUNDING", "PAYOUT_PERIOD", "COMPLETION", "TERMINATION");
        b.HasInCheck("payment_method", "CASH", "MOMO", "CHEQUE", "BANK_TRANSFER", "OTHERS", null!);
        b.WithTenantOrgBusLocFks();
        b.WithInvestmentFk();
        b.WithClientFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
