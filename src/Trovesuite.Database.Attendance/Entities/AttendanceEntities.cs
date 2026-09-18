namespace Trovesuite.Database.Attendance.Entities;

public class AttAttendanceRecord
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
    public bool AutoClosed { get; set; }
    public string CaptureSource { get; set; } = "web";
    public bool IsAdjusted { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AttEmployee
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string EmployeeCode { get; set; } = default!;
    public string FirstName { get; set; } = default!;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = default!;
    public string? JobTitle { get; set; }
    public string? DepartmentName { get; set; }
    public string? BranchName { get; set; }
    public Guid? ReportsToEmployeeId { get; set; }
    public bool IsLineManager { get; set; }
    public bool IsHeadOfDepartment { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AttPunch
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public Guid AttendanceId { get; set; }
    public string PunchType { get; set; } = default!;
    public DateTimeOffset PunchedAt { get; set; }
    public string Source { get; set; } = "web";
    public Guid? DeviceId { get; set; }
    public bool IsSuperseded { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AttAdjustment
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public Guid EmployeeId { get; set; }
    public Guid? AttendanceId { get; set; }
    public DateOnly AttendanceDate { get; set; }
    public string Kind { get; set; } = default!;
    public string? PunchType { get; set; }
    public TimeOnly? PunchTime { get; set; }
    public Guid? OriginalPunchId { get; set; }
    public string Reason { get; set; } = default!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}

public class AttDevice
{
    public Guid Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Vendor { get; set; }
    public string? Model { get; set; }
    /// <summary>ZKTeco device SN — used as ADMS identity (globally unique when set).</summary>
    public string? Serial { get; set; }
    public string? Location { get; set; }
    /// <summary>When false, ADMS ingest ignores this device.</summary>
    public bool IsEnabled { get; set; } = true;
    public DateTimeOffset? LastSeenAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedById { get; set; }
    public string? UpdatedById { get; set; }
}
