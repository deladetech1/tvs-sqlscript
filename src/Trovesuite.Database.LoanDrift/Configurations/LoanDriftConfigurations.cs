using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift.Configurations;

internal static class LoanDriftDefaults
{
    public static EntityTypeBuilder<T> ApplyAuditDefaults<T>(this EntityTypeBuilder<T> b) where T : class
    {
        if (b.Metadata.FindProperty("Cdatetime") is not null)
            b.Property("Cdatetime").HasColumnType("timestamptz");
        if (b.Metadata.FindProperty("DeleteStatus") is not null)
            b.Property("DeleteStatus").HasDefaultValue("NOT_DELETED");
        if (b.Metadata.FindProperty("IsActive") is not null)
            b.Property("IsActive").HasDefaultValue(true);
        return b;
    }

    /// <summary>
    /// Composite FK (TenantId, OrgId, BusId, LocId, LoanId) → ld_loan_details(TenantId, OrgId, BusId, LocId, Id).
    /// Used by every "loan-scoped" child table (calculations, charges, purpose, financial info, approvals,
    /// disbursements, messages, comments, guarantors, repayments, document paths).
    /// </summary>
    public static EntityTypeBuilder<T> WithLoanDetailFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<LoanDetail>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "LoanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>Composite FK to ld_clients (5-column).</summary>
    public static EntityTypeBuilder<T> WithClientFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Client>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "ClientId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(CurrencyId, TenantId) → core_platform.cp_currencies(Id, TenantId).</summary>
    public static EntityTypeBuilder<T> WithCurrencyFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.SetNull) where T : class
    {
        if (b.Metadata.FindProperty("CurrencyId") is null) return b;
        b.HasOne<Currency>().WithMany()
            .HasForeignKey("CurrencyId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(onDelete);
        return b;
    }
}

