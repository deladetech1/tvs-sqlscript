using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

/// <summary>
/// Membership table: rows here are users onboarded as HR employees.
/// The user identity itself lives in core_platform.cp_users; this table
/// references it and carries HR-specific fields (job, reporting line, contact).
/// Sensitive payroll/statutory/bank data lives in the satellite tables.
/// </summary>
public class Employee : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string UserId { get; set; } = default!;

    public string? EmployeeCode { get; set; }

    // Identity extras that don't belong on cp_users (HR-app-specific)
    public string? PersonalEmail { get; set; }
    public string? PhoneNumber { get; set; }
    public string? WorkEmail { get; set; }
    public string? Linkedin { get; set; }
    public string? GpsDigitalAddress { get; set; }
    public string? State { get; set; }
    public string? ResidentialAddress { get; set; }
    public string? Nationality { get; set; }
    public string? NationalityIdType { get; set; }
    public string? NationalityIdNumber { get; set; }

    // Employment
    public string? JobTitle { get; set; }
    public string? DepartmentId { get; set; }
    public string? EmploymentType { get; set; }
    public string? WorkArrangement { get; set; }
    public string? WorkLocation { get; set; }
    public string? PayGrade { get; set; }
    public DateOnly? StartDate { get; set; }
    public DateOnly? ProbationEndDate { get; set; }
    public decimal? WorkingHoursPerWeek { get; set; }
    public int? NoticePeriodDays { get; set; }

    // Reporting line (self-FK)
    public string? LineManagerId { get; set; }
    public string? DottedLineManagerId { get; set; }

    public string EmploymentStatus { get; set; } = "ACTIVE";
}
