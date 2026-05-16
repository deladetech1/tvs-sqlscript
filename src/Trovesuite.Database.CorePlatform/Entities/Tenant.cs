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
