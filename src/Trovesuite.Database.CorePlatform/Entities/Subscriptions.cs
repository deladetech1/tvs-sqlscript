using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class Subscription
{
    public string Id { get; set; } = default!;
    public string SubscriptionName { get; set; } = default!;
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class App
{
    public string Id { get; set; } = default!;
    public string? AppName { get; set; }
    public string? Feature1 { get; set; }
    public string? Feature2 { get; set; }
    public string? Feature3 { get; set; }
    public string? Feature4 { get; set; }
    public string? Feature5 { get; set; }
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string Status { get; set; } = "coming_soon";
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class AppTierConfig
{
    public string Id { get; set; } = default!;
    public string AppId { get; set; } = default!;
    public string SubscriptionId { get; set; } = default!;
    public int? MaxLoginUsers { get; set; }
    public decimal Price { get; set; }
    public decimal Rate { get; set; } = 12.0m;
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class AppFeature
{
    public string Id { get; set; } = default!;
    public string FeatureType { get; set; } = default!;
    public string Title { get; set; } = default!;
    public string Description { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class AppSubscription : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string BusinessAppId { get; set; } = default!;
    public string BusinessId { get; set; } = default!;
    public string AppId { get; set; } = default!;
    public string SharedSubscriptionId { get; set; } = default!;

    // Lifecycle status of the live subscription. During a tenant trial window
    // every subscription sits at TRIALING; payment moves it to ACTIVE.
    public string Status { get; set; } = "TRIALING";

    // Current paid billing cycle. Set when the subscription becomes ACTIVE
    // (for trial subscriptions, the first cycle starts at trial end).
    public DateTimeOffset? CurrentPeriodStart { get; set; }
    public DateTimeOffset? CurrentPeriodEnd { get; set; }
    public DateTimeOffset? NextChargeDate { get; set; }

    // Enterprise deals are billed off-platform. is_payment_required=false means
    // we never collect a card / auto-charge (free trial or enterprise-offline);
    // true means a card is required and access is blocked until first payment.
    public bool IsEnterprise { get; set; }
    public bool IsPaymentRequired { get; set; } = true;
}

// Tenant-level saved Paystack card reference. Stores ONLY the reusable
// authorization token plus non-sensitive display metadata — never the PAN/CVV.
public class PaymentAuthorization : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? PaystackCustomerCode { get; set; }
    public string AuthorizationCode { get; set; } = default!;
    public string Email { get; set; } = default!;
    public string? Last4 { get; set; }
    public string? CardType { get; set; }
    public string? ExpMonth { get; set; }
    public string? ExpYear { get; set; }
    public string? Bank { get; set; }
    public string? Signature { get; set; }
    public bool Reusable { get; set; } = true;
    public bool IsDefault { get; set; } = true;
    // Paystack payment channel for this saved instrument: "card", "mobile_money", etc.
    public string? Channel { get; set; }
}

public class AppSubscriptionHistory : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string AppSubscriptionId { get; set; } = default!;
    public string BusinessId { get; set; } = default!;
    public string AppId { get; set; } = default!;
    public string SharedSubscriptionId { get; set; } = default!;
    public string? StartAt { get; set; }
    public string? EndAt { get; set; }
}
