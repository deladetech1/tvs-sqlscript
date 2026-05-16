using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform.Configurations;

public sealed class ResourceDeletionChatHistoryConfiguration : IEntityTypeConfiguration<ResourceDeletionChatHistory>
{
    public void Configure(EntityTypeBuilder<ResourceDeletionChatHistory> b)
    {
        b.ToTable("cp_resource_deletion_chat_histories");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        // sent_by → cp_users(id, tenant_id) RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.SentBy, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ActivityLogConfiguration : IEntityTypeConfiguration<ActivityLog>
{
    public void Configure(EntityTypeBuilder<ActivityLog> b)
    {
        b.ToTable("cp_activity_logs");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OldData).HasColumnType("jsonb");
        b.Property(x => x.NewData).HasColumnType("jsonb");
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceType).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class UnitOfMeasureConfiguration : IEntityTypeConfiguration<UnitOfMeasure>
{
    public void Configure(EntityTypeBuilder<UnitOfMeasure> b)
    {
        b.ToTable("cp_unit_of_measures");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DecimalPlace).HasColumnType("numeric(10,2)");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class CurrencyConfiguration : IEntityTypeConfiguration<Currency>
{
    public void Configure(EntityTypeBuilder<Currency> b)
    {
        b.ToTable("cp_currencies");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DecimalPlaces).HasDefaultValue(2);
        b.Property(x => x.ThousandSeparator).HasDefaultValue(",");
        b.Property(x => x.DecimalSeparator).HasDefaultValue(".");
        b.Property(x => x.CurrencyPosition).HasDefaultValue("before");
        b.Property(x => x.IsDefault).HasDefaultValue(false);
        b.Property(x => x.ExchangeRate).HasColumnType("numeric(20,6)");
        b.Property(x => x.ExchangeRateSource).HasDefaultValue("manual");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.Code }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasInCheck("currency_position", "before", "after");
        b.HasInCheck("exchange_rate_source", "manual", "auto");
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class ThemeConfiguration : IEntityTypeConfiguration<Theme>
{
    public void Configure(EntityTypeBuilder<Theme> b)
    {
        b.ToTable("cp_themes");
        b.HasKey(x => new { x.Id, x.TenantId, x.UserId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.ThemeName, x.UserId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasInCheck("theme_name", "light", "dark", "system");
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class ExpenseConfiguration : IEntityTypeConfiguration<Expense>
{
    public void Configure(EntityTypeBuilder<Expense> b)
    {
        b.ToTable("cp_expense");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId }).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Organization>().WithMany().HasForeignKey(x => new { x.OrgId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Location>().WithMany().HasForeignKey(x => new { x.LocId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class DocumentPathConfiguration : IEntityTypeConfiguration<DocumentPath>
{
    public void Configure(EntityTypeBuilder<DocumentPath> b)
    {
        b.ToTable("cp_document_paths");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DocumentPathValue).HasColumnName("document_path");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Organization>().WithMany().HasForeignKey(x => new { x.OrgId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasDeleteStatusCheck();
        // bkup: created_by / updated_by / deleted_by → cp_users ON DELETE SET NULL
        b.WithAuditUserFks(DeleteBehavior.SetNull);
    }
}

public sealed class BillingLogConfiguration : IEntityTypeConfiguration<BillingLog>
{
    public void Configure(EntityTypeBuilder<BillingLog> b)
    {
        b.ToTable("cp_billings_logs");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Price).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.Rate).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.PaidAmount).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.IsPaid).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.CreatedBy).HasDefaultValue("SYSTEM");
        b.Property(x => x.UpdatedBy).HasDefaultValue("SYSTEM");
        b.Property(x => x.DeletedBy).HasDefaultValue("SYSTEM");
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<App>().WithMany().HasForeignKey(x => x.AppId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Organization>().WithMany().HasForeignKey(x => new { x.OrganizationId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.SetNull);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusinessId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.SetNull);
        b.HasOne<Location>().WithMany().HasForeignKey(x => new { x.LocationId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.SetNull);
        b.HasInCheck("paid_method", "CASH", "CHEQUE", "MOMO", "BANK_TRANSFER", "OTHERS", null!);
        b.HasInCheck("paid_status", "PENDING", "PAID", "FAILED", "CANCELLED", "REFUNDED", "OTHERS", null!);
        b.HasDeleteStatusCheck();
        // bkup does not declare audit-user FKs (created_by defaults to 'SYSTEM'), so no WithAuditUserFks here.
    }
}

public sealed class ExpenseHistoryConfiguration : IEntityTypeConfiguration<ExpenseHistory>
{
    public void Configure(EntityTypeBuilder<ExpenseHistory> b)
    {
        b.ToTable("cp_expenses_history");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.Balance).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.Source).HasDefaultValue("ALLOCATED");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Currency>().WithMany().HasForeignKey(x => new { x.CurrencyId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Organization>().WithMany().HasForeignKey(x => new { x.OrgId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Business>().WithMany().HasForeignKey(x => new { x.BusId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<Location>().WithMany().HasForeignKey(x => new { x.LocId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Restrict);
        b.HasInCheck("source", "ALLOCATED", "CONTIGENCY", "FIXED", "REIMBURSABLE");
        b.HasDeleteStatusCheck();
        b.WithAuditUserFks();
    }
}

public sealed class NotificationEmailCredentialConfiguration : IEntityTypeConfiguration<NotificationEmailCredential>
{
    public void Configure(EntityTypeBuilder<NotificationEmailCredential> b)
    {
        b.ToTable("cp_notification_email_credentials", t => t.HasComment(
            "Stores tenant-specific email credentials for sending notifications. If a tenant has credentials here, they will be used instead of system defaults."));
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.NotificationEmail).HasComment(
            "Tenant-specific email address for sending notifications.");
        b.Property(x => x.NotificationPassword).HasComment(
            "Password for the tenant-specific notification email.");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).AsTimestampDefault();
        b.HasIndex(x => x.TenantId).IsUnique();
        b.HasOne<Tenant>().WithMany().HasForeignKey(x => x.TenantId).OnDelete(DeleteBehavior.Cascade);
        b.HasDeleteStatusCheck();
        // bkup: audit FKs ON DELETE SET NULL.
        b.WithAuditUserFks(DeleteBehavior.SetNull);
    }
}
