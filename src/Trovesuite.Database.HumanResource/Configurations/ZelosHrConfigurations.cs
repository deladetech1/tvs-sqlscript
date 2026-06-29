using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.CorePlatform.Entities;
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
        b.Property(x => x.Address).HasMaxLength(500);
        b.Property(x => x.Country).HasMaxLength(100);
        b.Property(x => x.Description).HasMaxLength(500);
        b.Property(x => x.IsArchived).HasDefaultValue(false);
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
    }
}

public sealed class ZhrDepartmentConfiguration : IEntityTypeConfiguration<ZhrDepartment>
{
    public void Configure(EntityTypeBuilder<ZhrDepartment> b)
    {
        b.ToZelosHrTable("zhr_departments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Description).HasMaxLength(500);
        b.HasOne<ZhrDepartment>().WithMany().HasForeignKey(x => x.ParentDepartmentId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Property(x => x.IsArchived).HasDefaultValue(false);
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
    }
}

public sealed class ZhrEmploymentTypeConfiguration : IEntityTypeConfiguration<ZhrEmploymentType>
{
    public void Configure(EntityTypeBuilder<ZhrEmploymentType> b)
    {
        b.ToZelosHrTable("zhr_employment_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.Description).HasMaxLength(500);
        b.Property(x => x.IsSystemDefault).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.IsActive });
    }
}

public sealed class ZhrIdCardTypeConfiguration : IEntityTypeConfiguration<ZhrIdCardType>
{
    public void Configure(EntityTypeBuilder<ZhrIdCardType> b)
    {
        b.ToZelosHrTable("zhr_id_card_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.Description).HasMaxLength(500);
        b.Property(x => x.IsSystemDefault).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.IsActive });
    }
}

public sealed class ZhrCompanyProfileConfiguration : IEntityTypeConfiguration<ZhrCompanyProfile>
{
    public void Configure(EntityTypeBuilder<ZhrCompanyProfile> b)
    {
        b.ToZelosHrTable("zhr_company_profile");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.LegalName).HasMaxLength(200);
        b.Property(x => x.TradingName).HasMaxLength(200);
        b.Property(x => x.Industry).HasMaxLength(150);
        b.Property(x => x.CompanySize).HasMaxLength(50);
        b.Property(x => x.BusinessRegistrationNumber).HasMaxLength(100);
        b.Property(x => x.Tin).HasMaxLength(100);
        b.Property(x => x.PrimaryWorkCountry).HasMaxLength(100);
        b.Property(x => x.CompanyEmail).HasMaxLength(200);
        b.Property(x => x.Website).HasMaxLength(300);
        b.Property(x => x.LogoDocumentId).HasMaxLength(200);
        b.Property(x => x.BannerDocumentId).HasMaxLength(200);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
    }
}

public sealed class ZhrCompanyOfficeConfiguration : IEntityTypeConfiguration<ZhrCompanyOffice>
{
    public void Configure(EntityTypeBuilder<ZhrCompanyOffice> b)
    {
        b.ToZelosHrTable("zhr_company_offices");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(150);
        b.Property(x => x.Country).HasMaxLength(100);
        b.Property(x => x.City).HasMaxLength(100);
        b.Property(x => x.Phone).HasMaxLength(50);
        b.Property(x => x.IsHeadOffice).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId });
    }
}

