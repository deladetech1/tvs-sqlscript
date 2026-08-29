using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift.Configurations;

internal static class RegulatoryDefaults
{
    /// <summary>
    /// Every identification type the Bank of Ghana credit bureau return has a
    /// column for. OTHER carries its label in <c>other_id_label</c>, which is
    /// what the return's OtherID column reports next to the number.
    ///
    /// NHIS has no column of its own and is reported as an OTHER document. It is
    /// listed because the capture API already accepted it for guarantors while
    /// the database check did not, so a guarantor holding one could not be saved.
    /// </summary>
    public static readonly string[] IdTypes =
    {
        "GHANA_CARD", "VOTER_ID", "DRIVERS_LICENSE", "PASSPORT",
        "SSNIT", "EZWICH", "TIN", "NHIS", "OTHER",
    };

    /// <summary>The same list where the column is optional — the id_type a client
    /// or guarantor row carries directly, which may not have been sighted yet.</summary>
    public static readonly string[] IdTypesOrNull =
    {
        "GHANA_CARD", "VOTER_ID", "DRIVERS_LICENSE", "PASSPORT",
        "SSNIT", "EZWICH", "TIN", "NHIS", "OTHER", null!,
    };

    /// <summary>Composite FK (TenantId, OrgId, BusId, LocId, GuarantorId) → ld_guarantors.</summary>
    public static EntityTypeBuilder<T> WithGuarantorFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Guarantor>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "GuarantorId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }
}

public sealed class CompanyProfileConfiguration : IEntityTypeConfiguration<CompanyProfile>
{
    public void Configure(EntityTypeBuilder<CompanyProfile> b)
    {
        b.ToTable("ld_company_profile");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Country).HasDefaultValue("GH");
        b.Property(x => x.ReportingCurrency).HasDefaultValue("GHS");
        b.ApplyAuditDefaults();
        // One institution per business — the return has one filer.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId }).IsUnique();
        b.HasInCheck("institution_type",
            "MICROFINANCE", "SAVINGS_AND_LOANS", "RURAL_BANK", "FINANCE_HOUSE",
            "CREDIT_UNION", "LEASING", "MONEY_LENDER", "OTHER", null!);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class BranchProfileConfiguration : IEntityTypeConfiguration<BranchProfile>
{
    public void Configure(EntityTypeBuilder<BranchProfile> b)
    {
        b.ToTable("ld_branch_profile");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        // One profile per location, and a branch code that identifies exactly one
        // branch within the institution — a submission keyed on a duplicated code
        // cannot be traced back to the branch that booked the facility.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.BranchCode }).IsUnique();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ClientIdentificationConfiguration : IEntityTypeConfiguration<ClientIdentification>
{
    public void Configure(EntityTypeBuilder<ClientIdentification> b)
    {
        b.ToTable("ld_client_identifications");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        // The return has one column per ID type, so a client holding two Ghana
        // Cards has no way to report both — and no reason to.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ClientId, x.IdType })
            .IsUnique();
        // At most one document sighted at registration.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ClientId })
            .IsUnique().HasFilter("is_primary").HasDatabaseName("ux_ld_client_identifications_primary");
        b.HasInCheck("id_type", RegulatoryDefaults.IdTypes);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class GuarantorIdentificationConfiguration : IEntityTypeConfiguration<GuarantorIdentification>
{
    public void Configure(EntityTypeBuilder<GuarantorIdentification> b)
    {
        b.ToTable("ld_guarantor_identifications");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.GuarantorId, x.IdType })
            .IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.GuarantorId })
            .IsUnique().HasFilter("is_primary").HasDatabaseName("ux_ld_guarantor_identifications_primary");
        b.HasInCheck("id_type", RegulatoryDefaults.IdTypes);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithGuarantorFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
