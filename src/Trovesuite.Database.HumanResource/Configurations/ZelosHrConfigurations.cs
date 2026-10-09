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

public sealed class ZhrOfficeNetworkConfiguration : IEntityTypeConfiguration<ZhrOfficeNetwork>
{
    public void Configure(EntityTypeBuilder<ZhrOfficeNetwork> b)
    {
        b.ToZelosHrTable("zhr_office_networks");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Label).HasMaxLength(150);
        b.Property(x => x.Notation).HasMaxLength(100);
        b.Property(x => x.StartAddress).HasMaxLength(45);
        b.Property(x => x.EndAddress).HasMaxLength(45);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Notation }).IsUnique();
    }
}

public sealed class ZhrAttendanceEnforcementConfiguration : IEntityTypeConfiguration<ZhrAttendanceEnforcement>
{
    public void Configure(EntityTypeBuilder<ZhrAttendanceEnforcement> b)
    {
        b.ToZelosHrTable("zhr_attendance_enforcement");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.RequireOfficeNetwork).HasDefaultValue(false);
        b.Property(x => x.TrackLocation).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
    }
}

public sealed class ZhrOfficeLocationConfiguration : IEntityTypeConfiguration<ZhrOfficeLocation>
{
    public void Configure(EntityTypeBuilder<ZhrOfficeLocation> b)
    {
        b.ToZelosHrTable("zhr_office_locations");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Label).HasMaxLength(150);
        b.Property(x => x.Latitude).HasColumnType("double precision");
        b.Property(x => x.Longitude).HasColumnType("double precision");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Label }).IsUnique();
    }
}

public sealed class ZhrTimeSettingConfiguration : IEntityTypeConfiguration<ZhrTimeSetting>
{
    public void Configure(EntityTypeBuilder<ZhrTimeSetting> b)
    {
        b.ToZelosHrTable("zhr_time_settings");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Key).HasMaxLength(64);
        b.Property(x => x.Payload).HasColumnType("jsonb");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Key }).IsUnique();
    }
}

public sealed class ZhrEmployeeIdFormatConfiguration : IEntityTypeConfiguration<ZhrEmployeeIdFormat>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeIdFormat> b)
    {
        b.ToZelosHrTable("zhr_employee_id_format");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Prefix).HasMaxLength(20);
        b.Property(x => x.Separator).HasMaxLength(20);
        b.Property(x => x.AutoGenerate).HasDefaultValue(true);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
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
        b.Property(x => x.EmployeeCodeSystem).HasMaxLength(32);
        b.Property(x => x.EmployeeCodeCustom).HasMaxLength(32);
        b.Property(x => x.FullName).HasMaxLength(500);
        b.Property(x => x.UserId).HasMaxLength(128);
        b.Property(x => x.LinkedInUrl).HasColumnName("linked_in_url");
        b.Property(x => x.Tier2PensionProvider).HasColumnName("tier2pension_provider");
        b.Property(x => x.Tier3PensionProvider).HasColumnName("tier3pension_provider");
        b.Property(x => x.GrossSalary).HasPrecision(18, 4);
        b.Property(x => x.AnnualizedCost).HasPrecision(18, 4);
        b.Property(x => x.NetSalary).HasPrecision(18, 4);
        b.Property(x => x.MaritalStatus).HasMaxLength(50);
        b.Property(x => x.NextOfKinName).HasMaxLength(200);
        b.Property(x => x.NextOfKinPhone).HasMaxLength(50);
        b.Property(x => x.RelationshipToNextOfKin).HasMaxLength(100);
        b.Property(x => x.CurrencyId).HasColumnName("currency_id");
        b.Property(x => x.DocumentIds)
            .HasColumnName("document_ids")
            .HasColumnType("jsonb")
            .HasDefaultValueSql("'[]'::jsonb");
        b.HasOne<Currency>().WithMany()
            .HasForeignKey(x => new { x.CurrencyId, x.TenantId })
            .OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => new { x.TenantId, x.EmployeeCodeSystem }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.EmployeeCodeCustom })
            .IsUnique()
            .HasFilter("employee_code_custom IS NOT NULL AND employee_code_custom <> ''");
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

