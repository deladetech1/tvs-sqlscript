using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class DepartmentConfiguration : IEntityTypeConfiguration<Department>
{
    public void Configure(EntityTypeBuilder<Department> b)
    {
        b.ToTable("hr_departments");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
