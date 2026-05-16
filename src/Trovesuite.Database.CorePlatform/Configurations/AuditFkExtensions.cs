using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

/// <summary>
/// Within-CorePlatform helpers that wire up the
/// (X, tenant_id) → cp_users(id, tenant_id) composite foreign keys that
/// almost every tenant-scoped table needs for its created_by / updated_by /
/// deleted_by columns.
/// </summary>
internal static class AuditFkExtensions
{
    /// <summary>
    /// Adds the three audit-user composite FKs:
    ///   (CreatedBy, TenantId) → cp_users(Id, TenantId)
    ///   (UpdatedBy, TenantId) → cp_users(Id, TenantId)
    ///   (DeletedBy, TenantId) → cp_users(Id, TenantId)
    /// with the given ON DELETE behavior (defaults to RESTRICT, matching bkup).
    /// </summary>
    public static EntityTypeBuilder<T> WithAuditUserFks<T>(
        this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Restrict)
        where T : class
    {
        AddOne(b, "CreatedBy", onDelete);
        AddOne(b, "UpdatedBy", onDelete);
        AddOne(b, "DeletedBy", onDelete);
        return b;
    }

    /// <summary>
    /// Variant for tables that only carry created_by / updated_by (no deleted_by).
    /// </summary>
    public static EntityTypeBuilder<T> WithCreateUpdateUserFks<T>(
        this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Restrict)
        where T : class
    {
        AddOne(b, "CreatedBy", onDelete);
        AddOne(b, "UpdatedBy", onDelete);
        return b;
    }

    private static void AddOne<T>(EntityTypeBuilder<T> b, string columnPropertyName, DeleteBehavior onDelete)
        where T : class
    {
        // Skip if the property doesn't exist on this entity (some tables don't have all three).
        if (b.Metadata.FindProperty(columnPropertyName) is null) return;
        if (b.Metadata.FindProperty("TenantId") is null) return;

        b.HasOne<User>()
            .WithMany()
            .HasForeignKey(columnPropertyName, "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(onDelete);
    }
}
