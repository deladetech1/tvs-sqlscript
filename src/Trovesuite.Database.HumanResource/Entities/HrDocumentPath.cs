using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

/// <summary>
/// HR-owned mirror of mystoreguard's msg_document_paths. Stores blob/file
/// references for HR documents (contracts, IDs, certificates, …).
/// </summary>
public class HrDocumentPath : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string DocumentPathValue { get; set; } = default!; // mapped to "document_path"
    public string? FileName { get; set; }
}
