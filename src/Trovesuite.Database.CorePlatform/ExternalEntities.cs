using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform;

/// <summary>
/// Registers core_platform entity types (cp_tenants / cp_users / cp_organizations /
/// cp_businesses / cp_locations / cp_currencies / cp_unit_of_measures / cp_resource_types)
/// as "external" tables in non-core DbContexts.
///
/// Each entity is marked <see cref="TableBuilder.ExcludeFromMigrations"/> so those
/// DbContexts don't try to re-create the tables (CorePlatform owns their DDL),
/// but EF still knows enough about their schemas + composite keys to model
/// cross-schema FK constraints in <c>ld_*</c>, <c>msg_*</c>, <c>hr_*</c> tables.
/// </summary>
public static class ExternalCorePlatformEntities
{
    public static void Register(ModelBuilder b)
    {
        b.Entity<Tenant>(e =>
        {
            e.ToTable("cp_tenants", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => x.Id);
        });

        b.Entity<User>(e =>
        {
            e.ToTable("cp_users", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<Organization>(e =>
        {
            e.ToTable("cp_organizations", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<Business>(e =>
        {
            e.ToTable("cp_businesses", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<Location>(e =>
        {
            e.ToTable("cp_locations", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<Currency>(e =>
        {
            e.ToTable("cp_currencies", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<UnitOfMeasure>(e =>
        {
            e.ToTable("cp_unit_of_measures", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => new { x.Id, x.TenantId });
        });

        b.Entity<ResourceType>(e =>
        {
            e.ToTable("cp_resource_types", CorePlatformDbContext.SchemaName, t => t.ExcludeFromMigrations());
            e.HasKey(x => x.Id);
        });
    }
}
