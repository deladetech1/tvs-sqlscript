using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> b)
    {
        b.ToTable("cp_users");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.IsOwner).HasDefaultValue(false);
        b.Property(x => x.CanLogin).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => x.Email).IsUnique();
        b.HasIndex(x => x.Contact).IsUnique();
        b.HasInCheck("gender", "MALE", "FEMALE", null!);
        b.HasDeleteStatusCheck();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        // Self-references: created_by / updated_by / deleted_by → cp_users(id, tenant_id)
        b.WithAuditUserFks();
    }
}

public sealed class MemberConfiguration : IEntityTypeConfiguration<Member>
{
    public void Configure(EntityTypeBuilder<Member> b)
    {
        b.ToTable("cp_members", t => t.HasComment(
            "Rows here are users added directly at the core-platform level. HR-onboarded users live in cp_users + human_resource.hr_employees, NOT here."));
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => new { x.UserId, x.TenantId }).IsUnique();
        b.HasDeleteStatusCheck();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.WithAuditUserFks();
    }
}

public sealed class OtpConfiguration : IEntityTypeConfiguration<Otp>
{
    public void Configure(EntityTypeBuilder<Otp> b)
    {
        b.ToTable("cp_otps");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsActive).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).AsTimestampDefault();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.WithCreateUpdateUserFks(DeleteBehavior.SetNull);
    }
}

public sealed class PasswordPolicyConfiguration : IEntityTypeConfiguration<PasswordPolicy>
{
    public void Configure(EntityTypeBuilder<PasswordPolicy> b)
    {
        b.ToTable("cp_password_policies");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.MinLength).HasDefaultValue(8);
        b.Property(x => x.RequireUppercase).HasDefaultValue(true);
        b.Property(x => x.RequireLowercase).HasDefaultValue(true);
        b.Property(x => x.RequireNumbers).HasDefaultValue(true);
        b.Property(x => x.RequireSpecialChars).HasDefaultValue(true);
        b.Property(x => x.SpecialCharsList).HasDefaultValue("!@#$%^&*()_+-=[]{}|;:,.<>?");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => x.TenantId).IsUnique();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.WithCreateUpdateUserFks();
    }
}

public sealed class MultiFactorSettingConfiguration : IEntityTypeConfiguration<MultiFactorSetting>
{
    public void Configure(EntityTypeBuilder<MultiFactorSetting> b)
    {
        b.ToTable("cp_multi_factor_settings");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsMultiFactor).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => x.TenantId).IsUnique();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.WithCreateUpdateUserFks();
    }
}

public sealed class ChangePasswordPolicyConfiguration : IEntityTypeConfiguration<ChangePasswordPolicy>
{
    public void Configure(EntityTypeBuilder<ChangePasswordPolicy> b)
    {
        b.ToTable("cp_change_password_policy");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.AllowPasswordChange).HasDefaultValue(true);
        b.HasIndex(x => x.TenantId).IsUnique();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.WithCreateUpdateUserFks();
    }
}

public sealed class UserLoginTrackingConfiguration : IEntityTypeConfiguration<UserLoginTracking>
{
    public void Configure(EntityTypeBuilder<UserLoginTracking> b)
    {
        b.ToTable("cp_user_login_tracking");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.LoginAttemptsCount).HasDefaultValue(0);
        b.Property(x => x.IsLocked).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.PasswordHistory).HasColumnType("text[]");
        b.HasIndex(x => new { x.TenantId, x.UserId }).IsUnique();

        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.WithCreateUpdateUserFks();
    }
}

public sealed class EnterpriseSubscriptionConfiguration : IEntityTypeConfiguration<EnterpriseSubscription>
{
    public void Configure(EntityTypeBuilder<EnterpriseSubscription> b)
    {
        // No FKs in bkup — table doesn't have tenant_id, so the audit columns are bare text.
        b.ToTable("cp_enterprise_subscriptions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasDeleteStatusCheck();
    }
}
