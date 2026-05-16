using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class ResourceType
{
    public string Id { get; set; } = default!;
    public string ResourceTypeName { get; set; } = default!;
    public string? ParentResourceId { get; set; }
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class SharedResourceId
{
    public string Id { get; set; } = default!;
    public string ResourceTypeId { get; set; } = default!;
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class Permission
{
    public string Id { get; set; } = default!;
    public string PermissionName { get; set; } = default!;
    public string? Description { get; set; }
    public string? ResourceTypeId { get; set; }
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class Role : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string RoleName { get; set; } = default!;
    public string? ResourceTypeId { get; set; }
    public bool IsSystem { get; set; } = true;
}

public class RolePermission : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? RoleId { get; set; }
    public string? PermissionId { get; set; }
}

public class AssignRole : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? UserId { get; set; }
    public string? GroupId { get; set; }
    public string? RoleId { get; set; }
    public string? ResourceType { get; set; }
    public bool IsSystem { get; set; }
}
