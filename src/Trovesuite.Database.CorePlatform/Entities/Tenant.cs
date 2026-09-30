using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class Tenant
{
    public string Id { get; set; } = default!;

    // What this tenant is called, in the words of the person who signed up.
    //
    // A tenant had no name at all until now, only an id and a Description that
    // nothing set. That was survivable while one person belonged to exactly one
    // tenant, because nothing ever had to name one: you were simply in it. Once
    // the same email can be in two, sign-in has to ask which — and a question
    // offering two rows of uuids is not a question anybody can answer.
    //
    // Deliberately NOT unique. Two unrelated customers can both be "Acme Ltd",
    // and refusing the second one means telling a paying customer their own
    // company name is taken, which also tells them somebody else has it.
    // Uniqueness belongs on the subdomain slug, when that arrives: the
    // machine-readable handle is the thing that must not collide, not the label.
    public string TenantName { get; set; } = default!;

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
