using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class EmployeeStatutoryConfiguration : IEntityTypeConfiguration<EmployeeStatutory>
{
    public void Configure(EntityTypeBuilder<EmployeeStatutory> b)
    {
        b.ToTable("hr_employee_statutory");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.EmployeeId }).IsUnique();
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("EmployeeId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.HasOne<PensionProvider>().WithMany()
            .HasForeignKey("Tier2ProviderId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
        b.HasOne<PensionProvider>().WithMany()
            .HasForeignKey("Tier3ProviderId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class EmployeePaymentMethodConfiguration : IEntityTypeConfiguration<EmployeePaymentMethod>
{
    public void Configure(EntityTypeBuilder<EmployeePaymentMethod> b)
    {
        b.ToTable("hr_employee_payment_methods");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsPrimary).HasDefaultValue(true);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.EmployeeId })
            .HasFilter("is_primary = true AND delete_status = 'NOT_DELETED'")
            .IsUnique();
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("EmployeeId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Bank>().WithMany()
            .HasForeignKey("BankId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
        b.HasOne<BankBranch>().WithMany()
            .HasForeignKey("BranchId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class EmployeeSalaryConfiguration : IEntityTypeConfiguration<EmployeeSalary>
{
    public void Configure(EntityTypeBuilder<EmployeeSalary> b)
    {
        b.ToTable("hr_employee_salaries");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PayFrequency).HasDefaultValue("MONTHLY");
        b.Property(x => x.IsCurrent).HasDefaultValue(true);
        b.Property(x => x.GrossMonthlySalary).HasColumnType("numeric(18,2)");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.EmployeeId })
            .HasFilter("is_current = true AND delete_status = 'NOT_DELETED'")
            .IsUnique();
        b.HasDeleteStatusCheck();
        b.HasInCheck("pay_frequency", "MONTHLY", "BIWEEKLY", "WEEKLY");
        b.HasInCheck("reason", "INITIAL", "RAISE", "PROMOTION", "CORRECTION", null!);

        b.WithTenantFk();
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("EmployeeId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Currency>().WithMany()
            .HasForeignKey("CurrencyId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class EmployeeEmergencyContactConfiguration : IEntityTypeConfiguration<EmployeeEmergencyContact>
{
    public void Configure(EntityTypeBuilder<EmployeeEmergencyContact> b)
    {
        b.ToTable("hr_employee_emergency_contacts");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsPrimary).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasDeleteStatusCheck();
        b.HasInCheck("relationship", "SPOUSE", "PARENT", "SIBLING", "CHILD", "FRIEND", "OTHER", null!);

        b.WithTenantFk();
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("EmployeeId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class EmployeeDocumentConfiguration : IEntityTypeConfiguration<EmployeeDocument>
{
    public void Configure(EntityTypeBuilder<EmployeeDocument> b)
    {
        b.ToTable("hr_employee_documents");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasDeleteStatusCheck();
        b.HasInCheck("document_type", "CONTRACT", "NATIONAL_ID", "CERTIFICATE", "OTHER");

        b.WithTenantFk();
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("EmployeeId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.HasOne<HrDocumentPath>().WithMany()
            .HasForeignKey("DocumentId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}
