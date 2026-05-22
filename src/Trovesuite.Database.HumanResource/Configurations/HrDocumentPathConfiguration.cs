using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class HrDocumentPathConfiguration : IEntityTypeConfiguration<HrDocumentPath>
{
    public void Configure(EntityTypeBuilder<HrDocumentPath> b)
    {
        b.ToTable("hr_document_paths");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DocumentPathValue).HasColumnName("document_path");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks(DeleteBehavior.SetNull);
    }
}
