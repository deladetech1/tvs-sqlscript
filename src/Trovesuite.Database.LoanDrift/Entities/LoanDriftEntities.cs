using System.Text.Json;
using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.LoanDrift.Entities;

public class Client : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string Fullname { get; set; } = default!;
    public string? Email { get; set; }
    public string Contact { get; set; } = default!;
    public string? ResidentialAddress { get; set; }

    public DateTimeOffset? RegistrationDatetime { get; set; }

    public string? Dob { get; set; }
    public string? MaritalStatus { get; set; }
    public string? Occupation { get; set; }
    public string? Gender { get; set; }
    public string? IdType { get; set; }
    public string? IdNumber { get; set; }
    public string? IdIssueDate { get; set; }
    public string? IdExpiryDate { get; set; }
}

public class LoanDriftActivityLog
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? Action { get; set; }
    public string? ResourceType { get; set; }
    public JsonDocument? OldData { get; set; }
    public JsonDocument? NewData { get; set; }
    public string? Description { get; set; }
    public string? PerformedByEmail { get; set; }
    public string? PerformedByContact { get; set; }
    public string? PerformedByFullname { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class ClientBusiness : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string BusName { get; set; } = default!;
    public string Address { get; set; } = default!;
    public string? GoogleMapLocationCapture { get; set; }
}

public class Sector : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string SectorName { get; set; } = default!;
    public bool IsSystem { get; set; } = true;
}

public class LoanType : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string TypeName { get; set; } = default!;
    public bool IsSystem { get; set; } = true;
}

public class InterestType : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string? OrgId { get; set; }
    public string? BusId { get; set; }
    public string InterestTypeName { get; set; } = default!;
    public bool IsSystem { get; set; } = true;
}

public class LoanDetail : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? LoanTypeId { get; set; }
    public string? SectorId { get; set; }
    public string? InterestTypeId { get; set; }
    public string? PaymentType { get; set; }
    public int GracePeriod { get; set; }
    public string? RegistrationId { get; set; }

    public string Status { get; set; } = "REGISTERED";
    public bool IsReadyForApproval { get; set; }

    public decimal? RequestedAmount { get; set; }
    public string? CurrencyId { get; set; }

    public DateTimeOffset? RegistrationDatetime { get; set; }
}

public class LoanCalculation
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public decimal InterestRate { get; set; }
    public string? LoanPeriods { get; set; }
    public string? InterestPeriod { get; set; }
    public int? RepaymentWeeks { get; set; }
    public string? FirstPaymentDate { get; set; }
    public decimal ExpectedInterestRate { get; set; }
    public decimal LoanAmount { get; set; }
    public decimal LoanRepaymentAmount { get; set; }
    public string? CurrencyId { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class LoanCharge
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public decimal ProcessingFees { get; set; }
    public decimal ProcessingFeesPercentage { get; set; }
    public decimal Insurance { get; set; }
    public decimal InsurancePercentage { get; set; }
    public decimal OtherCharges { get; set; }
    public decimal OtherChargesPercentage { get; set; }
    public string? BankChequeReference { get; set; }
    public string? CurrencyId { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class LoanPurpose
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? LoanPurposeValue { get; set; }
    public int? NumberOfMonths { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ClientFinancialInfo
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? CurrentlyWorkingWith { get; set; }
    public string? SavingBankWith { get; set; }
    public decimal SavingAmount { get; set; }

    public string? ProvidentFundWith { get; set; }
    public decimal ProvidentFundAmount { get; set; }

    public string? LifeInsuranceProvider { get; set; }
    public decimal LifeInsuranceAmount { get; set; }

    public string? SalaryInBankWith { get; set; }
    public string? SalaryAccountNumber { get; set; }
    public decimal SalaryAmount { get; set; }

    public string? AssetName { get; set; }
    public decimal AssetValue { get; set; }
    public string? PropertyName { get; set; }
    public decimal PropertyValue { get; set; }

    public decimal BorrowerMonthlySalary { get; set; }
    public decimal BorrowerOtherIncome { get; set; }
    public decimal BorrowerMonthlyExpenses { get; set; }

    public decimal PreviousLoanAmount { get; set; }
    public decimal PreviousLoanAmount2 { get; set; }
    public string? PurposeInstallmentPayment { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal PrincipalLoanAmount { get; set; }
    public string? CurrencyId { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class LoanApproval
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? ApprovedBy { get; set; }
    public decimal? ApprovedAmount { get; set; }
    public string? ApprovalDate { get; set; }
    public string? ApprovalTime { get; set; }
    public string? ApprovedMessage { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class LoanDisbursement
{
    public string LoanId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? Mode { get; set; }
    public string? Reference { get; set; }
    public string? DisbursedBy { get; set; }
    public string? DisbursementDate { get; set; }
    public string? DisbursementTime { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class LoanMessage : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? Message { get; set; }
    public string Status { get; set; } = "REGISTERED";
}

public class ClientComment : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? Comment { get; set; }
    public bool HasTakenLoanBefore { get; set; }
    public string? LoanProcessedBy { get; set; }
}

public class Guarantor : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string LoanId { get; set; } = default!;

    public string? Title { get; set; }
    public string? Fullname { get; set; }
    public string? Contact { get; set; }
    public string? Dob { get; set; }
    public string? Gender { get; set; }
    public string? Address { get; set; }

    public string? MaritalStatus { get; set; }
    public string? RelationshipToBorrower { get; set; }
    public string? Occupation { get; set; }
    public string? ResidentialAddress { get; set; }
    public string? Religion { get; set; }

    public string? BusinessAddress { get; set; }
    public string? DigitalAddress { get; set; }
    public string? GoogleMapLocationCapture { get; set; }
    public JsonDocument? CollateralDetails { get; set; }

    public string? IdType { get; set; }
    public string? IdNumber { get; set; }
    public string? ReligionExtraInfo { get; set; }
    public string? IdIssueDate { get; set; }
    public string? IdExpiryDate { get; set; }
}

public class LoanDriftResourceDeletionChatHistory
{
    public string Id { get; set; } = default!;
    public string? ResourceId { get; set; }
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    public string? Message { get; set; }
    public string? SentBy { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class Repayment
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string ClientId { get; set; } = default!;

    public string? PaymentMethod { get; set; }
    public string? NextPaymentDate { get; set; }
    public bool IsCompleted { get; set; }

    public decimal AmountGiven { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal Balance { get; set; }

    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Description { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class ClientDocumentPath : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string LoanId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string DocumentPathValue { get; set; } = default!;
    public string DocumentName { get; set; } = default!;
}
