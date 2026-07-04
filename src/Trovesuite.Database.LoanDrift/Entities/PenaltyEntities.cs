using System.Text.Json;
using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

/// <summary>
/// Per (tenant, org, bus, loc) penalty-engine configuration (late/missed/default/
/// early/bounced rules + general rules) stored as a JSONB blob. One active row per scope.
/// </summary>
public class PenaltySettings : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string VersionId { get; set; } = default!;
    public JsonDocument? Config { get; set; }
}

/// <summary>Immutable before/after audit trail of penalty settings changes.</summary>
public class PenaltySettingsHistory
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
/// A single penalty event on a loan — the penalty ledger. One row per applied penalty.
/// </summary>
public class Penalty : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string PenaltyType { get; set; } = "LATE_PAYMENT";
    public decimal PenaltyAmount { get; set; }
    public decimal WaivedAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal OutstandingAmount { get; set; }
    public string Status { get; set; } = "OUTSTANDING";

    public string? DueDate { get; set; }
    public int DaysOverdue { get; set; }
    public decimal AppliedRate { get; set; }
    public string? AppliedSettingsVersion { get; set; }
    public string? CurrencyId { get; set; }

    public string? WaiverReason { get; set; }
    public string? WaivedBy { get; set; }

    public string Trigger { get; set; } = "BATCH_JOB";
}

/// <summary>
/// A waiver request against a penalty. Supports the manager approve/reject workflow.
/// </summary>
public class PenaltyWaiver : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PenaltyId { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public decimal WaiverAmount { get; set; }
    public decimal ApprovedAmount { get; set; }
    public string? WaiverReason { get; set; }
    public string Status { get; set; } = "PENDING";

    public string? RequestedBy { get; set; }
    public string? ApprovedBy { get; set; }
    public string? DecisionReason { get; set; }
}
