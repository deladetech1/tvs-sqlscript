using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

public class Department : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Name { get; set; } = default!;
}
