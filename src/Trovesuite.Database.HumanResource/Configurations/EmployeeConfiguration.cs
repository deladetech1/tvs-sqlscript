using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class EmployeeConfiguration : IEntityTypeConfiguration<Employee>
{
    public void Configure(EntityTypeBuilder<Employee> b)
    {
        b.ToTable("hr_employees");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.EmploymentStatus).HasDefaultValue("ACTIVE");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");

        b.HasIndex(x => new { x.UserId, x.TenantId }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.EmployeeCode }).IsUnique();

        b.HasDeleteStatusCheck();
        b.HasInCheck("employment_type", "FULL_TIME", "PART_TIME", "CONTRACT", "INTERN", null!);
        b.HasInCheck("work_arrangement", "ONSITE", "REMOTE", "HYBRID", null!);
        b.HasInCheck("nationality_id_type", "PASSPORT", "NATIONAL_ID", "DRIVERS_LICENSE", "OTHER", null!);
        b.HasInCheck("employment_status", "ACTIVE", "ON_LEAVE", "TERMINATED", "SUSPENDED");

        b.ToTable(t => t.HasCheckConstraint(
            "ck_hr_employees_no_self_manager",
            "line_manager_id IS NULL OR line_manager_id <> id"));
        b.ToTable(t => t.HasCheckConstraint(
            "ck_hr_employees_no_self_dotted_manager",
            "dotted_line_manager_id IS NULL OR dotted_line_manager_id <> id"));

        b.WithTenantFk();

        // (user_id, tenant_id) → core_platform.cp_users(id, tenant_id) CASCADE
        b.HasOne<User>().WithMany().HasForeignKey(x => new { x.UserId, x.TenantId })
            .HasPrincipalKey(x => new { x.Id, x.TenantId }).OnDelete(DeleteBehavior.Cascade);

        // Self-FK reporting lines
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("LineManagerId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.SetNull);
        b.HasOne<Employee>().WithMany()
            .HasForeignKey("DottedLineManagerId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.SetNull);

        // (department_id, tenant_id) → hr_departments
        b.HasOne<Department>().WithMany()
            .HasForeignKey("DepartmentId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);

        b.WithCrossSchemaAuditUserFks();
    }
}
