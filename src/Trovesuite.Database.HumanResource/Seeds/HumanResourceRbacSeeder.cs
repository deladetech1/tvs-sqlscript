using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Entities;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.HumanResource.Seeds;

/// <summary>
/// Upserts ZelosHR RBAC into <c>core_platform</c> via EF (no embedded SQL).
/// </summary>
public static class HumanResourceRbacSeeder
{
    public static async Task SeedAsync(HumanResourceDbContext context, CancellationToken ct = default)
    {
        var (cdate, ctime, cdatetime) = HumanResourceRbacAuditing.Now();

        await UpsertResourceTypesAsync(context, cdate, ctime, cdatetime, ct);
        await UpsertPermissionsAsync(context, cdate, ctime, cdatetime, ct);
        await UpsertRolesAsync(context, cdate, ctime, cdatetime, ct);
        await UpsertHrAdminRolePermissionsAsync(context, cdate, ctime, cdatetime, ct);
    }

    static async Task UpsertResourceTypesAsync(
        HumanResourceDbContext context,
        string cdate,
        string ctime,
        DateTimeOffset cdatetime,
        CancellationToken ct)
    {
        var set = context.Set<ResourceType>();
        // Insert roots before children so parent_resource_id FK is satisfied (EF batch order is not guaranteed).
        var roots = HumanResourceRbacSeedData.ResourceTypes.Where(r => r.ParentResourceId is null);
        var children = HumanResourceRbacSeedData.ResourceTypes.Where(r => r.ParentResourceId is not null);

        foreach (var batch in new[] { roots, children })
        {
            foreach (var seed in batch)
            {
                var existing = await set.FindAsync([seed.Id], ct);
                if (existing is null)
                {
                    seed.Cdate = cdate;
                    seed.Ctime = ctime;
                    seed.Cdatetime = cdatetime;
                    set.Add(seed);
                }
                else
                {
                    existing.ResourceTypeName = seed.ResourceTypeName;
                    existing.Description = seed.Description;
                    existing.ParentResourceId = seed.ParentResourceId;
                }
            }

            await context.SaveChangesAsync(ct);
        }
    }

    static async Task UpsertPermissionsAsync(
        HumanResourceDbContext context,
        string cdate,
        string ctime,
        DateTimeOffset cdatetime,
        CancellationToken ct)
    {
        var set = context.Set<Permission>();
        foreach (var seed in HumanResourceRbacSeedData.Permissions)
        {
            var existing = await set.FindAsync([seed.Id], ct);
            if (existing is null)
            {
                seed.Cdate = cdate;
                seed.Ctime = ctime;
                seed.Cdatetime = cdatetime;
                set.Add(seed);
            }
            else
            {
                existing.PermissionName = seed.PermissionName;
                existing.ResourceTypeId = seed.ResourceTypeId;
                existing.Description = seed.Description;
            }
        }

        await context.SaveChangesAsync(ct);
    }

    static async Task UpsertRolesAsync(
        HumanResourceDbContext context,
        string cdate,
        string ctime,
        DateTimeOffset cdatetime,
        CancellationToken ct)
    {
        var set = context.Set<Role>();
        foreach (var seed in HumanResourceRbacSeedData.Roles)
        {
            var existing = await set.FindAsync([seed.Id], ct);
            if (existing is null)
            {
                seed.Cdate = cdate;
                seed.Ctime = ctime;
                seed.Cdatetime = cdatetime;
                set.Add(seed);
            }
            else
            {
                existing.RoleName = seed.RoleName;
                existing.Description = seed.Description;
                existing.ResourceTypeId = seed.ResourceTypeId;
                existing.IsSystem = seed.IsSystem;
                existing.IsActive = seed.IsActive;
            }
        }

        await context.SaveChangesAsync(ct);
    }

    static async Task UpsertHrAdminRolePermissionsAsync(
        HumanResourceDbContext context,
        string cdate,
        string ctime,
        DateTimeOffset cdatetime,
        CancellationToken ct)
    {
        var permissionIds = await context.Set<Permission>()
            .AsNoTracking()
            .Where(p => p.Id.StartsWith("permission-zeloshr-"))
            .Select(p => p.Id)
            .ToListAsync(ct);

        var set = context.Set<RolePermission>();
        var tenantId = HumanResourceRbacSeedData.SystemTenantId;
        var roleId = HumanResourceRbacSeedData.HrAdminRoleId;

        foreach (var permissionId in permissionIds)
        {
            var id = $"rp-hr-admin-{permissionId}";

            // Look up by the row's deterministic id, NOT by (tenant, role, permission).
            // The id is independent of the role, so after a role rename
            // (e.g. app-hr -> app-zeloshr) the pre-existing row is invisible to a
            // role-scoped check and re-inserting it would hit a duplicate-key on the
            // primary key. Re-point the existing row at the current role instead.
            var existing = await set.FirstOrDefaultAsync(
                rp => rp.Id == id && rp.TenantId == tenantId,
                ct);

            if (existing is null)
            {
                set.Add(new RolePermission
                {
                    Id = id,
                    TenantId = tenantId,
                    RoleId = roleId,
                    PermissionId = permissionId,
                    IsActive = true,
                    DeleteStatus = DeleteStatuses.NotDeleted,
                    Cdate = cdate,
                    Ctime = ctime,
                    Cdatetime = cdatetime,
                });
            }
            else
            {
                // Self-heal a stale/soft-deleted row from a prior role id.
                existing.RoleId = roleId;
                existing.PermissionId = permissionId;
                existing.IsActive = true;
                existing.DeleteStatus = DeleteStatuses.NotDeleted;
            }
        }

        await context.SaveChangesAsync(ct);
    }
}