public sealed class ZhrEmployeeEmergencyContactConfiguration : IEntityTypeConfiguration<ZhrEmployeeEmergencyContact>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeEmergencyContact> b)
    {
        b.ToZelosHrTable("zhr_employee_emergency_contacts");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.EmergencyContactName).HasMaxLength(200);
        b.Property(x => x.EmergencyContactPhone).HasMaxLength(50);
        b.Property(x => x.Relationship).HasMaxLength(100);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeePaymentMethodConfiguration : IEntityTypeConfiguration<ZhrEmployeePaymentMethod>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeePaymentMethod> b)
    {
        b.ToZelosHrTable("zhr_employee_payment_methods");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.PaymentMode).HasMaxLength(50);
        b.Property(x => x.BankName).HasMaxLength(150);
        b.Property(x => x.AccountName).HasMaxLength(200);
        b.Property(x => x.AccountNumber).HasMaxLength(100);
        b.Property(x => x.BranchName).HasMaxLength(150);
        b.Property(x => x.IsPrimary).HasDefaultValue(false);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeMedicalProfileConfiguration : IEntityTypeConfiguration<ZhrEmployeeMedicalProfile>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeMedicalProfile> b)
    {
        b.ToZelosHrTable("zhr_employee_medical_profiles");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.BloodGroup).HasMaxLength(10);
        b.Property(x => x.DisabilityStatus).HasMaxLength(100);
        b.Property(x => x.AccommodationDetails).HasMaxLength(1000);
        b.Property(x => x.EmergencyMedicalNotes).HasMaxLength(1000);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId).IsUnique();
    }
}

public sealed class ZhrEmployeeMedicalConditionConfiguration : IEntityTypeConfiguration<ZhrEmployeeMedicalCondition>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeMedicalCondition> b)
    {
        b.ToZelosHrTable("zhr_employee_medical_conditions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Condition).HasMaxLength(200);
        b.Property(x => x.Severity).HasMaxLength(50);
        b.Property(x => x.Notes).HasMaxLength(1000);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeAllergyConfiguration : IEntityTypeConfiguration<ZhrEmployeeAllergy>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeAllergy> b)
    {
        b.ToZelosHrTable("zhr_employee_allergies");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Allergen).HasMaxLength(200);
        b.Property(x => x.Reaction).HasMaxLength(200);
        b.Property(x => x.Severity).HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeMedicationConfiguration : IEntityTypeConfiguration<ZhrEmployeeMedication>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeMedication> b)
    {
        b.ToZelosHrTable("zhr_employee_medications");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Name).HasMaxLength(200);
        b.Property(x => x.Dosage).HasMaxLength(100);
        b.Property(x => x.Frequency).HasMaxLength(100);
        b.Property(x => x.Notes).HasMaxLength(1000);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeSkillConfiguration : IEntityTypeConfiguration<ZhrEmployeeSkill>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeSkill> b)
    {
        b.ToZelosHrTable("zhr_employee_skills");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Name).HasMaxLength(150);
        b.Property(x => x.Proficiency).HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeExperienceConfiguration : IEntityTypeConfiguration<ZhrEmployeeExperience>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeExperience> b)
    {
        b.ToZelosHrTable("zhr_employee_experiences");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Company).HasMaxLength(200);
        b.Property(x => x.JobTitle).HasMaxLength(150);
        b.Property(x => x.EmploymentType).HasMaxLength(50);
        b.Property(x => x.Location).HasMaxLength(200);
        b.Property(x => x.Description).HasMaxLength(2000);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrEmployeeReferralConfiguration : IEntityTypeConfiguration<ZhrEmployeeReferral>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeReferral> b)
    {
        b.ToZelosHrTable("zhr_employee_referrals");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Name).HasMaxLength(200);
        b.Property(x => x.JobTitle).HasMaxLength(150);
        b.Property(x => x.Company).HasMaxLength(200);
        b.Property(x => x.Relationship).HasMaxLength(100);
        b.Property(x => x.Email).HasMaxLength(200);
        b.Property(x => x.Phone).HasMaxLength(50);
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
        b.Property(x => x.Openings).HasDefaultValue(1);
        b.Property(x => x.BudgetMonthly).HasPrecision(14, 2);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
    }
}

