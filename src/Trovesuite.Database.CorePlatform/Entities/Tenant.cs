using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class Tenant
{
    public string Id { get; set; } = default!;
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }

    public string? Description { get; set; }
    public bool IsVerified { get; set; }
    public bool IsSystem { get; set; } = true;

    // One free trial per tenant, ever. The first subscription made with
    // use_free_tier=true opens a single tenant-wide window; every app
    // subscribed while the window is open is free until it ends.
    public bool FreeTrialUsed { get; set; }
    public DateTimeOffset? FreeTrialStartedAt { get; set; }
    public DateTimeOffset? FreeTrialEndsAt { get; set; }
    public string? FreeTrialConsumedAppSubscriptionId { get; set; }
    // Last time the trial-expiry reminder job emailed the owner — drives the
    // daily "once per day" idempotency guard in the reminder function.
    public DateTimeOffset? LastTrialReminderSentAt { get; set; }
}

public class TenantOwnerRegistryEntry
{
    public string TenantId { get; set; } = default!;
    public string? Fullname { get; set; }
    public string? Email { get; set; }
    public string? Contact { get; set; }
    public string? Dob { get; set; }
    public string? Address { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Reason { get; set; }
    public DateTimeOffset? StoppedAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public DateTimeOffset? Mdatetime { get; set; }
}
