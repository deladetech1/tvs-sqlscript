using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

public class Bank : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? SwiftCode { get; set; }
    public string? SortCode { get; set; }
}

public class BankBranch : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string BankId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? BranchCode { get; set; }
}
