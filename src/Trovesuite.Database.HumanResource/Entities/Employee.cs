using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

/// <summary>
/// Membership table: rows here are users onboarded as HR employees.
/// The user identity itself lives in core_platform.cp_users; this table
/// only references it. HR-specific employee fields can be added later.
/// </summary>
public class Employee : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string UserId { get; set; } = default!;
}
