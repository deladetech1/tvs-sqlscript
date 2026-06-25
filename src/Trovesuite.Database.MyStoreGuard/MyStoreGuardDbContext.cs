using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.CorePlatform;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard;

public class MyStoreGuardDbContext : DbContext
{
    public const string SchemaName = "mystoreguard";

    public MyStoreGuardDbContext(DbContextOptions<MyStoreGuardDbContext> options) : base(options) { }

    public DbSet<ProductMetadata> ProductMetadata => Set<ProductMetadata>();
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<MsgDocumentPath> DocumentPaths => Set<MsgDocumentPath>();
    public DbSet<PurchaseBatch> PurchaseBatches => Set<PurchaseBatch>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();
    public DbSet<PurchaseOrderItem> PurchaseOrderItems => Set<PurchaseOrderItem>();
    public DbSet<PurchaseReceipt> PurchaseReceipts => Set<PurchaseReceipt>();
    public DbSet<StoreProduct> StoreProducts => Set<StoreProduct>();
    public DbSet<WarehouseProduct> WarehouseProducts => Set<WarehouseProduct>();
    public DbSet<BatchLocation> BatchLocations => Set<BatchLocation>();
    public DbSet<ProductMovement> ProductMovements => Set<ProductMovement>();
    public DbSet<ProductTransfer> ProductTransfers => Set<ProductTransfer>();
    public DbSet<ProductTransferItem> ProductTransferItems => Set<ProductTransferItem>();
    public DbSet<ProductTransferApproval> ProductTransferApprovals => Set<ProductTransferApproval>();
    public DbSet<StockTake> StockTakes => Set<StockTake>();
    public DbSet<StockTakeItem> StockTakeItems => Set<StockTakeItem>();
    public DbSet<ProductDocumentId> ProductDocumentIds => Set<ProductDocumentId>();
    public DbSet<AssignMetadataToProduct> AssignMetadataToProducts => Set<AssignMetadataToProduct>();
    public DbSet<ProductPrice> ProductPrices => Set<ProductPrice>();

    public DbSet<PricingRule> PricingRules => Set<PricingRule>();
    public DbSet<ReturnPolicy> ReturnPolicies => Set<ReturnPolicy>();
    public DbSet<OpenAndClosingStock> OpenAndClosingStocks => Set<OpenAndClosingStock>();
    public DbSet<Tax> Taxes => Set<Tax>();
    public DbSet<TaxRule> TaxRules => Set<TaxRule>();
    public DbSet<TaxRuleCondition> TaxRuleConditions => Set<TaxRuleCondition>();
    public DbSet<MsgActivityLog> ActivityLogs => Set<MsgActivityLog>();
    public DbSet<StoreConfig> StoreConfigs => Set<StoreConfig>();
    public DbSet<WarehouseConfig> WarehouseConfigs => Set<WarehouseConfig>();
    public DbSet<StockTakingAudit> StockTakingAudits => Set<StockTakingAudit>();
    public DbSet<PromoCode> PromoCodes => Set<PromoCode>();
    public DbSet<Affiliate> Affiliates => Set<Affiliate>();
    public DbSet<Sale> Sales => Set<Sale>();
    public DbSet<SaleItem> SaleItems => Set<SaleItem>();
    public DbSet<GiftCard> GiftCards => Set<GiftCard>();
    public DbSet<SalePayment> SalePayments => Set<SalePayment>();
    public DbSet<Return> Returns => Set<Return>();
    public DbSet<ReturnItem> ReturnItems => Set<ReturnItem>();
    public DbSet<Appointment> Appointments => Set<Appointment>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<InvoiceItem> InvoiceItems => Set<InvoiceItem>();
    public DbSet<InvoicePayment> InvoicePayments => Set<InvoicePayment>();
    public DbSet<InvoiceSale> InvoiceSales => Set<InvoiceSale>();
    public DbSet<Delivery> Deliveries => Set<Delivery>();
    public DbSet<DeliveryItem> DeliveryItems => Set<DeliveryItem>();
    public DbSet<GiftCardTransaction> GiftCardTransactions => Set<GiftCardTransaction>();
    public DbSet<PromoCodeUsage> PromoCodeUsages => Set<PromoCodeUsage>();
    public DbSet<AffiliateReferral> AffiliateReferrals => Set<AffiliateReferral>();
    public DbSet<AffiliateCommission> AffiliateCommissions => Set<AffiliateCommission>();

    public DbSet<MsgMessage> Messages => Set<MsgMessage>();
    public DbSet<MsgMessageRecipient> MessageRecipients => Set<MsgMessageRecipient>();
    public DbSet<Meeting> Meetings => Set<Meeting>();
    public DbSet<MeetingParticipant> MeetingParticipants => Set<MeetingParticipant>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        ExternalCorePlatformEntities.Register(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(MyStoreGuardDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}
