using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class TenantConfiguration : IEntityTypeConfiguration<Tenant>
{
    public void Configure(EntityTypeBuilder<Tenant> b)
    {
        b.ToTable("cp_tenants");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.Property(x => x.IsVerified).HasDefaultValue(false);
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.HasDeleteStatusCheck();
    }
}

public sealed class TenantOwnerRegistryEntryConfiguration : IEntityTypeConfiguration<TenantOwnerRegistryEntry>
{
    public void Configure(EntityTypeBuilder<TenantOwnerRegistryEntry> b)
    {
        b.ToTable("cp_tenant_owners_registry", t => t.HasComment(
            "Internal Trovesuite-ops record of tenant owners. No FKs by design — rows persist after tenant hard-delete so churn/ownership history survives."));
        b.HasKey(x => x.TenantId);
        b.Property(x => x.IsActive).HasDefaultValue(true)
            .HasComment("False once the owner has closed the account.");
        b.Property(x => x.Reason)
            .HasComment("Why the owner stopped using the app. Collected at account closure.");
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.Property(x => x.Mdatetime).AsTimestampDefault();
    }
}
