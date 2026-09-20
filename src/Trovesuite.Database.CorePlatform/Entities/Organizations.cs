using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class Group : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string GroupName { get; set; } = default!;
    public bool IsSystem { get; set; }
}

public class UserGroup : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? UserId { get; set; }
    public string? GroupId { get; set; }
    public bool IsSystem { get; set; }
}

public class LoginSetting : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? UserId { get; set; }
    public string? GroupId { get; set; }
    public bool IsSuspended { get; set; }
    public bool IsMultiFactorEnabled { get; set; }
    public bool IsLoginBefore { get; set; }
    public string[]? WorkingDays { get; set; }
    public DateTimeOffset? LoginOn { get; set; }
    public DateTimeOffset? LogoutOn { get; set; }
    public bool CanAlwaysLogin { get; set; }
}

/// <summary>
/// One allowed window on one weekday, hanging off a login setting.
///
/// The weekly schedule was two flat columns for years: WorkingDays said which
/// days, LoginOn/LogoutOn said between which two absolute moments. Neither could
/// express "Monday 02:30 to 17:50" — days carried no times, and the timestamps
/// were a single fixed date range rather than something that repeats. Rows here
/// carry the times, one per window, so a day can have more than one.
///
/// StartTime/EndTime are wall-clock <c>time</c>, not timestamps: they repeat
/// every week and mean nothing without a date. The date comes from the clock at
/// the moment of the check, read in the tenant's timezone.
/// </summary>
public class LoginSchedule : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string LoginSettingsId { get; set; } = default!;
    /// MONDAY … SUNDAY, matching the strings already stored in WorkingDays.
    public string DayOfWeek { get; set; } = default!;
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
}

public class Organization : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? LogoId { get; set; }
    public string OrgName { get; set; } = default!;
}

public class Business : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? LogoId { get; set; }
    public string? OrgId { get; set; }
    public string BusName { get; set; } = default!;
}

public class BusinessApp : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string AppId { get; set; } = default!;
}

public class Location : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string LocName { get; set; } = default!;
}

public class BusinessAppLocation : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? BusinessAppId { get; set; }
    public string? LocId { get; set; }
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string? AppId { get; set; }
}

public class UserLocation : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? UserId { get; set; }
    public string? BusAppLocId { get; set; }
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string? AppId { get; set; }
}

public class GroupLocation : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? GroupId { get; set; }
    public string? BusAppLocId { get; set; }
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string? AppId { get; set; }
}
