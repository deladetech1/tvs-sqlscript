using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

internal static class ZelosHrTable
{
    public static EntityTypeBuilder<T> ToZelosHrTable<T>(this EntityTypeBuilder<T> b, string tableName)
        where T : class => b.ToTable(tableName, ZelosHrSchema.Name);
}

public sealed class ZhrBranchConfiguration : IEntityTypeConfiguration<ZhrBranch>
{
    public void Configure(EntityTypeBuilder<ZhrBranch> b)
    {
        b.ToZelosHrTable("zhr_branches");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(150);
        b.Property(x => x.IsArchived).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
    }
}

public sealed class ZhrDepartmentConfiguration : IEntityTypeConfiguration<ZhrDepartment>
{
    public void Configure(EntityTypeBuilder<ZhrDepartment> b)
    {
        b.ToZelosHrTable("zhr_departments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.HasOne<ZhrDepartment>().WithMany().HasForeignKey(x => x.ParentDepartmentId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Property(x => x.IsArchived).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
    }
}

public sealed class ZhrEmployeeConfiguration : IEntityTypeConfiguration<ZhrEmployee>
{
    public void Configure(EntityTypeBuilder<ZhrEmployee> b)
    {
        b.ToZelosHrTable("zhr_employees");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.EmployeeCode).HasMaxLength(32);
        b.Property(x => x.FullName).HasMaxLength(500);
        b.Property(x => x.UserId).HasMaxLength(128);
        b.Property(x => x.GrossSalary).HasPrecision(18, 4);
        b.Property(x => x.AnnualizedCost).HasPrecision(18, 4);
        b.Property(x => x.Currency).HasMaxLength(8).HasDefaultValue("GHS");
        b.HasIndex(x => x.EmployeeCode).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmploymentStatus, x.DepartmentId, x.BranchId });
        b.HasIndex(x => new { x.TenantId, x.GhanaCardNumber })
            .IsUnique()
            .HasFilter("ghana_card_number IS NOT NULL AND ghana_card_number <> ''");
        b.HasIndex(x => new { x.TenantId, x.UserId })
            .IsUnique()
            .HasFilter("user_id IS NOT NULL");
        b.Property(x => x.LifecycleState).HasDefaultValue("Pre-hire");
        b.Property(x => x.LifecycleStatus).HasDefaultValue("draft");
        b.Property(x => x.IsDraft).HasDefaultValue(true);
        b.Property(x => x.EmploymentStatus).HasDefaultValue("Active");
        b.Property(x => x.IsDeleted).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrDepartment>().WithMany().HasForeignKey(x => x.DepartmentId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrBranch>().WithMany().HasForeignKey(x => x.BranchId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.ManagerId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.ReportsToId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.DottedLineManagerId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ZhrEmployeeEducationConfiguration : IEntityTypeConfiguration<ZhrEmployeeEducation>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeEducation> b)
    {
        b.ToZelosHrTable("zhr_employee_education");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeCertificationConfiguration : IEntityTypeConfiguration<ZhrEmployeeCertification>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeCertification> b)
    {
        b.ToZelosHrTable("zhr_employee_certifications");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrAuditLogConfiguration : IEntityTypeConfiguration<ZhrAuditLog>
{
    public void Configure(EntityTypeBuilder<ZhrAuditLog> b)
    {
        b.ToZelosHrTable("zhr_audit_logs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.OccurredAt });
    }
}

public sealed class ZhrLifecycleEventConfiguration : IEntityTypeConfiguration<ZhrLifecycleEvent>
{
    public void Configure(EntityTypeBuilder<ZhrLifecycleEvent> b)
    {
        b.ToZelosHrTable("zhr_lifecycle_events");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.DueDate });
    }
}

public sealed class ZhrAttendanceRecordConfiguration : IEntityTypeConfiguration<ZhrAttendanceRecord>
{
    public void Configure(EntityTypeBuilder<ZhrAttendanceRecord> b)
    {
        b.ToZelosHrTable("zhr_attendance_records");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.HoursWorked).HasPrecision(5, 2);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.AttendanceDate });
    }
}

public sealed class ZhrLeaveRequestConfiguration : IEntityTypeConfiguration<ZhrLeaveRequest>
{
    public void Configure(EntityTypeBuilder<ZhrLeaveRequest> b)
    {
        b.ToZelosHrTable("zhr_leave_requests");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.DaysRequested).HasPrecision(4, 1);
    }
}

public sealed class ZhrLeaveBalanceConfiguration : IEntityTypeConfiguration<ZhrLeaveBalance>
{
    public void Configure(EntityTypeBuilder<ZhrLeaveBalance> b)
    {
        b.ToZelosHrTable("zhr_leave_balances");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.EntitledDays).HasPrecision(5, 1);
        b.Property(x => x.UsedDays).HasPrecision(5, 1);
        b.Property(x => x.RemainingDays).HasPrecision(5, 1);
    }
}

public sealed class ZhrJobPostingConfiguration : IEntityTypeConfiguration<ZhrJobPosting>
{
    public void Configure(EntityTypeBuilder<ZhrJobPosting> b)
    {
        b.ToZelosHrTable("zhr_job_postings");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    }
}

public sealed class ZhrOnboardingTaskConfiguration : IEntityTypeConfiguration<ZhrOnboardingTask>
{
    public void Configure(EntityTypeBuilder<ZhrOnboardingTask> b)
    {
        b.ToZelosHrTable("zhr_onboarding_tasks");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    }
}

public sealed class ZhrPerformanceReviewConfiguration : IEntityTypeConfiguration<ZhrPerformanceReview>
{
    public void Configure(EntityTypeBuilder<ZhrPerformanceReview> b)
    {
        b.ToZelosHrTable("zhr_performance_reviews");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    }
}

public sealed class ZhrDisciplinaryCaseConfiguration : IEntityTypeConfiguration<ZhrDisciplinaryCase>
{
    public void Configure(EntityTypeBuilder<ZhrDisciplinaryCase> b)
    {
        b.ToZelosHrTable("zhr_disciplinary_cases");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
    }
}

public sealed class ZhrEmployeeDocumentConfiguration : IEntityTypeConfiguration<ZhrEmployeeDocument>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeDocument> b)
    {
        b.ToZelosHrTable("zhr_employee_documents");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.BlobUrl).HasMaxLength(2048);
        b.Property(x => x.ContentType).HasMaxLength(128);
        b.Property(x => x.FileName).HasMaxLength(512);
        b.Property(x => x.IsDeleted).HasDefaultValue(false);
        b.Property(x => x.UploadedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.Category });
    }
}
