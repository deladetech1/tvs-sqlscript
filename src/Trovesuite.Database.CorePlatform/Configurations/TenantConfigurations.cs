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
        // NOT NULL, and with a store default despite signup always supplying a
        // name. The default exists for the deploy window, not for the code:
        // migrations ship on their own pipeline, so for some minutes the OLD
        // backend is running against the NEW column, and its tenant INSERT does
        // not mention tenant_name. Without a default that insert violates NOT
        // NULL and signup is down until the backend catches up.
        //
        // The value is deliberately one nobody would choose, so a row that ever
        // shows it is recognisable as a gap rather than as somebody's name.
        //
        // No unique index: see the note on Tenant.TenantName.
        b.Property(x => x.TenantName).HasMaxLength(120).IsRequired()
            .HasDefaultValue("Unnamed organisation");
        // A name of spaces satisfies NOT NULL and reads as empty everywhere it
        // is shown, which is the failure NOT NULL was meant to prevent.
        b.ToTable(t => t.HasCheckConstraint(
            "ck_cp_tenants_tenant_name_not_blank", "btrim(tenant_name) <> ''"));
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
