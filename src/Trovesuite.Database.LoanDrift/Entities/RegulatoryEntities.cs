using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

/// <summary>
/// The lending institution itself, as the Bank of Ghana knows it.
///
/// The credit bureau return identifies the lender and the branch that booked
/// each facility, and neither of those is derivable from the loan book: the
/// BOG institution code and the branch codes are assigned by the regulator and
/// have to be keyed in once. Everything a submission needs about "who is
/// filing" lives here, so a return can be built without asking an accountant
/// to retype the licence number every month.
///
/// One row per (tenant, org, bus) — an institution is a business; its branches
/// are <see cref="BranchProfile"/> rows, one per location.
/// </summary>
public class CompanyProfile : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;

    public string LegalName { get; set; } = default!;
    public string? TradingName { get; set; }

    /// <summary>BOG's category for the institution — decides which return applies.</summary>
    public string? InstitutionType { get; set; }
    /// <summary>The code the Bank of Ghana and the bureaus identify this lender by.
    /// Prefixes every facility number in a submission.</summary>
    public string? BogInstitutionCode { get; set; }
    public string? BogLicenceNumber { get; set; }
    public string? RegistrationNumber { get; set; }
    public string? Tin { get; set; }
    public string? IncorporationDate { get; set; }

    public string? AddressLine1 { get; set; }
    public string? AddressLine2 { get; set; }
    public string? AddressLine3 { get; set; }
    public string? AddressLine4 { get; set; }
    public string? PostalCode { get; set; }
    public string? DigitalAddress { get; set; }
    public string? City { get; set; }
    public string? Region { get; set; }
    /// <summary>ISO 3166-1 alpha-2. Ghana unless the institution says otherwise.</summary>
    public string Country { get; set; } = "GH";

    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Website { get; set; }

    /// <summary>ISO 4217 code the return is denominated in. The bureaus want the
    /// code, not the symbol.</summary>
    public string ReportingCurrency { get; set; } = "GHS";

    /// <summary>Who the regulator contacts about a submission.</summary>
    public string? ContactPersonName { get; set; }
    public string? ContactPersonPhone { get; set; }
    public string? ContactPersonEmail { get; set; }
}

/// <summary>
/// A branch, as it appears in a regulatory return: the location plus the code
/// the Bank of Ghana knows it by.
///
/// Loandrift already has branches — they are core-platform Locations — but a
/// Location carries no branch code, and adding one there would put a lending
/// field on every app in the suite. This table is the lending-side extension:
/// one row per location that the institution reports under.
/// </summary>
public class BranchProfile : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    /// <summary>The institution's own branch code — the segment that goes into a
    /// facility number. Unique within the business.</summary>
    public string BranchCode { get; set; } = default!;
    /// <summary>Set only when the Bank of Ghana assigns a different code to the
    /// branch than the institution uses internally.</summary>
    public string? BogBranchCode { get; set; }
    public string? BranchName { get; set; }
    public bool IsHeadOffice { get; set; }

    public string? AddressLine1 { get; set; }
    public string? AddressLine2 { get; set; }
    public string? AddressLine3 { get; set; }
    public string? AddressLine4 { get; set; }
    public string? PostalCode { get; set; }
    public string? DigitalAddress { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
}

/// <summary>
/// One identification document belonging to a client.
///
/// The credit bureau return asks for every ID type as its own column — national
/// ID, voter's, driver's licence, passport, SSNIT, e-zwich, TIN — all reported
/// together for the same person. A single id_type/id_number pair on the client
/// can only answer one of those columns, so the ones the client also holds are
/// lost. A row per document lets a client hold all of them at once.
///
/// The client's own <c>id_type</c>/<c>id_number</c> stay where they are: they
/// are the document the officer sighted at registration, and the rest of the
/// app reads them. The primary row here mirrors that pair.
/// </summary>
public class ClientIdentification : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string IdType { get; set; } = default!;
    public string IdNumber { get; set; } = default!;
    /// <summary>What the document is, when <see cref="IdType"/> is OTHER — the
    /// return reports the label alongside the number.</summary>
    public string? OtherIdLabel { get; set; }
    public string? IssueDate { get; set; }
    public string? ExpiryDate { get; set; }

    /// <summary>The document sighted at registration — mirrors the client's own
    /// id_type/id_number. At most one per client.</summary>
    public bool IsPrimary { get; set; }
}

/// <summary>
/// One identification document belonging to a guarantor. Same reasoning as
/// <see cref="ClientIdentification"/> — the return asks for a guarantor's
/// national ID, voter's, licence and passport as four separate columns.
/// </summary>
public class GuarantorIdentification : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string GuarantorId { get; set; } = default!;

    public string IdType { get; set; } = default!;
    public string IdNumber { get; set; } = default!;
    public string? OtherIdLabel { get; set; }
    public string? IssueDate { get; set; }
    public string? ExpiryDate { get; set; }

    public bool IsPrimary { get; set; }
}
