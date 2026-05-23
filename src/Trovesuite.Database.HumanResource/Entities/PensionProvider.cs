using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

public class PensionProvider : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string Tier { get; set; } = default!; // TIER_2 | TIER_3
}
