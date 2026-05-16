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
