using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class PricingRuleConfiguration : IEntityTypeConfiguration<PricingRule>
{
    public void Configure(EntityTypeBuilder<PricingRule> b)
    {
        b.ToTable("msg_pricing_rule");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");
        b.Property(x => x.DiscountValue).HasColumnType("decimal(10,2)");
        b.Property(x => x.DiscountPercent).HasColumnType("decimal(5,2)");
        b.Property(x => x.FreeQty).HasDefaultValue(0);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.StopsOtherRules).HasDefaultValue(false);
        b.Property(x => x.Priority).HasDefaultValue(0);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("rule_category", "PRICE_ADJUSTMENT", "QUANTITY_BASED");
        b.HasInCheck("rule_type", "FIXED_AMOUNT", "PRICE_DISCOUNT", "PERCENTAGE_DISCOUNT",
                                  "PRICE_MARKUP", "PERCENTAGE_MARKUP", "BUNDLE", "BOGO", "QUANTITY_BREAK");
        b.HasInCheck("rule_target_type", "PRODUCT", "ALL_PRODUCTS", "SKU", "LOCATION", "TAG", "CATEGORY", "BRAND", "LABEL");
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ReturnPolicyConfiguration : IEntityTypeConfiguration<ReturnPolicy>
{
    public void Configure(EntityTypeBuilder<ReturnPolicy> b)
    {
        b.ToTable("msg_return_policies");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");
        b.Property(x => x.ReturnWindowDays).HasDefaultValue(0);
        b.Property(x => x.ConditionRequired).HasDefaultValue("ANY");
        b.Property(x => x.ReceiptRequired).HasDefaultValue(true);
        b.Property(x => x.AllowExpiredReturns).HasDefaultValue(false);
        b.Property(x => x.RestockingFeePercent).HasColumnType("decimal(5,2)").HasDefaultValue(0m);
        b.Property(x => x.RefundMethod).HasDefaultValue("ANY");
        b.Property(x => x.ApprovalRequired).HasDefaultValue(false);
        b.Property(x => x.Approvers).HasColumnType("jsonb");
        b.Property(x => x.ApprovalThresholdAmount).HasColumnType("decimal(10,2)");
        b.Property(x => x.StopsOtherPolicies).HasDefaultValue(false);
        b.Property(x => x.Priority).HasDefaultValue(0);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("policy_target_type", "PRODUCT", "ALL_PRODUCTS", "SKU", "LOCATION", "TAG", "CATEGORY", "BRAND", "LABEL");
        b.HasInCheck("condition_required", "ANY", "UNOPENED", "WITH_TAGS", "UNDAMAGED");
        b.HasInCheck("refund_method", "ORIGINAL_PAYMENT", "STORE_CREDIT", "CASH", "ANY");
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class OpenAndClosingStockConfiguration : IEntityTypeConfiguration<OpenAndClosingStock>
{
    public void Configure(EntityTypeBuilder<OpenAndClosingStock> b)
    {
        b.ToTable("msg_open_and_closing_stock");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PeriodType).HasDefaultValue("DAILY");
        b.Property(x => x.TotalSalesValue).HasColumnType("numeric(10,2)");
        b.Property(x => x.TotalPurchaseValue).HasColumnType("numeric(10,2)");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ProductId, x.PeriodDate }).IsUnique();
        b.HasInCheck("period_type", "DAILY", "MONTHLY");
        b.WithTenantOrgBusLocFks();
        b.WithProductFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class TaxConfiguration : IEntityTypeConfiguration<Tax>
{
    public void Configure(EntityTypeBuilder<Tax> b)
    {
        b.ToTable("msg_taxes");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Rate).HasColumnType("numeric(5,2)");
        b.Property(x => x.IsInclusive).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Name }).IsUnique();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class TaxRuleConfiguration : IEntityTypeConfiguration<TaxRule>
{
    public void Configure(EntityTypeBuilder<TaxRule> b)
    {
        b.ToTable("msg_tax_rule");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Priority).HasDefaultValue(0);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.HasInCheck("rule_type", "PRODUCT", "ALL_PRODUCTS", "CATEGORY", "TAG", "BRAND", "LABEL", "LOCATION", "SKU");
        b.WithTenantOrgBusFks();
        b.HasOne<Tax>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaxId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class TaxRuleConditionConfiguration : IEntityTypeConfiguration<TaxRuleCondition>
{
    public void Configure(EntityTypeBuilder<TaxRuleCondition> b)
    {
        b.ToTable("tax_rule_conditions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Priority).HasDefaultValue(0);
        b.Property(x => x.ComparisonValue).HasColumnType("numeric(10,2)");
        b.Property(x => x.AdjustmentValue).HasColumnType("numeric(10,2)");
        b.Property(x => x.AdjustmentPercentage).HasColumnType("numeric(5,2)");
        b.HasInCheck("condition_type", "TAX_EXEMPTION", "TAX_REDUCTION");
        b.HasInCheck("condition", "IF_ITEM_PRICE", "IF_TOTAL_PRICE", "IF_ITEM_QTY");
        b.HasInCheck("comparison_operator", "EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN",
                                            "GREATER_THAN_OR_EQUALS", "LESS_THAN_OR_EQUALS");
        b.HasInCheck("logical_operator", "AND", "OR");
        b.WithTenantOrgBusFks();
        b.HasOne<Tax>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaxId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<TaxRule>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaxRuleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgActivityLogConfiguration : IEntityTypeConfiguration<MsgActivityLog>
{
    public void Configure(EntityTypeBuilder<MsgActivityLog> b)
    {
        b.ToTable("msg_activity_logs");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OldData).HasColumnType("jsonb");
        b.Property(x => x.NewData).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.HasOne<ResourceType>().WithMany().HasForeignKey(x => x.ResourceType).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class StoreConfigConfiguration : IEntityTypeConfiguration<StoreConfig>
{
    public void Configure(EntityTypeBuilder<StoreConfig> b)
    {
        b.ToTable("msg_store_configs");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsVisibleOnEcommerce).HasDefaultValue(false);
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.EnableAutoStockTake).HasDefaultValue(false);
        b.Property(x => x.NumOfDaysToTakeStock).HasDefaultValue(0);
        b.Property(x => x.EnableDailySalesReports).HasDefaultValue(false);
        b.Property(x => x.LockBasedOnClosingTime).HasDefaultValue(false);
        b.Property(x => x.ChangeToCard).HasDefaultValue(false);
        b.Property(x => x.EnableOutOfStockNotification).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
        // (tenant_id, manager_id) → cp_users(id, tenant_id) SET NULL
        b.HasOne<User>().WithMany().HasForeignKey("ManagerId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.SetNull);
    }
}

public sealed class WarehouseConfigConfiguration : IEntityTypeConfiguration<WarehouseConfig>
{
    public void Configure(EntityTypeBuilder<WarehouseConfig> b)
    {
        b.ToTable("msg_warehouse_configs");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.ChangeToCard).HasDefaultValue(false);
        b.Property(x => x.EnableOutOfStockNotification).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
        b.HasOne<User>().WithMany().HasForeignKey("ManagerId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.SetNull);
    }
}

public sealed class StockTakingAuditConfiguration : IEntityTypeConfiguration<StockTakingAudit>
{
    public void Configure(EntityTypeBuilder<StockTakingAudit> b)
    {
        b.ToTable("msg_stock_taking_audit");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantOrgBusLocFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class PromoCodeConfiguration : IEntityTypeConfiguration<PromoCode>
{
    public void Configure(EntityTypeBuilder<PromoCode> b)
    {
        b.ToTable("msg_promo_codes");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PromoCodeValue).HasColumnName("promo_code");
        b.Property(x => x.DiscountValue).HasColumnType("numeric(18,2)");
        b.Property(x => x.MinPurchaseAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.MaxDiscountAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.CurrentUsageCount).HasDefaultValue(0);
        b.Property(x => x.StartDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.Status).HasDefaultValue("ACTIVE");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.ApplicableToCustomersOnly).HasDefaultValue(false);
        b.Property(x => x.ApplicableToLocations).HasColumnType("text[]");
        b.Property(x => x.ApplicableToProducts).HasColumnType("text[]");
        b.Property(x => x.ApplicableToProductMetadata).HasColumnType("text[]");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PromoCodeValue }).IsUnique();
        b.HasInCheck("discount_type", "PERCENTAGE", "FIXED_AMOUNT", "FREE_SHIPPING");
        b.HasInCheck("status", "ACTIVE", "INACTIVE", "EXPIRED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCurrencyFk("CurrencyId");
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class AffiliateConfiguration : IEntityTypeConfiguration<Affiliate>
{
    public void Configure(EntityTypeBuilder<Affiliate> b)
    {
        b.ToTable("msg_affiliates");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.CommissionRate).HasColumnType("numeric(5,2)").HasDefaultValue(0m);
        b.Property(x => x.CommissionType).HasDefaultValue("PERCENTAGE");
        b.Property(x => x.FixedCommissionAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.Status).HasDefaultValue("ACTIVE");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.TotalReferrals).HasDefaultValue(0);
        b.Property(x => x.TotalConversions).HasDefaultValue(0);
        b.Property(x => x.TotalCommissionEarned).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.TotalCommissionPaid).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.ApplicableToLocations).HasColumnType("text[]");
        b.Property(x => x.ApplicableToProducts).HasColumnType("text[]");
        b.Property(x => x.ApplicableToProductMetadata).HasColumnType("text[]");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.AffiliateCode }).IsUnique();
        b.HasInCheck("commission_type", "PERCENTAGE", "FIXED_AMOUNT");
        b.HasInCheck("status", "ACTIVE", "INACTIVE", "SUSPENDED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SaleConfiguration : IEntityTypeConfiguration<Sale>
{
    public void Configure(EntityTypeBuilder<Sale> b)
    {
        b.ToTable("msg_sales");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.SaleDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.FulfillmentStatus).HasDefaultValue("PENDING");
        b.Property(x => x.FulfillmentDateTime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.Property(x => x.TotalAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.PaidAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.BalanceAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.GiftCardAmountUsed).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.PromoDiscountAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.TaxesApplied).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.SaleNumber }).IsUnique();
        b.HasInCheck("status", "ON_HOLD", "PAID", "PARTIALLY_PAID", "OVERDUE", "CANCELLED", "QUEUED");
        b.HasInCheck("sale_mode", "INSTANT", "DEPOSIT", "CREDIT");
        b.HasInCheck("fulfillment_status", "PENDING", "PARTIALLY_FULFILLED", "FULFILLED");
        b.WithTenantOrgBusLocFks();
        b.WithCustomerFk(DeleteBehavior.Restrict);
        b.WithPromoCodeFk();
        b.WithAffiliateFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SaleItemConfiguration : IEntityTypeConfiguration<SaleItem>
{
    public void Configure(EntityTypeBuilder<SaleItem> b)
    {
        b.ToTable("msg_sales_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        foreach (var col in new[]
        {
            "BaseSellingPrice","ActualPrice","PriceAfterPricingRule","PriceAfterTax",
            "FinalPrice","Quantity","LineTotal","TaxRate","TaxAmount"
        })
            b.Property(col).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.IsInclusive).HasDefaultValue(false);
        b.Property(x => x.TaxesApplied).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.WithTenantFk();
        b.WithSaleFk();
        // batch_id → msg_purchase_batches (RESTRICT)
        b.HasOne<PurchaseBatch>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "BatchId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.WithProductFk(DeleteBehavior.Restrict);
    }
}

public sealed class GiftCardConfiguration : IEntityTypeConfiguration<GiftCard>
{
    public void Configure(EntityTypeBuilder<GiftCard> b)
    {
        b.ToTable("msg_gift_cards");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.InitialValue).HasColumnType("numeric(18,2)");
        b.Property(x => x.CurrentBalance).HasColumnType("numeric(18,2)");
        b.Property(x => x.Status).HasDefaultValue("ACTIVE");
        b.Property(x => x.PurchaseDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.ApplicableToLocations).HasColumnType("text[]");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.GiftCardCode }).IsUnique();
        b.HasInCheck("status", "ACTIVE", "USED", "EXPIRED", "CANCELLED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        // purchased_by_customer_id → msg_customers SET NULL
        b.HasOne<Customer>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PurchasedByCustomerId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        b.WithCurrencyFk("CurrencyId");
        b.WithCrossSchemaAuditUserFks();
        // (tenant_id, purchased_by_user_id) → cp_users SET NULL
        b.HasOne<User>().WithMany().HasForeignKey("PurchasedByUserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.SetNull);
    }
}

