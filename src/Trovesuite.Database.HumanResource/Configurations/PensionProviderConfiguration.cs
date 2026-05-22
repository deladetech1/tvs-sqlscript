using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class PensionProviderConfiguration : IEntityTypeConfiguration<PensionProvider>
{
    public void Configure(EntityTypeBuilder<PensionProvider> b)
    {
        b.ToTable("hr_pension_providers");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.Name, x.Tier }).IsUnique();
        b.HasDeleteStatusCheck();
        b.HasInCheck("tier", "TIER_2", "TIER_3");

        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
