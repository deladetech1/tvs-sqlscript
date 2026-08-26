namespace Trovesuite.Database.MyStoreGuard.Entities;

/// <summary>
/// Someone standing behind a customer's installment plan.
///
/// Belongs to the CUSTOMER, not the sale: the same brother-in-law backs three
/// purchases and should be captured once. Which guarantors backed a particular
/// plan is recorded separately, with a snapshot — a guarantor who later moves
/// house must not silently rewrite an agreement already signed.
/// </summary>
public class Guarantor
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string CustomerId { get; set; } = default!;

    public string Fullname { get; set; } = default!;
    public string? Occupation { get; set; }
    public string? Address { get; set; }
    public string? DigitalAddress { get; set; }
    /// <summary>How they know the customer — brother, employer, friend.</summary>
    public string? Relationship { get; set; }
    public string? IdType { get; set; }
    public string? IdNumber { get; set; }
    public string? Notes { get; set; }

    public bool IsActive { get; set; } = true;

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

/// <summary>
/// A guarantor's phone numbers and email addresses — several of each.
///
/// Same shape as msg_customer_contacts, deliberately: a guarantor is chased for
/// money when a customer stops paying, and one number that no longer answers is
/// how that fails.
/// </summary>
public class GuarantorContact
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string GuarantorId { get; set; } = default!;

    /// <summary>'email' or 'phone'.</summary>
    public string Kind { get; set; } = default!;
    public string Value { get; set; } = default!;
    public bool IsPrimary { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// A file held against a guarantor — an ID photo, a signed undertaking.
///
/// The file itself lives in blob storage through the existing file manager;
/// this only keeps the document id and what it is.
/// </summary>
public class GuarantorDocument
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string GuarantorId { get; set; } = default!;

    public string DocumentId { get; set; } = default!;
    public string? DocType { get; set; }
    public string? Description { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// Which guarantors backed which sale, and what they looked like at the time.
///
/// The snapshot is the point: the guarantor record goes on changing, but what
/// was agreed on the day does not.
/// </summary>
public class SaleGuarantor
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string GuarantorId { get; set; } = default!;
    public System.Text.Json.JsonDocument? Snapshot { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>
/// A penalty charged on a late installment.
///
/// The amount AND the settings that produced it are frozen here at capture.
/// Loandrift versions its penalty config for the same reason: without it, an
/// admin editing a rate silently rewrites what customers were already charged.
/// </summary>
public class InstallmentPenalty
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PlanId { get; set; } = default!;
    /// <summary>The period that was late.</summary>
    public string ScheduleId { get; set; } = default!;

    public decimal Amount { get; set; }
    public decimal PaidAmount { get; set; }
    /// <summary>OUTSTANDING, PARTIALLY_PAID, CLEARED or WAIVED.</summary>
    public string Status { get; set; } = "OUTSTANDING";

    public int DaysLate { get; set; }
    /// <summary>The penalty settings as they stood, and how the figure was reached.</summary>
    public System.Text.Json.JsonDocument? Snapshot { get; set; }
    public string? Reason { get; set; }

    public DateTimeOffset? WaivedAt { get; set; }
    public string? WaivedBy { get; set; }
    public string? WaiverReason { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}