public sealed class SalePaymentConfiguration : IEntityTypeConfiguration<SalePayment>
{
    public void Configure(EntityTypeBuilder<SalePayment> b)
    {
        b.ToTable("msg_sales_payments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PaidAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("payment_method", "CASH", "CARD", "BANK_TRANSFER", "MOBILE_MONEY", "CHEQUE", "BITCOIN", "GIFT_CARD", "OTHERS");
        b.HasInCheck("payment_status", "SUCCESS", "FAILED", "PENDING", "REFUNDED");
        b.WithTenantFk();
        b.WithSaleFk();
        b.WithGiftCardFk();
    }
}

public sealed class ReturnConfiguration : IEntityTypeConfiguration<Return>
{
    public void Configure(EntityTypeBuilder<Return> b)
    {
        b.ToTable("msg_returns");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.ReturnType).HasDefaultValue("REFUND");
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.Reason).HasDefaultValue("CUSTOMER_CHANGED_MIND");
        b.Property(x => x.RefundMethod).HasDefaultValue("ORIGINAL_PAYMENT");
        b.Property(x => x.SubtotalRefundAmount).HasColumnType("decimal(10,2)").HasDefaultValue(0m);
        b.Property(x => x.RestockingFeePercent).HasColumnType("decimal(5,2)").HasDefaultValue(0m);
        b.Property(x => x.RestockingFeeAmount).HasColumnType("decimal(10,2)").HasDefaultValue(0m);
        b.Property(x => x.TotalRefundAmount).HasColumnType("decimal(10,2)").HasDefaultValue(0m);
        b.Property(x => x.ApprovalRequired).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("return_type", "REFUND", "EXCHANGE", "STORE_CREDIT");
        b.HasInCheck("status", "PENDING", "APPROVED", "REJECTED", "COMPLETED");
        b.HasInCheck("reason", "DEFECTIVE", "WRONG_ITEM", "CUSTOMER_CHANGED_MIND", "EXPIRED", "DAMAGED_IN_TRANSIT", "OTHER");
        b.HasInCheck("refund_method", "ORIGINAL_PAYMENT", "STORE_CREDIT", "CASH", "ANY");
        b.WithTenantOrgBusFks();
        b.WithSaleFk(DeleteBehavior.Restrict);
        b.WithCrossSchemaCreateUpdateUserFks();
        // approved_by / rejected_by / processed_by → cp_users RESTRICT
        foreach (var c in new[] { "ApprovedBy", "RejectedBy", "ProcessedBy" })
        {
            b.HasOne<User>().WithMany().HasForeignKey(c, "TenantId")
                .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}

public sealed class ReturnItemConfiguration : IEntityTypeConfiguration<ReturnItem>
{
    public void Configure(EntityTypeBuilder<ReturnItem> b)
    {
        b.ToTable("msg_return_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.QuantityReturned).HasColumnType("numeric(18,2)");
        b.Property(x => x.Condition).HasDefaultValue("RESALABLE");
        b.Property(x => x.Restock).HasDefaultValue(true);
        b.Property(x => x.UnitRefundAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.LineRefundAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("condition", "RESALABLE", "DAMAGED", "EXPIRED", "OPENED", "WRITE_OFF");
        b.WithTenantFk();
        b.WithReturnFk();
        // sale_item_id → msg_sales_items RESTRICT
        b.HasOne<SaleItem>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleItemId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.WithProductFk(DeleteBehavior.Restrict);
        // created_by → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class AppointmentConfiguration : IEntityTypeConfiguration<Appointment>
{
    public void Configure(EntityTypeBuilder<Appointment> b)
    {
        b.ToTable("msg_appointments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsWalkIn).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("appointment_type", "SALES", "SERVICE", "DELIVERY", "INSTALLATION", "CONSULTATION", "OTHERS");
        b.HasInCheck("status", "PENDING", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "NO_SHOW", "CANCELLED", "RESCHEDULED");
        b.WithTenantOrgBusLocFks();
        // assigned_to → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("AssignedTo", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InvoiceConfiguration : IEntityTypeConfiguration<Invoice>
{
    public void Configure(EntityTypeBuilder<Invoice> b)
    {
        b.ToTable("msg_invoices");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.SaleDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.SaleMode).HasDefaultValue("INSTANT");
        foreach (var col in new[] { "TotalAmount", "PaidAmount", "BalanceAmount", "GiftCardAmountUsed", "PromoDiscountAmount" })
            b.Property(col).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.InvoiceNumber }).IsUnique();
        b.HasInCheck("status", "DRAFT", "COMPLETED", "PARTIALLY_PAID", "OVERDUE", "CANCELLED");
        b.HasInCheck("sale_mode", "INSTANT", "DEPOSIT", "CREDIT");
        b.WithTenantOrgBusLocFks();
        b.WithCustomerFk(DeleteBehavior.Restrict);
        b.WithPromoCodeFk();
        b.WithAffiliateFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class InvoiceItemConfiguration : IEntityTypeConfiguration<InvoiceItem>
{
    public void Configure(EntityTypeBuilder<InvoiceItem> b)
    {
        b.ToTable("msg_invoice_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        foreach (var col in new[]
        {
            "BaseSellingPrice","ActualPrice","PriceAfterPricingRule","PriceAfterTax",
            "FinalPrice","Quantity","LineTotal","TaxRate","TaxAmount"
        })
            b.Property(col).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.IsInclusive).HasDefaultValue(false);
        b.Property(x => x.TaxesApplied).HasColumnType("jsonb");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.WithTenantFk();
        b.WithInvoiceFk();
        b.HasOne<PurchaseBatch>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "BatchId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.WithProductFk(DeleteBehavior.Restrict);
    }
}

public sealed class InvoicePaymentConfiguration : IEntityTypeConfiguration<InvoicePayment>
{
    public void Configure(EntityTypeBuilder<InvoicePayment> b)
    {
        b.ToTable("msg_invoice_payments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.PaidAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("payment_method", "CASH", "CARD", "BANK_TRANSFER", "MOBILE_MONEY", "CHEQUE", "BITCOIN", "GIFT_CARD", "OTHERS");
        b.HasInCheck("payment_status", "SUCCESS", "FAILED", "PENDING", "REFUNDED");
        b.WithTenantFk();
        b.WithInvoiceFk();
        b.WithGiftCardFk();
    }
}

public sealed class InvoiceSaleConfiguration : IEntityTypeConfiguration<InvoiceSale>
{
    public void Configure(EntityTypeBuilder<InvoiceSale> b)
    {
        b.ToTable("msg_invoice_sales");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.InvoiceId, x.SaleId }).IsUnique();
        b.WithTenantFk();
        b.WithInvoiceFk();
        b.WithSaleFk();
    }
}

public sealed class DeliveryConfiguration : IEntityTypeConfiguration<Delivery>
{
    public void Configure(EntityTypeBuilder<Delivery> b)
    {
        b.ToTable("msg_deliveries");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeliveryFee).HasColumnType("numeric(12,2)").HasDefaultValue(0m);
        b.Property(x => x.IsPaid).HasDefaultValue(false);
        b.Property(x => x.DispatchedAt).HasColumnType("timestamp");
        b.Property(x => x.DeliveredAt).HasColumnType("timestamp");
        b.Property(x => x.Cdate).HasDefaultValueSql("CURRENT_DATE::TEXT");
        b.Property(x => x.Ctime).HasDefaultValueSql("CURRENT_TIME::TEXT");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.DeliveryNumber }).IsUnique();
        b.HasInCheck("delivery_status", "PENDING", "SCHEDULED", "OUT_FOR_DELIVERY", "DELIVERED", "FAILED", "CANCELLED");
        b.HasInCheck("delivery_type", "INTERNAL", "THIRD_PARTY", "CUSTOMER_PICKUP");
        b.ToTable(t => t.HasCheckConstraint("ck_msg_deliveries_type_consistency",
            "(delivery_type = 'INTERNAL' AND driver_id IS NOT NULL) OR " +
            "(delivery_type = 'THIRD_PARTY' AND third_party_name IS NOT NULL) OR " +
            "(delivery_type = 'CUSTOMER_PICKUP')"));
        b.WithTenantOrgBusLocFks();
        b.WithSaleFk(DeleteBehavior.Restrict);
        // driver_id → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("DriverId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
        b.WithCurrencyFk("CurrencyId");
    }
}

public sealed class DeliveryItemConfiguration : IEntityTypeConfiguration<DeliveryItem>
{
    public void Configure(EntityTypeBuilder<DeliveryItem> b)
    {
        b.ToTable("msg_delivery_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OrderedQty).HasColumnType("numeric(12,3)");
        b.Property(x => x.DeliveredQty).HasColumnType("numeric(12,3)");
        b.Property(x => x.Cdate).HasDefaultValueSql("CURRENT_DATE::TEXT");
        b.Property(x => x.Ctime).HasDefaultValueSql("CURRENT_TIME::TEXT");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.WithTenantOrgBusLocFks();
        b.HasOne<Delivery>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "DeliveryId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithProductFk(DeleteBehavior.Restrict);
        // sale_item_id → msg_sales_items RESTRICT
        b.HasOne<SaleItem>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleItemId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class GiftCardTransactionConfiguration : IEntityTypeConfiguration<GiftCardTransaction>
{
    public void Configure(EntityTypeBuilder<GiftCardTransaction> b)
    {
        b.ToTable("msg_gift_card_transactions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Amount).HasColumnType("numeric(18,2)");
        b.Property(x => x.BalanceBefore).HasColumnType("numeric(18,2)");
        b.Property(x => x.BalanceAfter).HasColumnType("numeric(18,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("transaction_type", "PURCHASE", "REDEMPTION", "REFUND", "ADJUSTMENT", "EXPIRY");
        b.WithTenantOrgBusFks();
        // gift_card_id → msg_gift_cards CASCADE
        b.HasOne<GiftCard>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "GiftCardId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // (tenant_id, org_id, bus_id, loc_id, sale_id) → msg_sales SET NULL
        b.HasOne<Sale>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        // (tenant_id, loc_id) → cp_locations SET NULL
        b.HasOne<Location>().WithMany().HasForeignKey("LocId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.SetNull);
        // created_by → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class PromoCodeUsageConfiguration : IEntityTypeConfiguration<PromoCodeUsage>
{
    public void Configure(EntityTypeBuilder<PromoCodeUsage> b)
    {
        b.ToTable("msg_promo_code_usage");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DiscountAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.SaleTotalBeforeDiscount).HasColumnType("numeric(18,2)");
        b.Property(x => x.SaleTotalAfterDiscount).HasColumnType("numeric(18,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.WithTenantOrgBusLocFks();
        b.WithPromoCodeFk(DeleteBehavior.Restrict);
        b.WithSaleFk();
        b.WithCustomerFk();
        // created_by → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class AffiliateReferralConfiguration : IEntityTypeConfiguration<AffiliateReferral>
{
    public void Configure(EntityTypeBuilder<AffiliateReferral> b)
    {
        b.ToTable("msg_affiliate_referrals");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.ReferralDate).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.Property(x => x.ConversionStatus).HasDefaultValue("PENDING");
        b.Property(x => x.SaleAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.CommissionAmount).HasColumnType("numeric(18,2)").HasDefaultValue(0m);
        b.Property(x => x.CommissionPaid).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("conversion_status", "PENDING", "CONVERTED", "FAILED", "CANCELLED");
        b.WithTenantOrgBusLocFks();
        b.WithAffiliateFk(DeleteBehavior.Restrict);
        b.WithCustomerFk();
        b.WithSaleFk(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class AffiliateCommissionConfiguration : IEntityTypeConfiguration<AffiliateCommission>
{
    public void Configure(EntityTypeBuilder<AffiliateCommission> b)
    {
        b.ToTable("msg_affiliate_commissions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.CommissionAmount).HasColumnType("numeric(18,2)");
        b.Property(x => x.PaymentStatus).HasDefaultValue("PENDING");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("payment_status", "PENDING", "PAID", "CANCELLED");
        b.WithTenantOrgBusFks();
        b.WithAffiliateFk(DeleteBehavior.Restrict);
        // (tenant_id, org_id, bus_id, loc_id, referral_id) → msg_affiliate_referrals SET NULL
        b.HasOne<AffiliateReferral>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "ReferralId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        // (tenant_id, org_id, bus_id, loc_id, sale_id) → msg_sales SET NULL
        b.HasOne<Sale>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        // (tenant_id, loc_id) → cp_locations SET NULL
        b.HasOne<Location>().WithMany().HasForeignKey("LocId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}
