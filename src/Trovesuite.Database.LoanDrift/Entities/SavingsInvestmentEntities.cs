using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

// =====================================================
// SAVINGS
// =====================================================

/// <summary>
/// Reference/settings table for savings products (e.g. Regular, Fixed, Target, Daily, Group).
/// System rows are seeded per tenant; tenants may add their own. Mirrors <see cref="LoanType"/>.
/// </summary>
public class SavingsProduct : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }

    public string ProductName { get; set; } = default!;
    public string ProductType { get; set; } = "REGULAR_SAVINGS";

    public decimal DefaultInterestRate { get; set; }
    public string? DefaultInterestPeriod { get; set; }
    public decimal MinimumBalance { get; set; }
    public int DormancyDays { get; set; } = 180;

    public bool IsSystem { get; set; } = true;
}

/// <summary>
/// A client's savings account — a running ledger of deposits, withdrawals and interest credits.
/// </summary>
public class SavingsAccount : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string? SavingsProductId { get; set; }
    public string? CurrencyId { get; set; }

    public string? AccountNumber { get; set; }
    public string AccountName { get; set; } = default!;

    public decimal CurrentBalance { get; set; }
    public decimal TotalDeposits { get; set; }
    public decimal TotalWithdrawals { get; set; }
    public decimal TotalInterestEarned { get; set; }

    public decimal InterestRate { get; set; }
    public string? InterestPeriod { get; set; }
    public decimal MinimumBalance { get; set; }
    public decimal? TargetAmount { get; set; }
    public string? MaturityDate { get; set; }

    public string Status { get; set; } = "PENDING";

    public string? OpenedDate { get; set; }
    public string? ClosedDate { get; set; }
    public string? LastTransactionDate { get; set; }
    public string? ClosureReason { get; set; }
    public string? PayoutMethod { get; set; }
}

/// <summary>
/// A single movement on a savings account: DEPOSIT, WITHDRAWAL or INTEREST credit.
/// </summary>
public class SavingsTransaction
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SavingsId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string TransactionType { get; set; } = "DEPOSIT";
    public decimal Amount { get; set; }
    public decimal BalanceBefore { get; set; }
    public decimal BalanceAfter { get; set; }

    public string? PaymentMethod { get; set; }
    public string? Reference { get; set; }
    public string? Description { get; set; }
    public string? NextContributionDate { get; set; }

    // Populated for INTEREST credits only.
    public string? PeriodFrom { get; set; }
    public string? PeriodTo { get; set; }

    public bool IsEarlyWithdrawal { get; set; }

    public DateTimeOffset? OccurredAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

// =====================================================
// INVESTMENTS
// =====================================================

/// <summary>
/// Reference/settings table for investment products (Fixed Deposit, Treasury Bill, etc.).
/// </summary>
public class InvestmentProduct : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }

    public string ProductName { get; set; } = default!;
    public string ProductType { get; set; } = "FIXED_DEPOSIT";

    public decimal DefaultInterestRate { get; set; }
    public string? DefaultInterestPeriod { get; set; }
    public int? DefaultTermMonths { get; set; }
    public decimal EarlyTerminationPenaltyRate { get; set; }

    public bool IsSystem { get; set; } = true;
}

/// <summary>
/// A fixed-term, fixed-rate investment commitment for a client.
/// </summary>
public class Investment : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string? InvestmentProductId { get; set; }
    public string? CurrencyId { get; set; }

    public string? AccountNumber { get; set; }

    public decimal PrincipalAmount { get; set; }
    public decimal InterestRate { get; set; }
    public string? InterestPeriod { get; set; }
    public int TermMonths { get; set; }

    public string? StartDate { get; set; }
    public string? MaturityDate { get; set; }

    public decimal ExpectedInterest { get; set; }
    public decimal ExpectedTotalPayable { get; set; }
    public decimal PeriodicReturn { get; set; }

    public decimal EarlyTerminationPenaltyRate { get; set; }
    public bool RolloverOnMaturity { get; set; }

    public string Status { get; set; } = "REGISTERED";

    public string? FundedDate { get; set; }
    public string? ActivatedDate { get; set; }
    public string? MaturedDate { get; set; }
    public string? CompletedDate { get; set; }

    public decimal ActualReturn { get; set; }
    public decimal PenaltyAmount { get; set; }
}

/// <summary>
/// A single movement on an investment: FUNDING, PAYOUT_PERIOD, COMPLETION or TERMINATION.
/// </summary>
public class InvestmentTransaction
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string InvestmentId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string TransactionType { get; set; } = "FUNDING";
    public decimal Amount { get; set; }
    public decimal PenaltyAmount { get; set; }

    public string? PaymentMethod { get; set; }
    public string? Reference { get; set; }
    public string? Description { get; set; }

    public DateTimeOffset? OccurredAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}
