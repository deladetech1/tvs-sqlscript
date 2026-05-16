using System.Text.Json;
using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class ResourceDeletionChatHistory
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string? ResourceId { get; set; }
    public string? Message { get; set; }
    public string? SentBy { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class ActivityLog
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string? Action { get; set; }
    public string? ResourceType { get; set; }
    public JsonDocument? OldData { get; set; }
    public JsonDocument? NewData { get; set; }
    public string? Description { get; set; }
    public string? PerformedByEmail { get; set; }
    public string? PerformedByContact { get; set; }
    public string? PerformedByFullname { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class UnitOfMeasure : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Symbol { get; set; } = default!;
    public decimal DecimalPlace { get; set; }
}

public class Currency : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Code { get; set; } = default!;
    public string Symbol { get; set; } = default!;
    public string? Country { get; set; }
    public int DecimalPlaces { get; set; } = 2;
    public string? ThousandSeparator { get; set; } = ",";
    public string? DecimalSeparator { get; set; } = ".";
    public string CurrencyPosition { get; set; } = "before";
    public string? Locale { get; set; }
    public string? MinorUnitName { get; set; }
    public bool IsDefault { get; set; }
    public decimal? ExchangeRate { get; set; }
    public string? ExchangeRateSource { get; set; } = "manual";
}

public class Theme : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? UserId { get; set; }
    public string ThemeName { get; set; } = default!;
}

public class Expense : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string? LocId { get; set; }
    public string ExpName { get; set; } = default!;
    public decimal Amount { get; set; }
}

public class DocumentPath : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string? BusId { get; set; }
    public string DocumentPathValue { get; set; } = default!;
    public string? FileName { get; set; }
}

public class BillingLog : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrganizationId { get; set; } = default!;
    public string OrganizationName { get; set; } = default!;
    public string BusinessId { get; set; } = default!;
    public string BusinessName { get; set; } = default!;
    public string LocationId { get; set; } = default!;
    public string LocationName { get; set; } = default!;
    public string AppId { get; set; } = default!;
    public string AppName { get; set; } = default!;

    public decimal Price { get; set; }
    public decimal Rate { get; set; }
    public string? SubscriptionId { get; set; }
    public string? Month { get; set; }

    public bool IsPaid { get; set; }
    public decimal PaidAmount { get; set; }
    public string? PaidDate { get; set; }
    public string? PaidBy { get; set; }
    public string? PaidMethod { get; set; }
    public string? PaidNote { get; set; }
    public string? PaidStatus { get; set; }
}

public class ExpenseHistory : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public decimal Amount { get; set; }
    public string CurrencyId { get; set; } = default!;
    public decimal? Balance { get; set; }
    public string? UsedBy { get; set; }
    public string? UsedFor { get; set; }

    public string Source { get; set; } = "ALLOCATED";
    public string App { get; set; } = default!;
}

public class NotificationEmailCredential : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string NotificationEmail { get; set; } = default!;
    public string NotificationPassword { get; set; } = default!;
}
