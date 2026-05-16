using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

/// <summary>
/// Cross-schema FK helpers used by LoanDrift / MyStoreGuard / HR module
/// Configurations. Each method emits an
/// <c>(X, tenant_id) → core_platform.cp_users(id, tenant_id)</c>-style FK
/// referencing the external CorePlatform entity registered by
/// <see cref="ExternalCorePlatformEntities"/>.
/// </summary>
public static class CrossSchemaFkExtensions
{
    public static EntityTypeBuilder<T> WithCrossSchemaAuditUserFks<T>(
        this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Restrict) where T : class
    {
        AddUserFk(b, "CreatedBy", onDelete);
        AddUserFk(b, "UpdatedBy", onDelete);
        AddUserFk(b, "DeletedBy", onDelete);
        return b;
    }

    public static EntityTypeBuilder<T> WithCrossSchemaCreateUpdateUserFks<T>(
        this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Restrict) where T : class
    {
        AddUserFk(b, "CreatedBy", onDelete);
        AddUserFk(b, "UpdatedBy", onDelete);
        return b;
    }

    /// <summary>
    /// Adds the standard tenant-scoped FK chain that almost every
    /// tenant/org/business/location-scoped table needs:
    ///   tenant_id            → core_platform.cp_tenants(id)               CASCADE
    ///   (org_id, tenant_id)  → core_platform.cp_organizations(id, tenant_id) RESTRICT
    ///   (bus_id, tenant_id)  → core_platform.cp_businesses(id, tenant_id)    RESTRICT
    ///   (loc_id, tenant_id)  → core_platform.cp_locations(id, tenant_id)     RESTRICT
    /// </summary>
    public static EntityTypeBuilder<T> WithTenantOrgBusLocFks<T>(this EntityTypeBuilder<T> b) where T : class
    {
        AddTenantFk(b);
        AddCompositeFk<T, Organization>(b, "OrgId", DeleteBehavior.Restrict);
        AddCompositeFk<T, Business>(b, "BusId", DeleteBehavior.Restrict);
        AddCompositeFk<T, Location>(b, "LocId", DeleteBehavior.Restrict);
        return b;
    }

    public static EntityTypeBuilder<T> WithTenantOrgBusFks<T>(this EntityTypeBuilder<T> b) where T : class
    {
        AddTenantFk(b);
        AddCompositeFk<T, Organization>(b, "OrgId", DeleteBehavior.Restrict);
        AddCompositeFk<T, Business>(b, "BusId", DeleteBehavior.Restrict);
        return b;
    }

    public static EntityTypeBuilder<T> WithTenantFk<T>(this EntityTypeBuilder<T> b) where T : class
    {
        AddTenantFk(b);
        return b;
    }

    public static EntityTypeBuilder<TThis> WithCompositeFk<TThis, TPrincipal>(
        this EntityTypeBuilder<TThis> b,
        string foreignKeyColumnProperty,
        DeleteBehavior onDelete = DeleteBehavior.Restrict)
        where TThis : class
        where TPrincipal : class
    {
        AddCompositeFk<TThis, TPrincipal>(b, foreignKeyColumnProperty, onDelete);
        return b;
    }

    // -------- internals --------

    private static void AddUserFk<T>(EntityTypeBuilder<T> b, string column, DeleteBehavior onDelete) where T : class
    {
        if (b.Metadata.FindProperty(column) is null) return;
        if (b.Metadata.FindProperty("TenantId") is null) return;

        b.HasOne<User>().WithMany().HasForeignKey(column, "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(onDelete);
    }

    private static void AddTenantFk<T>(EntityTypeBuilder<T> b) where T : class
    {
        if (b.Metadata.FindProperty("TenantId") is null) return;
        b.HasOne<Tenant>().WithMany().HasForeignKey("TenantId").OnDelete(DeleteBehavior.Cascade);
    }

    private static void AddCompositeFk<TThis, TPrincipal>(
        EntityTypeBuilder<TThis> b, string column, DeleteBehavior onDelete)
        where TThis : class
        where TPrincipal : class
    {
        if (b.Metadata.FindProperty(column) is null) return;
        if (b.Metadata.FindProperty("TenantId") is null) return;

        b.HasOne<TPrincipal>().WithMany().HasForeignKey(column, "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(onDelete);
    }
}
