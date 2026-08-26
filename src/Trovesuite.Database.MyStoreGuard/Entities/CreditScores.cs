using System.Text.Json;

namespace Trovesuite.Database.MyStoreGuard.Entities;

/// <summary>
/// What a shop's own trading history says about whether a customer pays.
///
/// Deliberately NOT a bureau score. It is built only from what the shop can
/// see — how punctually this person has paid their instalments, how their
/// previous plans ended, how much they are carrying right now, and how long
/// they have been a customer. A lender's model would also weigh income and
/// collateral; a shop holds neither, and a score with two of its inputs
/// permanently blank is a score that lies about its own confidence.
///
/// Kept as a row per calculation rather than a column on the customer, because
/// the useful question is usually "what did we know when we approved this?",
/// which a single overwritten number cannot answer.
/// </summary>
public class CreditScore
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string CustomerId { get; set; } = default!;
    /// <summary>Set when the score was taken to decide one particular plan.</summary>
    public string? PlanId { get; set; }

    public int Score { get; set; }
    /// <summary>VERY_POOR, POOR, FAIR, GOOD or EXCELLENT.</summary>
    public string Band { get; set; } = default!;

    /// <summary>
    /// Every category, its weight, the raw figures behind it and the points it
    /// contributed. A score nobody can take apart is a number nobody trusts.
    /// </summary>
    public JsonDocument? Breakdown { get; set; }

    /// <summary>The settings used, frozen — later re-weighting must not silently rewrite history.</summary>
    public JsonDocument? SettingsSnapshot { get; set; }

    public bool IsManualAdjustment { get; set; }
    public int? PreviousScore { get; set; }
    public string? AdjustmentReason { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// How this business weighs the four things it can actually observe.
///
/// One row per business. The weights must sum to 100, which is enforced in the
/// service rather than the database because "which four" is allowed to change
/// and a CHECK naming columns would have to change with it.
/// </summary>
public class CreditScoreSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    /// <summary>Were instalments paid on or before the day they fell due.</summary>
    public int WeightRepaymentHistory { get; set; } = 45;
    /// <summary>How previous plans ended — completed, cancelled or defaulted.</summary>
    public int WeightPlanHistory { get; set; } = 25;
    /// <summary>What they are carrying now against what they have been trusted with.</summary>
    public int WeightOutstandingLoad { get; set; } = 20;
    /// <summary>How long they have been a customer, and how much they have bought.</summary>
    public int WeightRelationship { get; set; } = 10;

    public int BandExcellentMin { get; set; } = 800;
    public int BandGoodMin { get; set; } = 650;
    public int BandFairMin { get; set; } = 500;
    public int BandPoorMin { get; set; } = 350;

    /// <summary>
    /// Below this, a plan goes for approval however small it is. Null leaves
    /// scoring purely advisory, which is the default: a shop should see the
    /// numbers for a while before letting them refuse anybody.
    /// </summary>
    public int? ApprovalMinScore { get; set; }
    /// <summary>Below this, the plan is refused outright. Null means never.</summary>
    public int? BlockMinScore { get; set; }

    public bool IsActive { get; set; } = true;

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Who changed the weights, when, and what changed.
///
/// Re-weighting changes who gets credit, so it is the kind of setting that has
/// to be answerable for months later.
/// </summary>
public class CreditScoreSettingHistory
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public JsonDocument? OldSettings { get; set; }
    public JsonDocument? NewSettings { get; set; }
    public string? Summary { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}
