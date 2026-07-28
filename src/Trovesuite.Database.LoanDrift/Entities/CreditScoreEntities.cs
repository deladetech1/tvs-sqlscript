using System.Text.Json;
using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

/// <summary>
/// Per (tenant, org, bus, loc) credit-score engine configuration. All weights,
/// thresholds and breakpoints live in the <see cref="Config"/> JSONB blob so the
/// admin can tune ~90 knobs without a schema change. One active row per scope.
/// </summary>
public class CreditScoreSettings : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string VersionId { get; set; } = default!;
    public JsonDocument? Config { get; set; }
}

/// <summary>
/// Immutable audit trail of every credit-score settings change. Stores full
/// before/after snapshots so any historical score can be replayed.
/// </summary>
public class CreditScoreSettingsHistory
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? SettingsVersionId { get; set; }
    public string? ChangedBy { get; set; }
    public DateTimeOffset? ChangedAt { get; set; }
    public JsonDocument? PreviousSettings { get; set; }
    public JsonDocument? NewSettings { get; set; }
    public string? ChangeSummary { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

/// <summary>
/// A single computed credit-score record for a (client, loan). Immutable — a new
/// row is written for every calculation, recalculation or manual adjustment.
/// </summary>
public class CreditScore
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string LoanId { get; set; } = default!;

    public int TotalScore { get; set; }
    public string Band { get; set; } = "VERY_POOR";
    public string? Recommendation { get; set; }

    public int RepaymentHistoryScore { get; set; }
    public int DebtToIncomeScore { get; set; }
    public int CreditUtilizationScore { get; set; }
    public int LoanHistoryScore { get; set; }
    public int FinancialCapacityScore { get; set; }
    public int CollateralScore { get; set; }

    public decimal DtiRatio { get; set; }
    public decimal UtilizationRate { get; set; }
    public decimal NetWorth { get; set; }
    public decimal CollateralCoverageRatio { get; set; }
    public decimal OnTimePaymentRate { get; set; }
    public decimal TotalArrears { get; set; }

    public int TotalLoans { get; set; }
    public int CompletedLoans { get; set; }
    public int MaxDaysInDefault { get; set; }
    public int DefaultCount { get; set; }
    public int AccountAgeMonths { get; set; }

    public bool ManualOverride { get; set; }
    public int ManualAdjustment { get; set; }
    public string? ManualAdjustmentReason { get; set; }

    public string Trigger { get; set; } = "CAPTURE";
    public string? SettingsVersionId { get; set; }
    public JsonDocument? Breakdown { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}
