using System.Text.Json;
using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

/// <summary>
/// Per (tenant, org, bus, loc) loan-penalty engine configuration. Every rate,
/// grace period, cap and toggle lives in the <see cref="Config"/> JSONB blob so
/// the admin can tune the whole penalty ruleset without a schema change. One
/// active row per scope. Mirrors <see cref="CreditScoreSettings"/>.
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

/// <summary>
/// Immutable audit trail of every penalty-settings change. Stores full
/// before/after snapshots so any historical penalty can be explained.
/// </summary>
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
/// A single penalty applied to a (client, loan). One row per penalty event.
/// Running <c>OutstandingAmount = PenaltyAmount - WaivedAmount - PaidAmount</c>
/// is maintained by the service as repayments and waivers are applied.
/// </summary>
public class Penalty : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string LoanId { get; set; } = default!;

    public string PenaltyType { get; set; } = "LATE_PAYMENT";
    public decimal PenaltyAmount { get; set; }
    public decimal WaivedAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal OutstandingAmount { get; set; }
    public string Status { get; set; } = "OUTSTANDING";

    public string? DueDate { get; set; }
    public int DaysOverdue { get; set; }
    public decimal AppliedRate { get; set; }

    public string Trigger { get; set; } = "BATCH_JOB";
    public string? SettingsVersionId { get; set; }
    public JsonDocument? Breakdown { get; set; }
}

/// <summary>
/// A waiver request/decision against a specific <see cref="Penalty"/>. Officers
/// request; managers approve or reject. Approval reduces the penalty's
/// <c>WaivedAmount</c>. Immutable once decided.
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
    public string? WaiverReason { get; set; }
    public string Status { get; set; } = "PENDING";

    public string? RequestedBy { get; set; }
    public string? ReviewedBy { get; set; }
    public DateTimeOffset? ReviewedAt { get; set; }
    public string? ReviewNote { get; set; }
}
