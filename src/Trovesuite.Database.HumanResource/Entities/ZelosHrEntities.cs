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
    public bool IsArchived { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrDepartment
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public Guid? ParentDepartmentId { get; set; }
    public Guid? HeadOfDepartmentId { get; set; }
    public bool IsArchived { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public class ZhrEmployee
{
    public Guid Id { get; set; }
    public string EmployeeCode { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string FirstName { get; set; } = default!;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = default!;
    public DateOnly DateOfBirth { get; set; }
    public string Gender { get; set; } = default!;
    public string Nationality { get; set; } = default!;
    public string GhanaCardNumber { get; set; } = default!;
    public string PersonalEmail { get; set; } = default!;
    public string PersonalPhone { get; set; } = default!;
    public string ResidentialAddress { get; set; } = default!;
    public string GhanaPostGps { get; set; } = default!;
    public string LifecycleState { get; set; } = "Pre-hire";
    public string? JobTitle { get; set; }
    public Guid? DepartmentId { get; set; }
    public Guid? BranchId { get; set; }
    public string? EmploymentType { get; set; }
    public Guid? ManagerId { get; set; }
    public string EmploymentStatus { get; set; } = "Active";
    public string? ContractType { get; set; } = "Permanent";
    public DateOnly? ProbationEndDate { get; set; }
    public DateOnly? EmploymentStartDate { get; set; }
    public bool IsDeleted { get; set; }
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
    public string LeaveType { get; set; } = default!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public decimal DaysRequested { get; set; }
    public string Status { get; set; } = default!;
    public string? ApproverName { get; set; }
    public DateTimeOffset SubmittedAt { get; set; }
}

public class ZhrLeaveBalance
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public string EmployeeFullName { get; set; } = default!;
    public string LeaveType { get; set; } = default!;
    public decimal EntitledDays { get; set; }
    public decimal UsedDays { get; set; }
    public decimal RemainingDays { get; set; }
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
    public string EmployeeFullName { get; set; } = default!;
    public string DocumentName { get; set; } = default!;
    public string Category { get; set; } = default!;
    public int FileSizeKb { get; set; }
    public string UploadedBy { get; set; } = default!;
    public DateTimeOffset UploadedAt { get; set; }
    public string Status { get; set; } = "Active";
}