public sealed class ZhrCandidateConfiguration : IEntityTypeConfiguration<ZhrCandidate>
{
    public void Configure(EntityTypeBuilder<ZhrCandidate> b)
    {
        b.ToZelosHrTable("zhr_candidates");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.FullName).HasMaxLength(200);
        b.Property(x => x.Email).HasMaxLength(200);
        b.Property(x => x.Phone).HasMaxLength(40);
        b.Property(x => x.Source).HasMaxLength(60);
        b.Property(x => x.Stage).HasMaxLength(20);
        b.Property(x => x.Notes).HasMaxLength(2000);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.JobPostingId });
    }
}

public sealed class ZhrOnboardingTaskConfiguration : IEntityTypeConfiguration<ZhrOnboardingTask>
{
    public void Configure(EntityTypeBuilder<ZhrOnboardingTask> b)
    {
        b.ToZelosHrTable("zhr_onboarding_tasks");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Kind).HasMaxLength(20).HasDefaultValue("onboarding");
    }
}

public sealed class ZhrPerformanceReviewConfiguration : IEntityTypeConfiguration<ZhrPerformanceReview>
{
    public void Configure(EntityTypeBuilder<ZhrPerformanceReview> b)
    {
        b.ToZelosHrTable("zhr_performance_reviews");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Rating).HasPrecision(2, 1);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
    }
}

public sealed class ZhrCoachingNoteConfiguration : IEntityTypeConfiguration<ZhrCoachingNote>
{
    public void Configure(EntityTypeBuilder<ZhrCoachingNote> b)
    {
        b.ToZelosHrTable("zhr_coaching_notes");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.AuthorId).HasColumnType("text");
        b.Property(x => x.Body).HasMaxLength(4000);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.AuthorId });
    }
}

public sealed class ZhrDisciplinaryCaseConfiguration : IEntityTypeConfiguration<ZhrDisciplinaryCase>
{
    public void Configure(EntityTypeBuilder<ZhrDisciplinaryCase> b)
    {
        b.ToZelosHrTable("zhr_disciplinary_cases");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.Outcome).HasMaxLength(1000);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
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
        b.Property(x => x.FileDocumentId).HasMaxLength(128);
        b.Property(x => x.FileName).HasMaxLength(512);
        b.Property(x => x.IsDeleted).HasDefaultValue(false);
        b.Property(x => x.CustomFieldsData).HasColumnType("jsonb").HasDefaultValue("{}");
        b.Property(x => x.UploadedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.Category });
        b.HasIndex(x => x.CustomFieldsData).HasMethod("gin");
    }
}

public sealed class ZhrEmployeeChangeRequestConfiguration : IEntityTypeConfiguration<ZhrEmployeeChangeRequest>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeChangeRequest> b)
    {
        b.ToZelosHrTable("zhr_employee_change_requests");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.FieldPath).HasMaxLength(256);
        b.Property(x => x.OldValueJson).HasColumnType("jsonb");
        b.Property(x => x.NewValueJson).HasColumnType("jsonb");
        b.Property(x => x.Status).HasMaxLength(32);
        b.Property(x => x.RequestedBy).HasColumnType("text");
        b.Property(x => x.ReviewedBy).HasColumnType("text");
        b.Property(x => x.ReviewNote).HasColumnType("text");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasOne<ZhrEmployee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status, x.CreatedAt });
        b.HasIndex(x => new { x.EmployeeId, x.FieldPath, x.Status })
            .HasFilter("status = 'pending'");
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

