namespace Trovesuite.Database.HumanResource.Entities;

/// <summary>ZelosHR application schema (<c>zeloshr</c>) — consumed by ZelosHR.Api.</summary>
public static class ZelosHrSchema
{
    public const string Name = "zeloshr";
}

public class ZhrBranch
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Address { get; set; }
    /// <summary>Country name (e.g. Ghana, Nigeria, United Kingdom).</summary>
    public string? Country { get; set; }
    public string? Description { get; set; }
    public bool IsArchived { get; set; }
    public string CustomFieldsData { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrDepartment
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public Guid? ParentDepartmentId { get; set; }
    public Guid? HeadOfDepartmentId { get; set; }
    public int? HeadcountCapacity { get; set; }
    public bool IsArchived { get; set; }
    public string CustomFieldsData { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrEmploymentType
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    /// <summary>Ghana defaults ship pre-loaded; cannot be renamed or deleted.</summary>
    public bool IsSystemDefault { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrIdCardType
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    /// <summary>Ghana defaults (National ID, Voter's ID, Driver's License, NHIS) cannot be renamed or deleted.</summary>
    public bool IsSystemDefault { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrCompanyProfile
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string LegalName { get; set; } = default!;
    public string? TradingName { get; set; }
    public string? Industry { get; set; }
    public string? CompanySize { get; set; }
    public string? BusinessRegistrationNumber { get; set; }
    public string? Tin { get; set; }
    public string? PrimaryWorkCountry { get; set; }
    public string? CompanyEmail { get; set; }
    public string? Website { get; set; }
    /// <summary>File Management registry id (human_resource.hr_document_paths.id) — not a direct URL.</summary>
    public string? LogoDocumentId { get; set; }
    public string? BannerDocumentId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrCompanyOffice
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Country { get; set; }
    public string? City { get; set; }
    public string? Phone { get; set; }
    /// <summary>Client-managed flag — uniqueness across an org's offices is not enforced.</summary>
    public bool IsHeadOffice { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrCompanyLocalization
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    /// <summary>IANA time zone id (e.g. "Africa/Accra").</summary>
    public string TimeZone { get; set; } = default!;
    /// <summary>FK to core_platform.cp_currencies (seeded per tenant).</summary>
    public string CurrencyId { get; set; } = default!;
    public string DateFormat { get; set; } = default!;
    public string NumberFormat { get; set; } = default!;
    public string FirstDayOfWeek { get; set; } = default!;
    public string YearStartMonth { get; set; } = default!;
    public int YearStartDay { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrEmployee
{
    public Guid Id { get; set; }
    public string EmployeeCode { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;

    /// <summary>core_platform.cp_users.id (text). Nullable until finalise/import.</summary>
    public string? UserId { get; set; }

    public string FullName { get; set; } = default!;

    // Legacy directory fields (kept for backward compatibility; optional on drafts).
    public string? FirstName { get; set; }
    public string? MiddleName { get; set; }
    public string? LastName { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? Nationality { get; set; }
    public string? NationalityIdType { get; set; }
    public DateOnly? IdIssueDate { get; set; }
    public DateOnly? IdExpiryDate { get; set; }
    public string? IdNumber { get; set; }
    public string? GhanaCardNumber { get; set; }
    public string? PersonalEmail { get; set; }
    public string? WorkEmail { get; set; }
    public string? PersonalPhone { get; set; }
    public string? Phone { get; set; }
    public string? LinkedInUrl { get; set; }
    public string? ResidentialAddress { get; set; }
    public string? GhanaPostGps { get; set; }
    public string? State { get; set; }
    public string? ProfilePhotoUrl { get; set; }

    public string LifecycleState { get; set; } = default!;
    public string LifecycleStatus { get; set; } = default!;
    public bool IsDraft { get; set; }

    public string? JobTitle { get; set; }
    public Guid? DepartmentId { get; set; }
    public Guid? BranchId { get; set; }
    public string? EmploymentType { get; set; }
    public Guid? EmploymentTypeId { get; set; }
    public string? WorkArrangement { get; set; }
    public string? WorkLocation { get; set; }
    public string? PayGrade { get; set; }
    public Guid? ManagerId { get; set; }
    public Guid? ReportsToId { get; set; }
    public Guid? DottedLineManagerId { get; set; }
    public string? EmploymentStatus { get; set; }
    public string? ContractType { get; set; }
    public DateOnly? ProbationEndDate { get; set; }
    public DateOnly? EmploymentStartDate { get; set; }
    public DateOnly? StartDate { get; set; }
    public string? WorkingHours { get; set; }
    public string? NoticePeriod { get; set; }

    public decimal? GrossSalary { get; set; }
    public string? PayFrequency { get; set; }
    public decimal? AnnualizedCost { get; set; }
    public DateOnly? SalaryEffectiveFrom { get; set; }
    /// <summary>FK to core_platform.cp_currencies (seeded per tenant).</summary>
    public string? CurrencyId { get; set; }
    public List<string> DocumentIds { get; set; } = [];
    public string? SsnitNumber { get; set; }
    public string? TinNumber { get; set; }
    public string? Tier2PensionProvider { get; set; }
    public string? Tier3PensionProvider { get; set; }
    public string? PaymentMethod { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? MobileMoneyNumber { get; set; }

    public bool IsDeleted { get; set; }
    public string CustomFieldsData { get; set; } = "{}";
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrCustomFieldDefinition
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string EntityType { get; set; } = default!;
    public string FieldKey { get; set; } = default!;
    public string Label { get; set; } = default!;
    public string? Description { get; set; }
    public string FieldType { get; set; } = default!;
    public bool IsRequired { get; set; }
    public bool IsSensitive { get; set; }
    public bool IsFilterable { get; set; }
    public bool IsSearchable { get; set; }
    public int DisplayOrder { get; set; }
    public string? SectionName { get; set; }
    public int SectionOrder { get; set; }
    public string? Options { get; set; }
    public string? ValidationRules { get; set; }
    public string? DefaultValue { get; set; }
    public string? Placeholder { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsDeleted { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrCustomFieldAuditLog
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string EntityType { get; set; } = default!;
    public Guid EntityId { get; set; }
    public string FieldKey { get; set; } = default!;
    public string? OldValue { get; set; }
    public string? NewValue { get; set; }
    public string ChangedBy { get; set; } = default!;
    public DateTimeOffset ChangedAt { get; set; }
    public string ChangeType { get; set; } = default!;
}

public class ZhrEmployeeEducation
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Institution { get; set; } = default!;
    public string? Degree { get; set; }
    public string? FieldOfStudy { get; set; }
    public DateOnly? StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool IsCurrent { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeCertification
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Name { get; set; } = default!;
    public string? IssuingBody { get; set; }
    public DateOnly? IssueDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
    public string? CredentialUrl { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrAuditLog
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public DateTimeOffset OccurredAt { get; set; }
    public string ActionTitle { get; set; } = default!;
    public string? ActionDescription { get; set; }
    public Guid? EmployeeId { get; set; }
    public string? EmployeeDisplayCode { get; set; }
    public string? EmployeeFullName { get; set; }
    public string? ActorId { get; set; }
    public string ActorFullName { get; set; } = default!;
    public string Category { get; set; } = default!;
    public string Severity { get; set; } = default!;
    public bool IsFlagged { get; set; }
    public bool IsSensitiveRead { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class ZhrLifecycleEvent
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string EventType { get; set; } = default!;
    public string? DepartmentName { get; set; }
    public string? BranchName { get; set; }
    public DateOnly DueDate { get; set; }
    public string Status { get; set; } = default!;
    public string Urgency { get; set; } = default!;
    public string CustomFieldsData { get; set; } = "{}";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrAttendanceRecord
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string? EmployeeCode { get; set; }
    public string? DepartmentName { get; set; }
    public string? BranchName { get; set; }
    public DateOnly AttendanceDate { get; set; }
    public TimeOnly? ClockIn { get; set; }
    public TimeOnly? ClockOut { get; set; }
    public string Status { get; set; } = default!;
    public decimal? HoursWorked { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class ZhrLeaveRequest
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public Guid? LeaveTypeId { get; set; }
    public string LeaveType { get; set; } = default!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public decimal DaysRequested { get; set; }
    public string Status { get; set; } = default!;
    public string ApprovalStage { get; set; } = "pending_line_manager";
    public string? LmApproverId { get; set; }
    public DateTimeOffset? LmDecidedAt { get; set; }
    public string? HodApproverId { get; set; }
    public DateTimeOffset? HodDecidedAt { get; set; }
    public string? ApproverId { get; set; }
    public string? ApproverName { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }
    public string? Notes { get; set; }
    public DateTimeOffset SubmittedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrLeaveType
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? CountryCode { get; set; }
    public decimal DefaultEntitledDays { get; set; }
    public bool IsPaid { get; set; } = true;
    public bool IsActive { get; set; } = true;
    public string AccrualMethod { get; set; } = "front_loaded";
    public bool CarryOverAllowed { get; set; }
    /// <summary>JSON array of employment types; null = all types.</summary>
    public string? AppliesToEmploymentTypes { get; set; }
    public int? MinNoticeWorkingDays { get; set; }
    public int? MaxConsecutiveDays { get; set; }
    public bool RequiresSupportingDocument { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrPublicHoliday
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string CountryCode { get; set; } = default!;
    public string Name { get; set; } = default!;
    public DateOnly HolidayDate { get; set; }
    public bool IsRecurring { get; set; }
    public Guid? BranchId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrLeaveBalance
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public Guid? LeaveTypeId { get; set; }
    public string LeaveType { get; set; } = default!;
    public decimal EntitledDays { get; set; }
    public decimal UsedDays { get; set; }
    public decimal RemainingDays { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrJobPosting
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Title { get; set; } = default!;
    public string? DepartmentName { get; set; }
    public string? BranchName { get; set; }
    public string? EmploymentType { get; set; }
    public string Status { get; set; } = default!;
    public int ApplicantsCount { get; set; }
    public DateOnly PostedAt { get; set; }
    public DateOnly? ClosingDate { get; set; }
}

public class ZhrOnboardingTask
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string TaskName { get; set; } = default!;
    public string Category { get; set; } = default!;
    public DateOnly DueDate { get; set; }
    public string Status { get; set; } = default!;
    public string? AssignedTo { get; set; }
}

public class ZhrPerformanceReview
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string ReviewPeriod { get; set; } = default!;
    public string? ReviewerName { get; set; }
    public string? OverallRating { get; set; }
    public string Status { get; set; } = default!;
    public DateOnly DueDate { get; set; }
}

public class ZhrDisciplinaryCase
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string CaseType { get; set; } = default!;
    public string Severity { get; set; } = default!;
    public string Status { get; set; } = default!;
    public DateOnly OpenedAt { get; set; }
    public string? Description { get; set; }
}

public class ZhrEmployeeDocument
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string? EmployeeFullName { get; set; }
    public string Category { get; set; } = default!;
    public string FileName { get; set; } = default!;
    public long FileSizeBytes { get; set; }
    public string BlobUrl { get; set; } = default!;
    public string ContentType { get; set; } = default!;
    public string? UploadedBy { get; set; }
    public DateTimeOffset UploadedAt { get; set; }
    public bool IsDeleted { get; set; }
    public string CustomFieldsData { get; set; } = "{}";
    /// <summary>Legacy HR documents module status.</summary>
    public string? Status { get; set; }
    public int? FileSizeKb { get; set; }
    public string? DocumentName { get; set; }
}
