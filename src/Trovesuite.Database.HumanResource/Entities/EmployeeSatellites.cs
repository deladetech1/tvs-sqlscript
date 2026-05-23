using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.HumanResource.Entities;

/// <summary>
/// SSNIT / TIN / pension provider links. One row per employee.
/// Sensitive — masked at the service layer for callers without
/// the "reveal-sensitive" permission.
/// </summary>
public class EmployeeStatutory : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string EmployeeId { get; set; } = default!;
    public string? SsnitNumber { get; set; }
    public string? Tin { get; set; }
    public string? Tier2ProviderId { get; set; }
    public string? Tier3ProviderId { get; set; }
}

/// <summary>
/// Bank / branch / account used for payroll disbursement.
/// Sensitive — account number masked at the service layer.
/// </summary>
public class EmployeePaymentMethod : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string EmployeeId { get; set; } = default!;
    public string BankId { get; set; } = default!;
    public string? BranchId { get; set; }
    public string AccountName { get; set; } = default!;
    public string AccountNumber { get; set; } = default!;
    public bool IsPrimary { get; set; } = true;
}

/// <summary>
/// Append-only salary history. Each raise / promotion / correction
/// creates a new row with EffectiveFrom set; previous current row gets
/// EffectiveTo populated and IsCurrent = false.
/// </summary>
public class EmployeeSalary : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string EmployeeId { get; set; } = default!;
    public decimal GrossMonthlySalary { get; set; }
    public string PayFrequency { get; set; } = "MONTHLY"; // MONTHLY | BIWEEKLY | WEEKLY
    public string? PayGrade { get; set; }
    public string CurrencyId { get; set; } = default!;
    public DateOnly EffectiveFrom { get; set; }
    public DateOnly? EffectiveTo { get; set; }
    public bool IsCurrent { get; set; } = true;
    public string? Reason { get; set; } // INITIAL | RAISE | PROMOTION | CORRECTION
}

public class EmployeeEmergencyContact : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string EmployeeId { get; set; } = default!;
    public string FullName { get; set; } = default!;
    public string? Relationship { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Email { get; set; }
    public bool IsPrimary { get; set; } = false;
}

/// <summary>
/// Link table tying an employee to a document blob (typed: CONTRACT, NATIONAL_ID,
/// CERTIFICATE, OTHER) via hr_document_paths.
/// </summary>
public class EmployeeDocument : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string EmployeeId { get; set; } = default!;
    public string DocumentId { get; set; } = default!;
    public string DocumentType { get; set; } = default!;
}
