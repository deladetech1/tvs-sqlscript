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
