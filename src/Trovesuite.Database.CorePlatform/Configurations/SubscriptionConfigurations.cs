using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class SubscriptionConfiguration : IEntityTypeConfiguration<Subscription>
{
    public void Configure(EntityTypeBuilder<Subscription> b)
    {
        b.ToTable("cp_subscriptions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasDeleteStatusCheck();
    }
}

public sealed class AppConfiguration : IEntityTypeConfiguration<App>
{
    public void Configure(EntityTypeBuilder<App> b)
    {
        b.ToTable("cp_apps");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Status).HasDefaultValue("coming_soon");
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => x.AppName).IsUnique();
        b.HasInCheck("status", "coming_soon", "live", "deprecated", "beta");
        b.HasDeleteStatusCheck();
    }
}

public sealed class AppTierConfigConfiguration : IEntityTypeConfiguration<AppTierConfig>
{
    public void Configure(EntityTypeBuilder<AppTierConfig> b)
    {
        b.ToTable("cp_app_tier_configs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Price).HasColumnType("numeric(12,2)").HasDefaultValue(0m);
        b.Property(x => x.Rate).HasColumnType("numeric(12,2)").HasDefaultValue(12.0m);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => new { x.AppId, x.SubscriptionId }).IsUnique();
        b.HasOne<App>().WithMany().HasForeignKey(x => x.AppId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Subscription>().WithMany().HasForeignKey(x => x.SubscriptionId).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
    }
}

public sealed class AppFeatureConfiguration : IEntityTypeConfiguration<AppFeature>
{
    public void Configure(EntityTypeBuilder<AppFeature> b)
    {
        b.ToTable("cp_app_features");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.FeatureType).HasColumnType("varchar(50)");
        b.Property(x => x.Title).HasColumnType("varchar(255)");
        b.Property(x => x.Cdatetime).AsTimestampDefault();
    }
}

public sealed class AppSubscriptionConfiguration : IEntityTypeConfiguration<AppSubscription>
{
    public void Configure(EntityTypeBuilder<AppSubscription> b)
    {
        b.ToTable("cp_app_subscriptions", t => t.HasComment(
            "Per-business subscription. One tier per (tenant, business, app). Seat caps and pricing are scoped to this row."));
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Status).HasDefaultValue("TRIALING");
        b.Property(x => x.IsPaymentRequired).HasDefaultValue(true);
        b.Property(x => x.IsEnterprise).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasInCheck("status", "TRIALING", "ACTIVE", "PENDING_PAYMENT", "PAST_DUE", "SUSPENDED", "CANCELLED");
        b.HasIndex(x => new { x.TenantId, x.BusinessId, x.AppId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<App>().WithMany().HasForeignKey(x => x.AppId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Subscription>().WithMany().HasForeignKey(x => x.SharedSubscriptionId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<BusinessApp>().WithMany().HasForeignKey(x => new { x.BusinessAppId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusinessId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class AppSubscriptionHistoryConfiguration : IEntityTypeConfiguration<AppSubscriptionHistory>
{
    public void Configure(EntityTypeBuilder<AppSubscriptionHistory> b)
    {
        b.ToTable("cp_app_subscription_histories");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<App>().WithMany().HasForeignKey(x => x.AppId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Subscription>().WithMany().HasForeignKey(x => x.SharedSubscriptionId).OnDelete(DeleteBehavior.Restrict);
        // NOTE: deliberately NO FK to cp_app_subscriptions. This table is the durable
        // record of past subscription periods, so it must survive the hard-delete of
        // its parent app subscription on unsubscribe (same pattern as
        // cp_tenant_owners_registry). app_subscription_id is kept as a plain column.
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusinessId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class PaymentAuthorizationConfiguration : IEntityTypeConfiguration<PaymentAuthorization>
{
    public void Configure(EntityTypeBuilder<PaymentAuthorization> b)
    {
        b.ToTable("cp_payment_authorizations", t => t.HasComment(
            "Tenant-level saved Paystack card reference. Holds only the reusable authorization token and non-sensitive display metadata — never the PAN or CVV."));
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Reusable).HasDefaultValue(true);
        b.Property(x => x.IsDefault).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => new { x.TenantId, x.AuthorizationCode }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}
