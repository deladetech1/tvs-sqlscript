using System.Text.Json;

namespace Trovesuite.Database.MyStoreGuard.Entities;

public class PricingRule
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string RuleCategory { get; set; } = default!;
    public string RuleType { get; set; } = default!;
    public string RuleTargetType { get; set; } = default!;
    public string? RuleTargetId { get; set; }
    public int? QuantityMin { get; set; }
    public int? QuantityMax { get; set; }
    public decimal? DiscountValue { get; set; }
    public decimal? DiscountPercent { get; set; }
    public int FreeQty { get; set; }
    public bool IsActive { get; set; } = true;
    public bool StopsOtherRules { get; set; }
    public int Priority { get; set; }
    public DateTime? StartDatetime { get; set; }
    public DateTime? EndDatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class ReturnPolicy
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string PolicyTargetType { get; set; } = default!;
    public string? PolicyTargetId { get; set; }
    public int ReturnWindowDays { get; set; }
    public string ConditionRequired { get; set; } = "ANY";
    public bool ReceiptRequired { get; set; } = true;
    public bool AllowExpiredReturns { get; set; }
    public decimal RestockingFeePercent { get; set; }
    public string RefundMethod { get; set; } = "ANY";
    public bool ApprovalRequired { get; set; }
    public JsonDocument? Approvers { get; set; }
    public decimal? ApprovalThresholdAmount { get; set; }
    public bool StopsOtherPolicies { get; set; }
    public int Priority { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? StartDatetime { get; set; }
    public DateTime? EndDatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class OpenAndClosingStock
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public DateTimeOffset PeriodDate { get; set; }
    public string PeriodType { get; set; } = "DAILY";
    public int OpeningStock { get; set; }
    public int ClosingStock { get; set; }
    public int TotalStockIn { get; set; }
    public int TotalStockOut { get; set; }
    public int TotalSalesQuantity { get; set; }
    public decimal TotalSalesValue { get; set; }
    public int TotalPurchaseQuantity { get; set; }
    public decimal TotalPurchaseValue { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class Tax
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public decimal Rate { get; set; }
    public bool IsInclusive { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class TaxRule
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string TaxId { get; set; } = default!;
    public string RuleType { get; set; } = default!;
    public string? RuleTargetId { get; set; }
    public int Priority { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class TaxRuleCondition
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string TaxId { get; set; } = default!;
    public string TaxRuleId { get; set; } = default!;
    public int Priority { get; set; }
    public string ConditionType { get; set; } = default!;
    public string Condition { get; set; } = default!;
    public string ComparisonOperator { get; set; } = default!;
    public decimal ComparisonValue { get; set; }
    public decimal? AdjustmentValue { get; set; }
    public decimal? AdjustmentPercentage { get; set; }
    public string LogicalOperator { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgActivityLog
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    // Nullable: business-scoped resources (e.g. tasks / workflow templates) have no location.
    public string? LocId { get; set; }
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

public class StoreConfig
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? StoreName { get; set; }
    public string? Description { get; set; }
    public bool IsVisibleOnEcommerce { get; set; }
    public string? Address { get; set; }
    public bool IsActive { get; set; } = true;
    public string? ManagerId { get; set; }
    public bool EnableAutoStockTake { get; set; }
    public int NumOfDaysToTakeStock { get; set; }
    public bool EnableDailySalesReports { get; set; }
    public TimeOnly? OpenningTime { get; set; }
    public TimeOnly? ClosingTime { get; set; }
    public bool LockBasedOnClosingTime { get; set; }
    public bool ChangeToCard { get; set; }
    public bool EnableOutOfStockNotification { get; set; }
    public string? OutOfStockNotificationEmail { get; set; }
    public int? OutOfStockNotificationOccurrence { get; set; }
    public string? SalesNotificationEmails { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class WarehouseConfig
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? WarehouseName { get; set; }
    public string? Description { get; set; }
    public string? Aadress { get; set; }
    public bool IsActive { get; set; } = true;
    public string? ManagerId { get; set; }
    public TimeOnly? OpenningTime { get; set; }
    public TimeOnly? ClosingTime { get; set; }
    public bool ChangeToCard { get; set; }
    public bool EnableOutOfStockNotification { get; set; }
    public string? OutOfStockNotificationEmail { get; set; }
    public int? OutOfStockNotificationOccurrence { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class StockTakingAudit
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public DateTimeOffset StartDatetime { get; set; }
    public DateTimeOffset? NextStockTakeDatetime { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class PromoCode
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PromoCodeValue { get; set; } = default!;
    public string CurrencyId { get; set; } = default!;
    public string DiscountType { get; set; } = default!;
    public decimal DiscountValue { get; set; }
    public decimal MinPurchaseAmount { get; set; }
    public decimal? MaxDiscountAmount { get; set; }
    public int? UsageLimitPerCustomer { get; set; }
    public int? TotalUsageLimit { get; set; }
    public int CurrentUsageCount { get; set; }
    public DateOnly? StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public string Status { get; set; } = "ACTIVE";
    public bool IsActive { get; set; } = true;
    public bool ApplicableToCustomersOnly { get; set; }
    public string[] ApplicableToLocations { get; set; } = Array.Empty<string>();
    public string[]? ApplicableToProducts { get; set; }
    public string[]? ApplicableToProductMetadata { get; set; }
    public string? Description { get; set; }
    public string? Notes { get; set; }
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class Affiliate
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string AffiliateCode { get; set; } = default!;
    public string AffiliateName { get; set; } = default!;
    public string? ContactEmail { get; set; }
    public string? ContactPhone { get; set; }
    public decimal CommissionRate { get; set; }
    public string CommissionType { get; set; } = "PERCENTAGE";
    public decimal? FixedCommissionAmount { get; set; }
    public string Status { get; set; } = "ACTIVE";
    public bool IsActive { get; set; } = true;
    public int TotalReferrals { get; set; }
    public int TotalConversions { get; set; }
    public decimal TotalCommissionEarned { get; set; }
    public decimal TotalCommissionPaid { get; set; }
    public string? Description { get; set; }
    public string? Notes { get; set; }
    public string[]? ApplicableToLocations { get; set; }
    public string[]? ApplicableToProducts { get; set; }
    public string[]? ApplicableToProductMetadata { get; set; }
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class Sale
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleNumber { get; set; } = default!;
    public string? CustomerId { get; set; }
    public DateOnly SaleDate { get; set; }
    public string Status { get; set; } = default!;
    public string SaleMode { get; set; } = default!;
    public string FulfillmentStatus { get; set; } = "PENDING";
    public DateTimeOffset? FulfillmentDateTime { get; set; }
    public string? Description { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal BalanceAmount { get; set; }
    public decimal GiftCardAmountUsed { get; set; }
    public string? PromoCodeId { get; set; }
    public decimal PromoDiscountAmount { get; set; }
    public string? AffiliateId { get; set; }
    public JsonDocument? TaxesApplied { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class SaleItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string BatchId { get; set; } = default!;
    public string ProductName { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? Description { get; set; }
    public decimal BaseSellingPrice { get; set; }
    public decimal ActualPrice { get; set; }
    public decimal PriceAfterPricingRule { get; set; }
    public decimal PriceAfterTax { get; set; }
    public decimal FinalPrice { get; set; }
    public decimal Quantity { get; set; }
    public decimal LineTotal { get; set; }
    public decimal TaxRate { get; set; }
    public bool IsInclusive { get; set; }
    public decimal TaxAmount { get; set; }
    public JsonDocument? TaxesApplied { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class GiftCard
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string GiftCardCode { get; set; } = default!;
    public decimal InitialValue { get; set; }
    public decimal CurrentBalance { get; set; }
    public string CurrencyId { get; set; } = default!;
    public string Status { get; set; } = "ACTIVE";
    public DateOnly? ExpiryDate { get; set; }
    public DateOnly? PurchaseDate { get; set; }
    public string? PurchasedByCustomerId { get; set; }
    public string? PurchasedByUserId { get; set; }
    public string? Description { get; set; }
    public string? Notes { get; set; }
    public string[]? ApplicableToLocations { get; set; }
    public bool IsActive { get; set; } = true;
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class SalePayment
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string PaymentMethod { get; set; } = default!;
    public string PaymentStatus { get; set; } = default!;
    public decimal PaidAmount { get; set; }
    public string? GiftCardId { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}

public class Return
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string ReturnNumber { get; set; } = default!;
    public string? ReturnDate { get; set; }
    public string ReturnType { get; set; } = "REFUND";
    public string Status { get; set; } = "PENDING";
    public string Reason { get; set; } = "CUSTOMER_CHANGED_MIND";
    public string? ReasonNotes { get; set; }
    public string RefundMethod { get; set; } = "ORIGINAL_PAYMENT";
    public decimal SubtotalRefundAmount { get; set; }
    public decimal RestockingFeePercent { get; set; }
    public decimal RestockingFeeAmount { get; set; }
    public decimal TotalRefundAmount { get; set; }
    public string? ReturnPolicyId { get; set; }
    public bool ApprovalRequired { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTimeOffset? ApprovedAt { get; set; }
    public string? RejectedBy { get; set; }
    public DateTimeOffset? RejectedAt { get; set; }
    public string? RejectionReason { get; set; }
    public string? ProcessedBy { get; set; }
    public DateTimeOffset? ProcessedAt { get; set; }
    public string? ProcessingNotes { get; set; }
    public string? CustomerId { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ReturnItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ReturnId { get; set; } = default!;
    public string SaleItemId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? BatchId { get; set; }
    public decimal QuantityReturned { get; set; }
    public string Condition { get; set; } = "RESALABLE";
    public bool Restock { get; set; } = true;
    public decimal UnitRefundAmount { get; set; }
    public decimal LineRefundAmount { get; set; }
    public string? Reason { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class Appointment
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string AppointmentType { get; set; } = default!;
    public string Status { get; set; } = default!;
    public bool IsWalkIn { get; set; }
    public string? CustomerId { get; set; }
    public string? AssignedTo { get; set; }
    public DateTimeOffset StartDatetime { get; set; }
    public DateTimeOffset EndDatetime { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class Invoice
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string InvoiceNumber { get; set; } = default!;
    public string CustomerId { get; set; } = default!;
    public DateOnly SaleDate { get; set; }
    public DateOnly? DueDate { get; set; }
    public string Status { get; set; } = default!;
    public string SaleMode { get; set; } = "INSTANT";
    public string? Description { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal BalanceAmount { get; set; }
    public decimal GiftCardAmountUsed { get; set; }
    public string? PromoCodeId { get; set; }
    public decimal PromoDiscountAmount { get; set; }
    public string? AffiliateId { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class InvoiceItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string InvoiceId { get; set; } = default!;
    public string? BatchId { get; set; }
    public string ProductName { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? Description { get; set; }
    public decimal BaseSellingPrice { get; set; }
    public decimal ActualPrice { get; set; }
    public decimal PriceAfterPricingRule { get; set; }
    public decimal PriceAfterTax { get; set; }
    public decimal FinalPrice { get; set; }
    public decimal Quantity { get; set; }
    public decimal LineTotal { get; set; }
    public decimal TaxRate { get; set; }
    public bool IsInclusive { get; set; }
    public decimal TaxAmount { get; set; }
    public JsonDocument? TaxesApplied { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class InvoicePayment
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string InvoiceId { get; set; } = default!;
    public string PaymentMethod { get; set; } = default!;
    public string PaymentStatus { get; set; } = default!;
    public decimal PaidAmount { get; set; }
    public string? GiftCardId { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}

public class InvoiceSale
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string InvoiceId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}

public class Delivery
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string DeliveryNumber { get; set; } = default!;
    public string DeliveryStatus { get; set; } = default!;
    public string DeliveryType { get; set; } = default!;
    public DateOnly? ScheduledDate { get; set; }
    public DateTime? DispatchedAt { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public decimal DeliveryFee { get; set; }
    public string CurrencyId { get; set; } = default!;
    public bool IsPaid { get; set; }
    public string RecipientName { get; set; } = default!;
    public string? RecipientPhone { get; set; }
    public string DeliveryAddress { get; set; } = default!;
    public string? DeliveryNotes { get; set; }
    public string? DriverId { get; set; }
    public string? ThirdPartyName { get; set; }
    public string? TrackingNumber { get; set; }
    public string CreatedBy { get; set; } = default!;
    public string? DeletedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class DeliveryItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string DeliveryId { get; set; } = default!;
    public string SaleItemId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public decimal OrderedQty { get; set; }
    public decimal DeliveredQty { get; set; }
    public string CreatedBy { get; set; } = default!;
    public string? DeletedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class GiftCardTransaction
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string? LocId { get; set; }
    public string GiftCardId { get; set; } = default!;
    public string TransactionType { get; set; } = default!;
    public decimal Amount { get; set; }
    public decimal BalanceBefore { get; set; }
    public decimal BalanceAfter { get; set; }
    public string? SaleId { get; set; }
    public string? PaymentId { get; set; }
    public string? Description { get; set; }
    public string? Notes { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class PromoCodeUsage
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string PromoCodeId { get; set; } = default!;
    public string SaleId { get; set; } = default!;
    public string? CustomerId { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal SaleTotalBeforeDiscount { get; set; }
    public decimal SaleTotalAfterDiscount { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class AffiliateReferral
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string AffiliateId { get; set; } = default!;
    public string? CustomerId { get; set; }
    public string? SaleId { get; set; }
    public DateTimeOffset? ReferralDate { get; set; }
    public DateTimeOffset? ConversionDate { get; set; }
    public string ConversionStatus { get; set; } = "PENDING";
    public decimal? SaleAmount { get; set; }
    public decimal CommissionAmount { get; set; }
    public bool CommissionPaid { get; set; }
    public DateTimeOffset? CommissionPaidDate { get; set; }
    public string? ReferralSource { get; set; }
    public string? Notes { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class AffiliateCommission
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string? LocId { get; set; }
    public string AffiliateId { get; set; } = default!;
    public string? ReferralId { get; set; }
    public string? SaleId { get; set; }
    public decimal CommissionAmount { get; set; }
    public string PaymentStatus { get; set; } = "PENDING";
    public DateTimeOffset? PaidDate { get; set; }
    public string? PaymentMethod { get; set; }
    public string? PaymentReference { get; set; }
    public string? Description { get; set; }
    public string? Notes { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}