public sealed class ZhrCompensationVersionConfiguration : IEntityTypeConfiguration<ZhrCompensationVersion>
{
    public void Configure(EntityTypeBuilder<ZhrCompensationVersion> b)
    {
        b.ToZelosHrTable("zhr_compensation_versions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.BaseAmount).HasPrecision(14, 2);
        b.Property(x => x.ComponentsJson).HasColumnType("jsonb");
        b.Property(x => x.Currency).HasMaxLength(3);
        b.Property(x => x.PayFrequency).HasMaxLength(20);
        b.Property(x => x.Reason).HasMaxLength(500);
        b.Property(x => x.Status).HasMaxLength(20);
        b.Property(x => x.ProposedBy).HasColumnType("text");
        b.Property(x => x.DecidedBy).HasColumnType("text");
        b.Property(x => x.DecisionNote).HasMaxLength(500);
        b.Property(x => x.ChangeType).HasMaxLength(20);
        b.Property(x => x.ChangeValue).HasPrecision(14, 2);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.VersionNumber }).IsUnique();
        b.HasIndex(x => x.ChangeRequestId);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status });
    }
}

public sealed class ZhrPayrollRunConfiguration : IEntityTypeConfiguration<ZhrPayrollRun>
{
    public void Configure(EntityTypeBuilder<ZhrPayrollRun> b)
    {
        b.ToZelosHrTable("zhr_payroll_runs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Period).HasMaxLength(7);
        b.Property(x => x.Kind).HasMaxLength(20);
        b.Property(x => x.Status).HasMaxLength(30);
        b.Property(x => x.Currency).HasMaxLength(3);
        b.Property(x => x.RulePackVersion).HasMaxLength(30);
        b.Property(x => x.TotalGross).HasPrecision(16, 2);
        b.Property(x => x.TotalDeductions).HasPrecision(16, 2);
        b.Property(x => x.TotalEmployerCost).HasPrecision(16, 2);
        b.Property(x => x.TotalNet).HasPrecision(16, 2);
        b.Property(x => x.PreparedBy).HasColumnType("text");
        b.Property(x => x.ApprovedBy).HasColumnType("text");
        b.Property(x => x.EventsJson).HasColumnType("jsonb");
        b.Property(x => x.AcknowledgementsJson).HasColumnType("jsonb");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Period });
    }
}

public sealed class ZhrPayrollLineConfiguration : IEntityTypeConfiguration<ZhrPayrollLine>
{
    public void Configure(EntityTypeBuilder<ZhrPayrollLine> b)
    {
        b.ToZelosHrTable("zhr_payroll_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.EmployeeName).HasMaxLength(255);
        b.Property(x => x.EmployeeCode).HasMaxLength(64);
        b.Property(x => x.DepartmentName).HasMaxLength(255);
        b.Property(x => x.EarningsJson).HasColumnType("jsonb");
        b.Property(x => x.DeductionsJson).HasColumnType("jsonb");
        b.Property(x => x.EmployerContributionsJson).HasColumnType("jsonb");
        b.Property(x => x.FlagsJson).HasColumnType("jsonb");
        b.Property(x => x.Gross).HasPrecision(14, 2);
        b.Property(x => x.TotalDeductions).HasPrecision(14, 2);
        b.Property(x => x.TotalEmployerContributions).HasPrecision(14, 2);
        b.Property(x => x.Net).HasPrecision(14, 2);
        b.Property(x => x.PreviousNet).HasPrecision(14, 2);
        b.Property(x => x.Currency).HasMaxLength(3);
        b.Property(x => x.PaymentChannel).HasMaxLength(30);
        b.Property(x => x.PaymentDestinationMasked).HasMaxLength(64);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrPayrollRun>().WithMany().HasForeignKey(x => x.RunId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.RunId, x.EmployeeId }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId });
    }
}

public sealed class ZhrWorkPatternConfiguration : IEntityTypeConfiguration<ZhrWorkPattern>
{
    public void Configure(EntityTypeBuilder<ZhrWorkPattern> b)
    {
        b.ToZelosHrTable("zhr_work_patterns");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(120);
        b.Property(x => x.DaysJson).HasColumnType("jsonb");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId });
    }
}