public sealed class ClientConfiguration : IEntityTypeConfiguration<Client>
{
    public void Configure(EntityTypeBuilder<Client> b)
    {
        b.ToTable("ld_clients");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.RegistrationDatetime).HasColumnType("timestamptz");
        b.ApplyAuditDefaults();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Email }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Contact }).IsUnique();
        b.HasInCheck("marital_status", "SINGLE", "MARRIED", "DIVORCED", "WIDOWED", null!);
        b.HasInCheck("gender", "MALE", "FEMALE", "OTHER", null!);
        b.HasInCheck("id_type", "GHANA_CARD", "VOTER_ID", "DRIVERS_LICENSE", "PASSPORT", null!);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ActivityLogConfiguration : IEntityTypeConfiguration<LoanDriftActivityLog>
{
    public void Configure(EntityTypeBuilder<LoanDriftActivityLog> b)
    {
        b.ToTable("ld_activity_logs");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OldData).HasColumnType("jsonb");
        b.Property(x => x.NewData).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceType).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ClientBusinessConfiguration : IEntityTypeConfiguration<ClientBusiness>
{
    public void Configure(EntityTypeBuilder<ClientBusiness> b)
    {
        b.ToTable("ld_client_businesses");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SectorConfiguration : IEntityTypeConfiguration<Sector>
{
    public void Configure(EntityTypeBuilder<Sector> b)
    {
        b.ToTable("ld_sectors");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class LoanTypeConfiguration : IEntityTypeConfiguration<LoanType>
{
    public void Configure(EntityTypeBuilder<LoanType> b)
    {
        b.ToTable("ld_loan_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InterestTypeConfiguration : IEntityTypeConfiguration<InterestType>
{
    public void Configure(EntityTypeBuilder<InterestType> b)
    {
        b.ToTable("ld_interest_types");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsSystem).HasDefaultValue(true);
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class LoanDetailConfiguration : IEntityTypeConfiguration<LoanDetail>
{
    public void Configure(EntityTypeBuilder<LoanDetail> b)
    {
        b.ToTable("ld_loan_details");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.LoanTypeId).HasColumnName("loan_type");
        b.Property(x => x.GracePeriod).HasDefaultValue(0);
        b.Property(x => x.Status).HasDefaultValue("REGISTERED");
        b.Property(x => x.IsReadyForApproval).HasDefaultValue(false);
        b.Property(x => x.RequestedAmount).HasColumnType("numeric(15,2)");
        b.Property(x => x.RegistrationDatetime).HasColumnType("timestamptz");
        b.ApplyAuditDefaults();
        b.HasInCheck("payment_type", "DAILY", "WEEKLY", "BI_WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY", null!);
        b.HasInCheck("status", "REGISTERED", "CAPTURED", "APPROVED", "REJECTED", "DISBURSED",
                              "CLOSED", "DEFAULTED", "WRITTEN_OFF", "ACTIVE", "COMPLETED");
        b.HasOne<Sector>().WithMany().HasForeignKey(x => x.SectorId).OnDelete(DeleteBehavior.SetNull);
        b.HasOne<LoanType>().WithMany().HasForeignKey(x => x.LoanTypeId).OnDelete(DeleteBehavior.SetNull);
        b.HasOne<InterestType>().WithMany().HasForeignKey(x => x.InterestTypeId).OnDelete(DeleteBehavior.SetNull);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class LoanCalculationConfiguration : IEntityTypeConfiguration<LoanCalculation>
{
    public void Configure(EntityTypeBuilder<LoanCalculation> b)
    {
        b.ToTable("ld_loan_calculations");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.InterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.ExpectedInterestRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.LoanAmount).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.LoanRepaymentAmount).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("loan_periods", "DAYS", "WEEKS", "MONTHS", "YEARS", null!);
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class LoanChargeConfiguration : IEntityTypeConfiguration<LoanCharge>
{
    public void Configure(EntityTypeBuilder<LoanCharge> b)
    {
        b.ToTable("ld_loan_charges");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.ProcessingFees).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.ProcessingFeesPercentage).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.Insurance).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.InsurancePercentage).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.OtherCharges).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.OtherChargesPercentage).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class LoanPurposeConfiguration : IEntityTypeConfiguration<LoanPurpose>
{
    public void Configure(EntityTypeBuilder<LoanPurpose> b)
    {
        b.ToTable("ld_loan_purpose");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.LoanPurposeValue).HasColumnName("loan_purpose");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class ClientFinancialInfoConfiguration : IEntityTypeConfiguration<ClientFinancialInfo>
{
    public void Configure(EntityTypeBuilder<ClientFinancialInfo> b)
    {
        b.ToTable("ld_client_financial_info");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.ProvidentFundWith).HasColumnName("provident_fund_with");
        b.Property(x => x.ProvidentFundAmount).HasColumnName("provident_fund_amount");
        b.Property(x => x.AssetName).HasColumnName("asset_name");
        b.Property(x => x.AssetValue).HasColumnName("asset_value");
        b.Property(x => x.PropertyName).HasColumnName("property_name");
        // Snake-case convention drops the underscore before the trailing digit;
        // bkup column is "previous_loan_amount_2". Force the exact name.
        b.Property(x => x.PreviousLoanAmount2).HasColumnName("previous_loan_amount_2");
        foreach (var col in new[]
        {
            "SavingAmount","ProvidentFundAmount","LifeInsuranceAmount","SalaryAmount",
            "AssetValue","PropertyValue","BorrowerMonthlySalary","BorrowerOtherIncome",
            "BorrowerMonthlyExpenses","PreviousLoanAmount","PreviousLoanAmount2",
            "InterestAmount","PrincipalLoanAmount"
        })
            b.Property(col).HasColumnType("numeric(15,2)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCurrencyFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class LoanApprovalConfiguration : IEntityTypeConfiguration<LoanApproval>
{
    public void Configure(EntityTypeBuilder<LoanApproval> b)
    {
        b.ToTable("ld_loan_approvals");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.ApprovedAmount).HasColumnType("numeric(15,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaCreateUpdateUserFks();
        // approved_by → cp_users(id, tenant_id) RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("ApprovedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class LoanDisbursementConfiguration : IEntityTypeConfiguration<LoanDisbursement>
{
    public void Configure(EntityTypeBuilder<LoanDisbursement> b)
    {
        b.ToTable("ld_loan_disbursements");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.LoanId });
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("mode", "CASH", "CHEQUE", "MOMO", "BANK_TRANSFER", "OTHERS", null!);
        b.WithTenantFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaCreateUpdateUserFks();
        b.HasOne<User>().WithMany().HasForeignKey("DisbursedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class LoanMessageConfiguration : IEntityTypeConfiguration<LoanMessage>
{
    public void Configure(EntityTypeBuilder<LoanMessage> b)
    {
        b.ToTable("ld_loan_messages");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("REGISTERED");
        b.ApplyAuditDefaults();
        b.HasInCheck("status", "REGISTERED", "CAPTURED", "APPROVED", "REJECTED", "DISBURSED",
                              "DEFAULTED", "WRITTEN_OFF", "ACTIVE", "COMPLETED");
        b.WithTenantOrgBusLocFks();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ClientCommentConfiguration : IEntityTypeConfiguration<ClientComment>
{
    public void Configure(EntityTypeBuilder<ClientComment> b)
    {
        b.ToTable("ld_clients_comments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.HasTakenLoanBefore).HasDefaultValue(false);
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class GuarantorConfiguration : IEntityTypeConfiguration<Guarantor>
{
    public void Configure(EntityTypeBuilder<Guarantor> b)
    {
        b.ToTable("ld_guarantors");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.CollateralDetails).HasColumnType("jsonb");
        b.ApplyAuditDefaults();
        b.HasInCheck("title", "MR", "MRS", "MISS", "MS", "DR", "MADAM", null!);
        b.HasInCheck("gender", "MALE", "FEMALE", "OTHER", null!);
        b.HasInCheck("marital_status", "SINGLE", "MARRIED", "DIVORCED", "WIDOWED", null!);
        b.HasInCheck("relationship_to_borrower", "FAMILY", "FRIEND", "COLLEAGUE", "OTHER", null!);
        b.HasInCheck("id_type", "GHANA_CARD", "VOTER_ID", "DRIVERS_LICENSE", "PASSPORT", null!);
        b.HasDeleteStatusCheck();
        // bkup: org/bus/loc FKs are CASCADE (not RESTRICT) for guarantors
        b.WithTenantFk();
        b.WithCompositeFk<Guarantor, Organization>("OrgId", DeleteBehavior.Cascade);
        b.WithCompositeFk<Guarantor, Business>("BusId", DeleteBehavior.Cascade);
        b.WithCompositeFk<Guarantor, Location>("LocId", DeleteBehavior.Cascade);
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class LoanDriftResourceDeletionChatHistoryConfiguration
    : IEntityTypeConfiguration<LoanDriftResourceDeletionChatHistory>
{
    public void Configure(EntityTypeBuilder<LoanDriftResourceDeletionChatHistory> b)
    {
        b.ToTable("ld_resource_deletion_chat_histories");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.HasOne<User>().WithMany().HasForeignKey("SentBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class RepaymentConfiguration : IEntityTypeConfiguration<Repayment>
{
    public void Configure(EntityTypeBuilder<Repayment> b)
    {
        b.ToTable("ld_repayments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsCompleted).HasDefaultValue(false);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        foreach (var col in new[] { "AmountGiven", "PaidAmount", "Balance" })
            b.Property(col).HasColumnType("numeric(20,6)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("payment_method", "CASH", "CHEQUE", "MOMO", "BANK_TRANSFER", "OTHERS", null!);
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ClientDocumentPathConfiguration : IEntityTypeConfiguration<ClientDocumentPath>
{
    public void Configure(EntityTypeBuilder<ClientDocumentPath> b)
    {
        b.ToTable("ld_client_documents_paths");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DocumentPathValue).HasColumnName("document_path");
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithClientFk();
        b.WithLoanDetailFk();
        b.WithCrossSchemaAuditUserFks();
    }
}
