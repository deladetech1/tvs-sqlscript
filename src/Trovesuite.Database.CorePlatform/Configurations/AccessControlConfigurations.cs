using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class ResourceTypeConfiguration : IEntityTypeConfiguration<ResourceType>
{
    public void Configure(EntityTypeBuilder<ResourceType> b)
    {
        b.ToTable("cp_resource_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ParentResourceId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
    }
}

public sealed class SharedResourceIdConfiguration : IEntityTypeConfiguration<SharedResourceId>
{
    public void Configure(EntityTypeBuilder<SharedResourceId> b)
    {
        b.ToTable("cp_shared_resource_ids");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceTypeId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
    }
}

public sealed class PermissionConfiguration : IEntityTypeConfiguration<Permission>
{
    public void Configure(EntityTypeBuilder<Permission> b)
    {
        b.ToTable("cp_permissions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceTypeId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
    }
}

public sealed class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> b)
    {
        b.ToTable("cp_roles");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => new { x.TenantId, x.RoleName }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceTypeId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class RolePermissionConfiguration : IEntityTypeConfiguration<RolePermission>
{
    public void Configure(EntityTypeBuilder<RolePermission> b)
    {
        b.ToTable("cp_role_permissions");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => new { x.TenantId, x.RoleId, x.PermissionId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Role>().WithMany().HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Permission>().WithMany().HasForeignKey(x => x.PermissionId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class AssignRoleConfiguration : IEntityTypeConfiguration<AssignRole>
{
    public void Configure(EntityTypeBuilder<AssignRole> b)
    {
        b.ToTable("cp_assign_roles");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.UserId, x.RoleId }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.GroupId, x.RoleId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Role>().WithMany().HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Group>().WithMany().HasForeignKey(x => new { x.GroupId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}