public sealed class ZhrPatternAssignmentConfiguration : IEntityTypeConfiguration<ZhrPatternAssignment>
{
    public void Configure(EntityTypeBuilder<ZhrPatternAssignment> b)
    {
        b.ToZelosHrTable("zhr_pattern_assignments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Scope).HasMaxLength(20);
        b.Property(x => x.Target).HasMaxLength(64);
        b.Property(x => x.Reason).HasMaxLength(500);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.HasOne<ZhrWorkPattern>().WithMany().HasForeignKey(x => x.PatternId).OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EffectiveFrom });
    }
}

public sealed class ZhrShiftConfiguration : IEntityTypeConfiguration<ZhrShift>
{
    public void Configure(EntityTypeBuilder<ZhrShift> b)
    {
        b.ToZelosHrTable("zhr_shifts");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Start).HasMaxLength(5);
        b.Property(x => x.End).HasMaxLength(5);
        b.Property(x => x.Position).HasMaxLength(120);
        b.Property(x => x.Note).HasMaxLength(500);
        b.Property(x => x.State).HasMaxLength(20);
        b.Property(x => x.CreatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.UpdatedAt).HasDefaultValueSql("NOW()");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Date });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.Date });
    }
}

public sealed class ZhrShiftChangeConfiguration : IEntityTypeConfiguration<ZhrShiftChange>
{
    public void Configure(EntityTypeBuilder<ZhrShiftChange> b)
    {
        b.ToZelosHrTable("zhr_shift_changes");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Action).HasMaxLength(20);
        b.Property(x => x.Summary).HasMaxLength(500);
        b.Property(x => x.Reason).HasMaxLength(500);
        b.Property(x => x.By).HasColumnType("text");
        b.HasOne<ZhrShift>().WithMany().HasForeignKey(x => x.ShiftId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.ShiftId);
    }
}

public sealed class ZhrLeaveReconciliationConfiguration : IEntityTypeConfiguration<ZhrLeaveReconciliation>
{
    public void Configure(EntityTypeBuilder<ZhrLeaveReconciliation> b)
    {
        b.ToZelosHrTable("zhr_leave_reconciliations");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Key).HasMaxLength(200);
        b.Property(x => x.Action).HasMaxLength(40);
        b.Property(x => x.Note).HasMaxLength(1000);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Key }).IsUnique();
    }
}

public sealed class ZhrEmployeeStatusChangeConfiguration : IEntityTypeConfiguration<ZhrEmployeeStatusChange>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeStatusChange> b)
    {
        b.ToZelosHrTable("zhr_employee_status_changes");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.FromStatus).HasMaxLength(50);
        b.Property(x => x.ToStatus).HasMaxLength(50);
        b.Property(x => x.Reason).HasMaxLength(1000);
        b.Property(x => x.Source).HasMaxLength(20);
        b.Property(x => x.ChangedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.ChangedAt });
        b.HasIndex(x => x.EmployeeId);
    }
}

public sealed class ZhrOffboardingCaseConfiguration : IEntityTypeConfiguration<ZhrOffboardingCase>
{
    public void Configure(EntityTypeBuilder<ZhrOffboardingCase> b)
    {
        b.ToZelosHrTable("zhr_offboarding_cases");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Reference).HasMaxLength(20);
        b.Property(x => x.Reason).HasMaxLength(30);
        b.Property(x => x.State).HasMaxLength(10);
        b.Property(x => x.Currency).HasMaxLength(3);
        b.Property(x => x.AccruedLeaveDays).HasPrecision(6, 2);
        b.Property(x => x.FinalSettlement).HasPrecision(14, 2);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Reference }).IsUnique();
        b.HasIndex(x => x.EmployeeId);
        b.HasIndex(x => x.LifecycleEventId);
    }
}

public sealed class ZhrTimesheetConfiguration : IEntityTypeConfiguration<ZhrTimesheet>
{
    public void Configure(EntityTypeBuilder<ZhrTimesheet> b)
    {
        b.ToZelosHrTable("zhr_timesheets");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Period).HasMaxLength(7);
        b.Property(x => x.Status).HasMaxLength(40);
        b.Property(x => x.Comment).HasMaxLength(1000);
        b.Property(x => x.DecidedBy).HasColumnType("text");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Period, x.EmployeeId }).IsUnique();
    }
}

