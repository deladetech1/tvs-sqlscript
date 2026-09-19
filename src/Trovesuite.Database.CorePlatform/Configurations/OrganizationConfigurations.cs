using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class GroupConfiguration : IEntityTypeConfiguration<Group>
{
    public void Configure(EntityTypeBuilder<Group> b)
    {
        b.ToTable("cp_groups");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.GroupName }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class UserGroupConfiguration : IEntityTypeConfiguration<UserGroup>
{
    public void Configure(EntityTypeBuilder<UserGroup> b)
    {
        b.ToTable("cp_user_groups");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.UserId, x.GroupId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Group>().WithMany().HasForeignKey(x => new { x.GroupId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class LoginSettingConfiguration : IEntityTypeConfiguration<LoginSetting>
{
    public void Configure(EntityTypeBuilder<LoginSetting> b)
    {
        b.ToTable("cp_login_settings");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSuspended).HasDefaultValue(false);
        b.Property(x => x.IsMultiFactorEnabled).HasDefaultValue(false);
        b.Property(x => x.IsLoginBefore).HasDefaultValue(false);
        b.Property(x => x.CanAlwaysLogin).HasDefaultValue(false);
        b.Property(x => x.WorkingDays).HasColumnType("text[]");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        // A row belongs to one user or one group. The group side is read as "the
        // group's settings", singular, so two live rows for one group would be a
        // question nobody can answer at login time. Partial: the per-user rows are
        // left alone.
        // Group-first so EF keeps the plain tenant_id index: a filtered index cannot
        // stand in for it, and leading with TenantId makes EF think it can.
        b.HasIndex(x => new { x.GroupId, x.TenantId })
            .IsUnique()
            .HasDatabaseName("ix_cp_login_settings_group_tenant")
            .HasFilter("group_id IS NOT NULL AND delete_status = 'NOT_DELETED'");
        // The filtered index above would otherwise displace the conventional FK
        // index on the same columns, leaving the RESTRICT check that runs when a
        // group is deleted with nothing to use for soft-deleted rows.
        b.HasIndex(x => new { x.GroupId, x.TenantId, x.DeleteStatus })
            .HasDatabaseName("ix_cp_login_settings_group_id_tenant_id");
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Group>().WithMany().HasForeignKey(x => new { x.GroupId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class LoginScheduleConfiguration : IEntityTypeConfiguration<LoginSchedule>
{
    public void Configure(EntityTypeBuilder<LoginSchedule> b)
    {
        b.ToTable("cp_login_schedules");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DayOfWeek).HasMaxLength(9);
        b.Property(x => x.StartTime).HasColumnType("time");
        b.Property(x => x.EndTime).HasColumnType("time");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);

        // A window has to end after it starts. Equal is not a window, and
        // reversed silently means "never", which is the kind of setting that
        // looks saved and locks somebody out on Monday morning.
        b.ToTable(t => t.HasCheckConstraint(
            "ck_cp_login_schedules_window", "end_time > start_time"));
        b.ToTable(t => t.HasCheckConstraint(
            "ck_cp_login_schedules_day",
            "day_of_week IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY')"));

        // The resolver reads every window for a login setting on the auth hot
        // path, so it looks them up by that and nothing else.
        b.HasIndex(x => new { x.LoginSettingsId, x.TenantId })
            .HasDatabaseName("ix_cp_login_schedules_settings_tenant");

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        // Cascade, not Restrict: a window is part of the setting it hangs off,
        // with no meaning once that row is gone.
        //
        // No HasPrincipalKey here, unlike the FKs above. cp_login_settings is
        // keyed on exactly (id, tenant_id), so convention already targets the
        // primary key; naming it explicitly makes EF register an alternate key
        // over the same columns and rename the live table's primary key
        // constraint to match — a destructive no-op on a table this one sits on.
        b.HasOne<LoginSetting>().WithMany()
            .HasForeignKey(x => new { x.LoginSettingsId, x.TenantId })
            .OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class OrganizationConfiguration : IEntityTypeConfiguration<Organization>
{
    public void Configure(EntityTypeBuilder<Organization> b)
    {
        b.ToTable("cp_organizations");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.OrgName }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class BusinessConfiguration : IEntityTypeConfiguration<Business>
{
    public void Configure(EntityTypeBuilder<Business> b)
    {
        b.ToTable("cp_businesses");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.BusName }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Organization>().WithMany().HasForeignKey(x => new { x.OrgId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class BusinessAppConfiguration : IEntityTypeConfiguration<BusinessApp>
{
    public void Configure(EntityTypeBuilder<BusinessApp> b)
    {
        b.ToTable("cp_business_apps");
        b.HasKey(x => new { x.TenantId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.BusId, x.AppId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<App>().WithMany().HasForeignKey(x => x.AppId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class LocationConfiguration : IEntityTypeConfiguration<Location>
{
    public void Configure(EntityTypeBuilder<Location> b)
    {
        b.ToTable("cp_locations");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.LocName }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class BusinessAppLocationConfiguration : IEntityTypeConfiguration<BusinessAppLocation>
{
    public void Configure(EntityTypeBuilder<BusinessAppLocation> b)
    {
        b.ToTable("cp_business_app_locations");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<BusinessApp>().WithMany().HasForeignKey(x => new { x.BusinessAppId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Location>().WithMany().HasForeignKey(x => new { x.LocId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class UserLocationConfiguration : IEntityTypeConfiguration<UserLocation>
{
    public void Configure(EntityTypeBuilder<UserLocation> b)
    {
        b.ToTable("cp_user_locations");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<BusinessAppLocation>().WithMany().HasForeignKey(x => new { x.BusAppLocId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class GroupLocationConfiguration : IEntityTypeConfiguration<GroupLocation>
{
    public void Configure(EntityTypeBuilder<GroupLocation> b)
    {
        b.ToTable("cp_group_locations");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Group>().WithMany().HasForeignKey(x => new { x.GroupId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<BusinessAppLocation>().WithMany().HasForeignKey(x => new { x.BusAppLocId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}
