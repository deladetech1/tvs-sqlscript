namespace Trovesuite.Database.Common.Entities;

public abstract class AuditableEntity
{
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }

    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public abstract class TenantScopedEntity : AuditableEntity
{
    public string TenantId { get; set; } = default!;
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
}

public static class DeleteStatuses
{
    public const string Pending = "PENDING";
    public const string Deleted = "DELETED";
    public const string NotDeleted = "NOT_DELETED";
}
