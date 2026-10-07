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
    public string? LegalName { get; set; }
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

/// <summary>Office IP or range that may clock in from the web portal.</summary>
public class ZhrOfficeNetwork
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Label { get; set; } = default!;
    /// <summary>Single IP, CIDR, or IPv4 start-end (for example 10.0.0.1-10.0.0.40).</summary>
    public string Notation { get; set; } = default!;
    public string StartAddress { get; set; } = default!;
    public string EndAddress { get; set; } = default!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Optional attendance checks. Both flags stay off until an admin turns them on.</summary>
public class ZhrAttendanceEnforcement
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public bool RequireOfficeNetwork { get; set; }
    public bool TrackLocation { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Office point used when location tracking is enabled.</summary>
public class ZhrOfficeLocation
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Label { get; set; } = default!;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int RadiusMeters { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>One JSON document per time-settings screen (rules, capture, schedules, approval).</summary>
public class ZhrTimeSetting
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Key { get; set; } = default!;
    public string Payload { get; set; } = default!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrEmployeeIdFormat
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Prefix { get; set; } = default!;
    public int DigitCount { get; set; }
    public int StartingNumber { get; set; }
    /// <summary>hyphen · none · underscore · slash</summary>
    public string Separator { get; set; } = default!;
    public bool AutoGenerate { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Regional formats and the year start. Time zone and currency are the tenant's, kept in Core Platform.</summary>
public class ZhrCompanyLocalization
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
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
    public string EmployeeCodeSystem { get; set; } = default!;
    public string? EmployeeCodeCustom { get; set; }
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
    public decimal? NetSalary { get; set; }

    public string? MaritalStatus { get; set; }
    public string? NextOfKinName { get; set; }
    public string? NextOfKinPhone { get; set; }
    public string? RelationshipToNextOfKin { get; set; }

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

public class ZhrEmployeeIdentification
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public Guid IdCardTypeId { get; set; }
    public string IdNumber { get; set; } = default!;
    public DateOnly? IdIssueDate { get; set; }
    public DateOnly? IdExpiryDate { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeEmergencyContact
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string EmergencyContactName { get; set; } = default!;
    public string? EmergencyContactPhone { get; set; }
    public string? Relationship { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeePaymentMethod
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string PaymentMode { get; set; } = default!;
    public string? BankName { get; set; }
    public string? AccountName { get; set; }
    public string? AccountNumber { get; set; }
    public string? BranchName { get; set; }
    public bool IsPrimary { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeMedicalProfile
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string? BloodGroup { get; set; }
    public bool HasMedicalCondition { get; set; }
    public bool TakesRegularMedication { get; set; }
    public string? DisabilityStatus { get; set; }
    public bool RequiresAccommodation { get; set; }
    public string? AccommodationDetails { get; set; }
    public string? EmergencyMedicalNotes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeMedicalCondition
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Condition { get; set; } = default!;
    public string? Severity { get; set; }
    public string? Notes { get; set; }
    public DateOnly? DiagnosedDate { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeAllergy
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Allergen { get; set; } = default!;
    public string? Reaction { get; set; }
    public string? Severity { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeMedication
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Name { get; set; } = default!;
    public string? Dosage { get; set; }
    public string? Frequency { get; set; }
    public string? Notes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeSkill
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Name { get; set; } = default!;
    public string? Proficiency { get; set; }
    public int? YearsOfExperience { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeExperience
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Company { get; set; } = default!;
    public string? JobTitle { get; set; }
    public string? EmploymentType { get; set; }
    public string? Location { get; set; }
    public DateOnly? StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool IsCurrent { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployeeReferral
{
    public Guid Id { get; set; }
    public Guid EmployeeId { get; set; }
    public string Name { get; set; } = default!;
    public string? JobTitle { get; set; }
    public string? Company { get; set; }
    public string? Relationship { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
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
    public int Openings { get; set; } = 1;
    /// <summary>Monthly pay budgeted per opening, in the company currency.</summary>
    public decimal? BudgetMonthly { get; set; }
    public Guid? HiringManagerId { get; set; }
    public DateOnly? TargetStartDate { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Someone applying for a requisition, moved through the hiring stages.</summary>
public class ZhrCandidate
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid JobPostingId { get; set; }
    public string FullName { get; set; } = default!;
    public string? Email { get; set; }
    public string? Phone { get; set; }
    /// <summary>Careers page, LinkedIn, Referral, Job board, Walk-in…</summary>
    public string? Source { get; set; }
    /// <summary>applied · screening · interview · assessment · offer · hired · rejected</summary>
    public string Stage { get; set; } = "applied";
    /// <summary>1–5, or null when nobody has rated them yet.</summary>
    public int? Rating { get; set; }
    public string? Notes { get; set; }
    public DateOnly AppliedOn { get; set; }
    /// <summary>The pre-hire employee record created when they were hired.</summary>
    public Guid? EmployeeId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
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
    /// <summary>onboarding · offboarding — the same checklist shape serves both ends.</summary>
    public string Kind { get; set; } = "onboarding";
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
    /// <summary>The manager who owns the review.</summary>
    public Guid? ReviewerId { get; set; }
    /// <summary>1.0–5.0 once the manager has rated it.</summary>
    public decimal? Rating { get; set; }
    public DateOnly? SharedOn { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>A manager's private note about someone. Only its author reads it until it is escalated, which cannot be undone.</summary>
public class ZhrCoachingNote
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    /// <summary>Platform user id of the author.</summary>
    public string AuthorId { get; set; } = default!;
    public string Body { get; set; } = default!;
    public bool Escalated { get; set; }
    public DateTimeOffset? EscalatedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
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
    /// <summary>What was decided when the case was finalised or dismissed.</summary>
    public string? Outcome { get; set; }
    public DateOnly? ClosedOn { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    /// <summary>Who raised the case.</summary>
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ZhrEmployeeChangeRequest
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    /// <summary>Dot path matching employee update JSON (e.g. identity.full_name, education).</summary>
    public string FieldPath { get; set; } = default!;
    public string? OldValueJson { get; set; }
    public string NewValueJson { get; set; } = default!;
    /// <summary>pending | approved | rejected | superseded</summary>
    public string Status { get; set; } = default!;
    public string RequestedBy { get; set; } = default!;
    public string? ReviewedBy { get; set; }
    public string? ReviewNote { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
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
    /// <summary>When the document stops being valid; feeds the compliance alerts.</summary>
    public DateOnly? ExpiresOn { get; set; }
    /// <summary>The file registry id (core_platform.cp_document_paths) the file was stored under.</summary>
    public string? FileDocumentId { get; set; }
}

/// <summary>
/// One version of an employee's pay. Pay is never edited in place: every change is a new
/// version, proposed by one person and approved by another, so past pay stays readable.
/// The version in force on a date is the latest approved one effective on or before it.
/// </summary>
public class ZhrCompensationVersion
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public int VersionNumber { get; set; }
    public DateOnly EffectiveFrom { get; set; }
    /// <summary>Monthly basic salary: the SSNIT base.</summary>
    public decimal BaseAmount { get; set; }
    /// <summary>Recurring allowances: [{"name","amount","taxable"}].</summary>
    public string ComponentsJson { get; set; } = "[]";
    public string Currency { get; set; } = "GHS";
    public string PayFrequency { get; set; } = "monthly";
    public string Reason { get; set; } = default!;
    /// <summary>pending · approved · rejected · cancelled</summary>
    public string Status { get; set; } = default!;
    public Guid? SupersedesVersionId { get; set; }
    /// <summary>Shared by every version a single proposal wrote (a bulk change writes one per person).</summary>
    public Guid? ChangeRequestId { get; set; }
    /// <summary>percent · fixed_increase · new_amount — how the proposal was expressed.</summary>
    public string? ChangeType { get; set; }
    public decimal? ChangeValue { get; set; }
    public string ProposedBy { get; set; } = default!;
    public DateTimeOffset ProposedAt { get; set; }
    public string? DecidedBy { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }
    public string? DecisionNote { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>A payroll run for one period. Its figures are on its lines; totals are kept for listing.</summary>
public class ZhrPayrollRun
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    /// <summary>yyyy-MM</summary>
    public string Period { get; set; } = default!;
    public DateOnly PeriodStart { get; set; }
    public DateOnly PeriodEnd { get; set; }
    public DateOnly PayDate { get; set; }
    /// <summary>regular · off_cycle</summary>
    public string Kind { get; set; } = "regular";
    /// <summary>draft · calculated · pending_approval · approved · paid · cancelled</summary>
    public string Status { get; set; } = default!;
    public string Currency { get; set; } = "GHS";
    public string? RulePackVersion { get; set; }
    public int EmployeeCount { get; set; }
    public decimal TotalGross { get; set; }
    public decimal TotalDeductions { get; set; }
    public decimal TotalEmployerCost { get; set; }
    public decimal TotalNet { get; set; }
    public string? PreparedBy { get; set; }
    public DateTimeOffset? SubmittedAt { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTimeOffset? ApprovedAt { get; set; }
    public DateTimeOffset? PaidAt { get; set; }
    /// <summary>Append-only history: [{"at","by","action","note"}].</summary>
    public string EventsJson { get; set; } = "[]";
    /// <summary>Warnings acknowledged before calculating: [{"check_id","by","reason","at"}].</summary>
    public string AcknowledgementsJson { get; set; } = "[]";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>One person's pay in a run, as calculated. A payslip is a statement of this line.</summary>
public class ZhrPayrollLine
{
    public Guid Id { get; set; }
    public Guid RunId { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeName { get; set; } = default!;
    public string? EmployeeCode { get; set; }
    public string? DepartmentName { get; set; }
    public Guid? CompensationVersionId { get; set; }
    /// <summary>[{"code","label","amount"}]</summary>
    public string EarningsJson { get; set; } = "[]";
    public string DeductionsJson { get; set; } = "[]";
    public string EmployerContributionsJson { get; set; } = "[]";
    public decimal Gross { get; set; }
    public decimal TotalDeductions { get; set; }
    public decimal TotalEmployerContributions { get; set; }
    public decimal Net { get; set; }
    public decimal? PreviousNet { get; set; }
    public string Currency { get; set; } = "GHS";
    public string? PaymentChannel { get; set; }
    public string? PaymentDestinationMasked { get; set; }
    /// <summary>["net_change","new_payee",...]</summary>
    public string FlagsJson { get; set; } = "[]";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>
/// A fixed weekly pattern of working hours. What attendance measures lateness and hours against
/// for staff who are not rostered. Kept once assigned, so history still resolves.
/// </summary>
public class ZhrWorkPattern
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    /// <summary>[{"weekday":1..7,"start":"HH:mm","end":"HH:mm"}]; days not listed are non-working.</summary>
    public string DaysJson { get; set; } = "[]";
    public int BreakMinutes { get; set; }
    public bool BreakPaid { get; set; }
    /// <summary>Null takes the company figure from attendance rules.</summary>
    public int? GraceMinutes { get; set; }
    public bool Archived { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Who follows which pattern, from when. Never edited: a later assignment supersedes it. A null
/// pattern means rostered — the person's expectation comes from published shifts.
/// </summary>
public class ZhrPatternAssignment
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid? PatternId { get; set; }
    /// <summary>company · branch · department · employee</summary>
    public string Scope { get; set; } = default!;
    /// <summary>Employee id, department id or branch id; null for company.</summary>
    public string? Target { get; set; }
    public DateOnly EffectiveFrom { get; set; }
    public string Reason { get; set; } = default!;
    public string? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>One day's rostered expectation. A published shift beats any pattern underneath it.</summary>
public class ZhrShift
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    /// <summary>Null is an open shift with nobody on it yet.</summary>
    public Guid? EmployeeId { get; set; }
    public DateOnly Date { get; set; }
    /// <summary>HH:mm</summary>
    public string Start { get; set; } = default!;
    public string End { get; set; } = default!;
    public int BreakMinutes { get; set; }
    public string Position { get; set; } = default!;
    public Guid? BranchId { get; set; }
    public Guid? DepartmentId { get; set; }
    public string? Note { get; set; }
    /// <summary>draft · published</summary>
    public string State { get; set; } = default!;
    public DateTimeOffset? PublishedAt { get; set; }
    public bool ChangedSincePublish { get; set; }
    public bool Cancelled { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>The roster's trail. Append-only.</summary>
public class ZhrShiftChange
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid ShiftId { get; set; }
    /// <summary>created · edited · assigned · cancelled · published</summary>
    public string Action { get; set; } = default!;
    public string Summary { get; set; } = default!;
    public string? Reason { get; set; }
    public string? By { get; set; }
    public DateTimeOffset At { get; set; }
}

/// <summary>
/// Someone looked at a disagreement between attendance and leave and said what they did. The key
/// is "kind:employee:first date", so the record survives the item being recomputed.
/// </summary>
public class ZhrLeaveReconciliation
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Key { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string Action { get; set; } = default!;
    public string? Note { get; set; }
    public string? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>One change to an employee's employment status. Append-only.</summary>
public class ZhrEmployeeStatusChange
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string? FromStatus { get; set; }
    public string ToStatus { get; set; } = default!;
    public DateOnly EffectiveDate { get; set; }
    public string? Reason { get; set; }
    /// <summary>manual · lifecycle · registration</summary>
    public string Source { get; set; } = "manual";
    public string? ChangedBy { get; set; }
    public DateTimeOffset ChangedAt { get; set; }
}

/// <summary>One person leaving: clearance and final settlement. Opened from an exit event.</summary>
public class ZhrOffboardingCase
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Reference { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public Guid? LifecycleEventId { get; set; }
    public string Reason { get; set; } = default!;
    public DateOnly NoticeGivenOn { get; set; }
    public DateOnly LastWorkingDay { get; set; }
    public int NoticePeriodDays { get; set; }
    public string State { get; set; } = "open";
    public bool AssetsReturned { get; set; }
    public bool AccessRevoked { get; set; }
    public bool SettlementCalculated { get; set; }
    public bool HandoverDone { get; set; }
    public bool ExitInterviewDone { get; set; }
    public decimal? AccruedLeaveDays { get; set; }
    public decimal? FinalSettlement { get; set; }
    public string Currency { get; set; } = "GHS";
    public DateTimeOffset? SentToPayrollAt { get; set; }
    public DateTimeOffset? ClosedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>One person's timesheet for a pay period ("yyyy-MM"): the review decision on their hours.</summary>
public class ZhrTimesheet
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Period { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    /// <summary>pending_review, changes_requested or approved.</summary>
    public string Status { get; set; } = default!;
    public string? Comment { get; set; }
    public string? DecidedBy { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>A pay period that has been closed. Its days, corrections and approvals are read-only afterwards.</summary>
public class ZhrPayPeriodClosure
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Period { get; set; } = default!;
    public string? ClosedBy { get; set; }
    public DateTimeOffset ClosedAt { get; set; }
}

/// <summary>Pay outside somebody's package (a bonus, an award, a settlement), paid by the runs after its date.</summary>
public class ZhrPayrollOneOff
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string Component { get; set; } = default!;
    public decimal Amount { get; set; }
    /// <summary>gross · net (grossed up so the person receives the amount).</summary>
    public string Basis { get; set; } = "gross";
    public bool Taxable { get; set; } = true;
    public DateOnly PayFrom { get; set; }
    /// <summary>once · monthly</summary>
    public string Recurrence { get; set; } = "once";
    public int? Months { get; set; }
    public string Note { get; set; } = default!;
    public bool Cancelled { get; set; }
    public string? CancelReason { get; set; }
    /// <summary>Runs whose calculation included it: ["run id", …].</summary>
    public string IncludedRunIdsJson { get; set; } = "[]";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>The lines of an approved run going out on one channel, tracked until each has settled.</summary>
public class ZhrPaymentBatch
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid RunId { get; set; }
    /// <summary>bank_transfer · mobile_money</summary>
    public string Channel { get; set; } = default!;
    public string Reference { get; set; } = default!;
    /// <summary>initiated · sent · confirmed · failed</summary>
    public string Status { get; set; } = default!;
    /// <summary>[{employee_id, name, amount, currency, destination_masked, status, failure_reason, attempts}]</summary>
    public string ItemsJson { get; set; } = "[]";
    public string EventsJson { get; set; } = "[]";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Someone recorded a decision on a compliance alert. Keyed "kind:source id:yyyyMMdd", so a new date raises a new alert.</summary>
public class ZhrAlertAcknowledgement
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string AlertKey { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string? Note { get; set; }
    public string? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A request to correct a day's clock-in or clock-out. Nothing changes until someone else approves it.</summary>
public class ZhrAttendanceCorrection
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public DateOnly AttendanceDate { get; set; }
    public TimeOnly? OriginalClockIn { get; set; }
    public TimeOnly? OriginalClockOut { get; set; }
    public TimeOnly? ClockIn { get; set; }
    public TimeOnly? ClockOut { get; set; }
    public string Reason { get; set; } = default!;
    /// <summary>pending · approved · rejected · cancelled</summary>
    public string Status { get; set; } = "pending";
    public string? DecidedBy { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }
    public string? DecisionNote { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}