public sealed class ZhrCompanyLocalizationConfiguration : IEntityTypeConfiguration<ZhrCompanyLocalization>
{
    public void Configure(EntityTypeBuilder<ZhrCompanyLocalization> b)
    {
        b.ToZelosHrTable("zhr_company_localization");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.TimeZone).HasMaxLength(100);
        b.Property(x => x.CurrencyId).HasMaxLength(64);
        b.Property(x => x.DateFormat).HasMaxLength(50);
        b.Property(x => x.NumberFormat).HasMaxLength(50);
        b.Property(x => x.FirstDayOfWeek).HasMaxLength(20);
        b.Property(x => x.YearStartMonth).HasMaxLength(20);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
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
        b.Property(x => x.LinkedInUrl).HasColumnName("linked_in_url");
        b.Property(x => x.Tier2PensionProvider).HasColumnName("tier2pension_provider");
        b.Property(x => x.Tier3PensionProvider).HasColumnName("tier3pension_provider");
        b.Property(x => x.GrossSalary).HasPrecision(18, 4);
        b.Property(x => x.AnnualizedCost).HasPrecision(18, 4);
        b.Property(x => x.CurrencyId).HasColumnName("currency_id");
        b.Property(x => x.DocumentIds)
            .HasColumnName("document_ids")
            .HasColumnType("jsonb")
            .HasDefaultValueSql("'[]'::jsonb");
        b.HasOne<Currency>().WithMany()
            .HasForeignKey(x => new { x.CurrencyId, x.TenantId })
            .OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => new { x.TenantId, x.EmployeeCode }).IsUnique();
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
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
        b.HasOne<ZhrDepartment>().WithMany().HasForeignKey(x => x.DepartmentId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrBranch>().WithMany().HasForeignKey(x => x.BranchId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<ZhrEmploymentType>().WithMany().HasForeignKey(x => x.EmploymentTypeId).OnDelete(DeleteBehavior.Restrict);
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

public sealed class ZhrEmployeeIdentificationConfiguration : IEntityTypeConfiguration<ZhrEmployeeIdentification>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeIdentification> b)
    {
        b.ToZelosHrTable("zhr_employee_identifications");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<ZhrIdCardType>().WithMany().HasForeignKey(x => x.IdCardTypeId).OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => x.EmployeeId);
        b.HasIndex(x => new { x.EmployeeId, x.IdCardTypeId }).IsUnique();
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
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
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
        b.Property(x => x.ApprovalStage).HasMaxLength(40);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
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
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.LeaveTypeId }).IsUnique();
    }
}

public sealed class ZhrLeaveTypeConfiguration : IEntityTypeConfiguration<ZhrLeaveType>
{
    public void Configure(EntityTypeBuilder<ZhrLeaveType> b)
    {
        b.ToZelosHrTable("zhr_leave_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Name).HasMaxLength(80);
        b.Property(x => x.CountryCode).HasMaxLength(2);
        b.Property(x => x.DefaultEntitledDays).HasPrecision(5, 1);
        b.Property(x => x.AccrualMethod).HasMaxLength(20).HasDefaultValue("front_loaded");
        b.Property(x => x.CarryOverAllowed).HasDefaultValue(false);
        b.Property(x => x.AppliesToEmploymentTypes).HasColumnType("jsonb");
        b.Property(x => x.RequiresSupportingDocument).HasDefaultValue(false);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name }).IsUnique();
    }
}

public sealed class ZhrPublicHolidayConfiguration : IEntityTypeConfiguration<ZhrPublicHoliday>
{
    public void Configure(EntityTypeBuilder<ZhrPublicHoliday> b)
    {
        b.ToZelosHrTable("zhr_public_holidays");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.CountryCode).HasMaxLength(2);
        b.Property(x => x.Name).HasMaxLength(200);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.CountryCode, x.HolidayDate, x.Name });
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
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.Property(x => x.UploadedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.Category });
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
    }
}

public sealed class ZhrCustomFieldDefinitionConfiguration : IEntityTypeConfiguration<ZhrCustomFieldDefinition>
{
    public void Configure(EntityTypeBuilder<ZhrCustomFieldDefinition> b)
    {
        b.ToZelosHrTable("zhr_custom_field_definitions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.EntityType).HasMaxLength(64);
        b.Property(x => x.FieldKey).HasMaxLength(64);
        b.Property(x => x.Label).HasMaxLength(128);
        b.Property(x => x.FieldType).HasMaxLength(32);
        b.Property(x => x.Options).HasColumnType("jsonb");
        b.Property(x => x.ValidationRules).HasColumnType("jsonb");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.IsDeleted).HasDefaultValue(false);
        b.Property(x => x.DisplayOrder).HasDefaultValue(0);
        b.Property(x => x.SectionOrder).HasDefaultValue(0);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EntityType, x.FieldKey })
            .IsUnique()
            .HasFilter("is_deleted = false");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EntityType, x.SectionOrder, x.DisplayOrder });
    }
}

public sealed class ZhrCustomFieldAuditLogConfiguration : IEntityTypeConfiguration<ZhrCustomFieldAuditLog>
{
    public void Configure(EntityTypeBuilder<ZhrCustomFieldAuditLog> b)
    {
        b.ToZelosHrTable("zhr_custom_field_audit_log");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.EntityType).HasMaxLength(64);
        b.Property(x => x.FieldKey).HasMaxLength(64);
        b.Property(x => x.ChangeType).HasMaxLength(32);
        b.Property(x => x.ChangedAt).HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EntityType, x.EntityId, x.ChangedAt });
    }
}