public sealed class ZhrPayPeriodClosureConfiguration : IEntityTypeConfiguration<ZhrPayPeriodClosure>
{
    public void Configure(EntityTypeBuilder<ZhrPayPeriodClosure> b)
    {
        b.ToZelosHrTable("zhr_pay_period_closures");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Period).HasMaxLength(7);
        b.Property(x => x.ClosedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Period }).IsUnique();
    }
}

public sealed class ZhrPayrollOneOffConfiguration : IEntityTypeConfiguration<ZhrPayrollOneOff>
{
    public void Configure(EntityTypeBuilder<ZhrPayrollOneOff> b)
    {
        b.ToZelosHrTable("zhr_payroll_one_offs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Component).HasMaxLength(60);
        b.Property(x => x.Amount).HasPrecision(14, 2);
        b.Property(x => x.Basis).HasMaxLength(10);
        b.Property(x => x.Recurrence).HasMaxLength(10);
        b.Property(x => x.Note).HasMaxLength(500);
        b.Property(x => x.CancelReason).HasMaxLength(500);
        b.Property(x => x.IncludedRunIdsJson).HasColumnType("jsonb");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId });
    }
}

public sealed class ZhrPaymentBatchConfiguration : IEntityTypeConfiguration<ZhrPaymentBatch>
{
    public void Configure(EntityTypeBuilder<ZhrPaymentBatch> b)
    {
        b.ToZelosHrTable("zhr_payment_batches");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Channel).HasMaxLength(30);
        b.Property(x => x.Reference).HasMaxLength(60);
        b.Property(x => x.Status).HasMaxLength(20);
        b.Property(x => x.ItemsJson).HasColumnType("jsonb");
        b.Property(x => x.EventsJson).HasColumnType("jsonb");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.RunId });
    }
}

public sealed class ZhrAlertAcknowledgementConfiguration : IEntityTypeConfiguration<ZhrAlertAcknowledgement>
{
    public void Configure(EntityTypeBuilder<ZhrAlertAcknowledgement> b)
    {
        b.ToZelosHrTable("zhr_alert_acknowledgements");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.AlertKey).HasMaxLength(200);
        b.Property(x => x.Note).HasMaxLength(500);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.AlertKey }).IsUnique();
    }
}

public sealed class ZhrAttendanceCorrectionConfiguration : IEntityTypeConfiguration<ZhrAttendanceCorrection>
{
    public void Configure(EntityTypeBuilder<ZhrAttendanceCorrection> b)
    {
        b.ToZelosHrTable("zhr_attendance_corrections");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Reason).HasMaxLength(1000);
        b.Property(x => x.Status).HasMaxLength(20);
        b.Property(x => x.DecisionNote).HasMaxLength(1000);
        b.Property(x => x.DecidedBy).HasColumnType("text");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Status });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.AttendanceDate });
    }
}

public sealed class ZhrPayrollSettingsConfiguration : IEntityTypeConfiguration<ZhrPayrollSettings>
{
    public void Configure(EntityTypeBuilder<ZhrPayrollSettings> b)
    {
        b.ToZelosHrTable("zhr_payroll_settings");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.EmployeeSocialSecurityPercent).HasPrecision(6, 3);
        b.Property(x => x.EmployerSocialSecurityPercent).HasPrecision(6, 3);
        b.Property(x => x.OvertimeRate).HasPrecision(6, 3);
        b.Property(x => x.OvertimeRestDayRate).HasPrecision(6, 3);
        b.Property(x => x.StandardDailyHours).HasPrecision(6, 2);
        b.Property(x => x.StandardMonthlyHours).HasPrecision(8, 2);
        b.Property(x => x.MinNetPercentOfGross).HasPrecision(6, 2);
        b.Property(x => x.PayDayRule).HasMaxLength(20).HasDefaultValue("day");
        b.Property(x => x.NonWorkingDayRule).HasMaxLength(10).HasDefaultValue("before");
        b.Property(x => x.EnabledPaymentMethodsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.Property(x => x.DisbursementBank).HasMaxLength(120);
        b.Property(x => x.DisbursementAccountName).HasMaxLength(160);
        b.Property(x => x.DisbursementAccountNumber).HasMaxLength(60);
        b.Property(x => x.DisbursementBranch).HasMaxLength(120);
        b.Property(x => x.PayslipOptionsJson).HasColumnType("jsonb").HasDefaultValueSql("'{}'::jsonb");
        b.Property(x => x.PayslipRelease).HasMaxLength(20).HasDefaultValue("approved");
        b.Property(x => x.PayrollPreparerIdsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.Property(x => x.PayrollApproverIdsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.Property(x => x.CompensationApproverIdsJson).HasColumnType("jsonb").HasDefaultValueSql("'[]'::jsonb");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId }).IsUnique();
    }
}

public sealed class ZhrPayComponentConfiguration : IEntityTypeConfiguration<ZhrPayComponent>
{
    public void Configure(EntityTypeBuilder<ZhrPayComponent> b)
    {
        b.ToZelosHrTable("zhr_pay_components");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(80);
        b.Property(x => x.Kind).HasMaxLength(20);
        b.Property(x => x.Calculation).HasMaxLength(20);
        b.Property(x => x.Value).HasPrecision(14, 3);
        b.Property(x => x.AppliesTo).HasMaxLength(20);
        b.Property(x => x.Description).HasMaxLength(500);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Kind });
    }
}

public sealed class ZhrPayComponentAssignmentConfiguration : IEntityTypeConfiguration<ZhrPayComponentAssignment>
{
    public void Configure(EntityTypeBuilder<ZhrPayComponentAssignment> b)
    {
        b.ToZelosHrTable("zhr_pay_component_assignments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Value).HasPrecision(14, 3);
        b.Property(x => x.FromPeriod).HasMaxLength(7);
        b.Property(x => x.ToPeriod).HasMaxLength(7);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.ComponentId });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId });
    }
}

public sealed class ZhrEmployeeLoanConfiguration : IEntityTypeConfiguration<ZhrEmployeeLoan>
{
    public void Configure(EntityTypeBuilder<ZhrEmployeeLoan> b)
    {
        b.ToZelosHrTable("zhr_employee_loans");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(80);
        b.Property(x => x.Principal).HasPrecision(14, 2);
        b.Property(x => x.Installment).HasPrecision(14, 2);
        b.Property(x => x.StartPeriod).HasMaxLength(7);
        b.Property(x => x.Status).HasMaxLength(20);
        b.Property(x => x.Note).HasMaxLength(500);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId });
    }
}

public sealed class ZhrPayGroupConfiguration : IEntityTypeConfiguration<ZhrPayGroup>
{
    public void Configure(EntityTypeBuilder<ZhrPayGroup> b)
    {
        b.ToZelosHrTable("zhr_pay_groups");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.Name).HasMaxLength(80);
        b.Property(x => x.EntityName).HasMaxLength(160);
        b.Property(x => x.Country).HasMaxLength(2);
        b.Property(x => x.Currency).HasMaxLength(3);
        b.Property(x => x.Frequency).HasMaxLength(20);
        b.Property(x => x.VarianceThresholdPercent).HasPrecision(6, 2);
        b.Property(x => x.PaymentChannelsJson).HasColumnType("jsonb");
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.Property(x => x.UpdatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId });
    }
}

public sealed class ZhrPayGroupMemberConfiguration : IEntityTypeConfiguration<ZhrPayGroupMember>
{
    public void Configure(EntityTypeBuilder<ZhrPayGroupMember> b)
    {
        b.ToZelosHrTable("zhr_pay_group_members");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasDefaultValueSql("gen_random_uuid()");
        b.Property(x => x.TenantId).HasMaxLength(128);
        b.Property(x => x.OrgId).HasMaxLength(128);
        b.Property(x => x.CreatedBy).HasColumnType("text");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.PayGroupId });
    }
}

