using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

internal static class MsgDefaults
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

    /// <summary>(TenantId, OrgId, BusId, ProductId) → msg_products(TenantId, OrgId, BusId, Id).</summary>
    public static EntityTypeBuilder<T> WithProductFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Product>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "ProductId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, LocId, SaleId) → msg_sales(TenantId, OrgId, BusId, LocId, Id).</summary>
    public static EntityTypeBuilder<T> WithSaleFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Sale>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "SaleId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, LocId, InvoiceId) → msg_invoices.</summary>
    public static EntityTypeBuilder<T> WithInvoiceFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Invoice>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "InvoiceId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, LocId, ReturnId) → msg_returns.</summary>
    public static EntityTypeBuilder<T> WithReturnFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.Cascade) where T : class
    {
        b.HasOne<Return>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "ReturnId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, GiftCardId) → msg_gift_cards.</summary>
    public static EntityTypeBuilder<T> WithGiftCardFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.SetNull) where T : class
    {
        b.HasOne<GiftCard>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "GiftCardId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, PromoCodeId) → msg_promo_codes.</summary>
    public static EntityTypeBuilder<T> WithPromoCodeFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.SetNull) where T : class
    {
        b.HasOne<PromoCode>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PromoCodeId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, AffiliateId) → msg_affiliates.</summary>
    public static EntityTypeBuilder<T> WithAffiliateFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.SetNull) where T : class
    {
        b.HasOne<Affiliate>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "AffiliateId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, OrgId, BusId, CustomerId) → msg_customers.</summary>
    public static EntityTypeBuilder<T> WithCustomerFk<T>(this EntityTypeBuilder<T> b,
        DeleteBehavior onDelete = DeleteBehavior.SetNull) where T : class
    {
        b.HasOne<Customer>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "CustomerId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(onDelete);
        return b;
    }

    /// <summary>(TenantId, CurrencyId) → core_platform.cp_currencies(TenantId, Id).</summary>
    public static EntityTypeBuilder<T> WithCurrencyFk<T>(this EntityTypeBuilder<T> b,
        string columnName = "CurrencyId",
        DeleteBehavior onDelete = DeleteBehavior.Restrict) where T : class
    {
        if (b.Metadata.FindProperty(columnName) is null) return b;
        b.HasOne<Currency>().WithMany()
            .HasForeignKey(columnName, "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(onDelete);
        return b;
    }
}

public sealed class ProductMetadataConfiguration : IEntityTypeConfiguration<ProductMetadata>
{
    public void Configure(EntityTypeBuilder<ProductMetadata> b)
    {
        b.ToTable("msg_product_metadata");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Name, x.OfType }).IsUnique();
        b.HasInCheck("of_type", "TAG", "CATEGORY", "BRAND", "LABEL", "COLOR", "CONDITION");
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class SupplierConfiguration : IEntityTypeConfiguration<Supplier>
{
    public void Configure(EntityTypeBuilder<Supplier> b)
    {
        b.ToTable("msg_suppliers");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Email }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Contact }).IsUnique();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class CustomerConfiguration : IEntityTypeConfiguration<Customer>
{
    public void Configure(EntityTypeBuilder<Customer> b)
    {
        b.ToTable("msg_customers");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Email }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Contact }).IsUnique();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        // bkup: customers table only has org/bus FKs, not loc (despite having loc_id column)
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgDocumentPathConfiguration : IEntityTypeConfiguration<MsgDocumentPath>
{
    public void Configure(EntityTypeBuilder<MsgDocumentPath> b)
    {
        b.ToTable("msg_document_paths");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DocumentPathValue).HasColumnName("document_path");
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        // bkup: audit FKs ON DELETE SET NULL for document_paths
        b.WithCrossSchemaAuditUserFks(DeleteBehavior.SetNull);
    }
}

public sealed class PurchaseBatchConfiguration : IEntityTypeConfiguration<PurchaseBatch>
{
    public void Configure(EntityTypeBuilder<PurchaseBatch> b)
    {
        b.ToTable("msg_purchase_batches");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.CostPrice).HasColumnType("numeric(18,2)");
        b.Property(x => x.BaseSellingPrice).HasColumnType("numeric(18,2)");
        b.Property(x => x.QtyOrdered).HasColumnType("numeric(18,2)");
        b.Property(x => x.QtyReceived).HasColumnType("numeric(18,2)");
        b.Property(x => x.QtyRemainingForPurchaseOrder).HasColumnType("numeric(18,2)");
        b.Property(x => x.QtyRemaining).HasColumnType("numeric(18,2)");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.BatchType).HasDefaultValue("PURCHASE");
        b.Property(x => x.ReceivedDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.ReceivedTime).HasDefaultValueSql("CURRENT_TIME");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("delete_status", "NOT_DELETED", "DELETED");
        b.HasInCheck("batch_type", "OPENING_STOCK", "ADJUSTMENT", "PURCHASE");
        b.HasInCheck("status", "OPENING_STOCK", "RECEIVED", "PARTIALLY_ALLOCATED", "FULLY_ALLOCATED", "VOID", "CANCELLED");
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> b)
    {
        b.ToTable("msg_products");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        // Non-unique index on name (product names are NOT required to be unique).
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Name });
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class PurchaseOrderConfiguration : IEntityTypeConfiguration<PurchaseOrder>
{
    public void Configure(EntityTypeBuilder<PurchaseOrder> b)
    {
        b.ToTable("msg_purchase_orders");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PoNumber }).IsUnique();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        // RECEIVED = all items in but supplier not yet fully paid; COMPLETED = received AND paid.
        b.HasInCheck("status", "DRAFT", "APPROVED", "PARTIALLY_RECEIVED", "RECEIVED", "CANCELLED", "COMPLETED");
        b.WithTenantFk();
        // (tenant_id, org_id, bus_id, supplier_id) → msg_suppliers
        b.HasOne<Supplier>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "SupplierId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        // (tenant_id, created_by) → cp_users (RESTRICT)
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class PurchaseOrderItemConfiguration : IEntityTypeConfiguration<PurchaseOrderItem>
{
    public void Configure(EntityTypeBuilder<PurchaseOrderItem> b)
    {
        b.ToTable("msg_purchase_order_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.CostPrice).HasColumnType("numeric(10,2)");
        b.Property(x => x.BaseSellingPrice).HasColumnType("numeric(10,2)");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PurchaseOrderId, x.ProductId }).IsUnique();
        b.WithTenantFk();
        b.HasOne<PurchaseOrder>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PurchaseOrderId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithProductFk(DeleteBehavior.Restrict);
        b.WithCurrencyFk();
        // (tenant_id, unit_of_measure_id) → core_platform.cp_unit_of_measures
        b.HasOne<UnitOfMeasure>().WithMany()
            .HasForeignKey("UnitOfMeasureId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class PurchaseReceiptConfiguration : IEntityTypeConfiguration<PurchaseReceipt>
{
    public void Configure(EntityTypeBuilder<PurchaseReceipt> b)
    {
        b.ToTable("msg_purchase_receipts");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.ReceivedDate).HasDefaultValueSql("CURRENT_DATE");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.ReceiptNumber }).IsUnique();
        b.HasInCheck("status", "DRAFT", "APPROVED", "PARTIALLY_RECEIVED", "CANCELLED", "COMPLETED");
        b.WithTenantFk();
        b.HasOne<PurchaseOrder>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PurchaseOrderId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class StoreProductConfiguration : IEntityTypeConfiguration<StoreProduct>
{
    public void Configure(EntityTypeBuilder<StoreProduct> b)
    {
        b.ToTable("msg_store_products");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ProductId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithProductFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class WarehouseProductConfiguration : IEntityTypeConfiguration<WarehouseProduct>
{
    public void Configure(EntityTypeBuilder<WarehouseProduct> b)
    {
        b.ToTable("msg_warehouse_products");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.ProductId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        b.WithProductFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class BatchLocationConfiguration : IEntityTypeConfiguration<BatchLocation>
{
    public void Configure(EntityTypeBuilder<BatchLocation> b)
    {
        b.ToTable("msg_batch_locations");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.PurchaseBatcheId, x.LocationType, x.LocId }).IsUnique();
        b.HasInCheck("location_type", "STORE", "WAREHOUSE");
        b.WithTenantOrgBusLocFks();
        b.HasOne<PurchaseBatch>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "PurchaseBatcheId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ProductMovementConfiguration : IEntityTypeConfiguration<ProductMovement>
{
    public void Configure(EntityTypeBuilder<ProductMovement> b)
    {
        b.ToTable("msg_product_movements");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("location_type", "STORE", "WAREHOUSE", "SYSTEM", null!);
        b.HasInCheck("movement_type", "IN", "OUT", "TRANSFER", "REVERSAL");
        b.WithTenantOrgBusFks();
        b.WithProductFk();
        b.HasOne<PurchaseBatch>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "BatchId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class ProductTransferConfiguration : IEntityTypeConfiguration<ProductTransfer>
{
    public void Configure(EntityTypeBuilder<ProductTransfer> b)
    {
        b.ToTable("msg_product_transfers");
        // Pin the PK constraint name. Without this, the naming convention reclassifies
        // the key once a second child table references it (msg_product_transfer_approvals),
        // producing a spurious drop/recreate of the primary key in the migration.
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id }).HasName("pk_msg_product_transfers");
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Status).HasDefaultValue("PENDING_APPROVAL");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.TransferNumber }).IsUnique();
        b.HasInCheck("source", "STORE", "WAREHOUSE");
        b.HasInCheck("destination", "STORE", "WAREHOUSE");
        b.HasInCheck("status", "PENDING_APPROVAL", "APPROVED", "REJECTED", "COMPLETED");
        b.HasDeleteStatusCheck();
        b.WithTenantFk();
        // source_id / destination_id → core_platform.cp_locations(id, tenant_id) CASCADE
        b.HasOne<Location>().WithMany()
            .HasForeignKey("SourceId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Location>().WithMany()
            .HasForeignKey("DestinationId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        // person_to_approve_id, created_by → cp_users(id, tenant_id)
        b.HasOne<User>().WithMany().HasForeignKey("PersonToApproveId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ProductTransferItemConfiguration : IEntityTypeConfiguration<ProductTransferItem>
{
    public void Configure(EntityTypeBuilder<ProductTransferItem> b)
    {
        b.ToTable("msg_product_transfer_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING_APPROVAL");
        b.HasInCheck("status", "PENDING_APPROVAL", "APPROVED", "REJECTED", "COMPLETED");
        // one line per product per transfer
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.TransferId, x.ProductId }).IsUnique();
        b.WithTenantFk();
        // (tenant_id, org_id, bus_id, transfer_id) → msg_product_transfers, deleting the
        // header removes its items
        b.HasOne<ProductTransfer>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TransferId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithProductFk(DeleteBehavior.Restrict);
    }
}

public sealed class ProductTransferApprovalConfiguration : IEntityTypeConfiguration<ProductTransferApproval>
{
    public void Configure(EntityTypeBuilder<ProductTransferApproval> b)
    {
        b.ToTable("msg_product_transfer_approvals");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("action", "APPROVED", "REJECTED");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.TransferId });
        b.WithTenantFk();
        // (tenant_id, org_id, bus_id, transfer_id) → msg_product_transfers, decisions
        // are removed when the parent transfer is deleted
        b.HasOne<ProductTransfer>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TransferId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // performed_by → core_platform.cp_users(id, tenant_id)
        b.HasOne<User>().WithMany().HasForeignKey("PerformedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class StockTakeConfiguration : IEntityTypeConfiguration<StockTake>
{
    public void Configure(EntityTypeBuilder<StockTake> b)
    {
        b.ToTable("msg_stock_takes");
        // Pin the PK name: msg_stock_take_items references this key, which would
        // otherwise make the convention drop/recreate the PK in the migration.
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id }).HasName("pk_msg_stock_takes");
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("DRAFT");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.Property(x => x.CompletedDatetime).HasColumnType("timestamptz");
        // one stock-take number per location
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.StockTakeNumber }).IsUnique();
        b.HasInCheck("location_type", "STORE", "WAREHOUSE");
        b.HasInCheck("status", "DRAFT", "COMPLETED", "CANCELLED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusLocFks();
        // completed_by → core_platform.cp_users(id, tenant_id)
        b.HasOne<User>().WithMany().HasForeignKey("CompletedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class StockTakeItemConfiguration : IEntityTypeConfiguration<StockTakeItem>
{
    public void Configure(EntityTypeBuilder<StockTakeItem> b)
    {
        b.ToTable("msg_stock_take_items");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.MatchStatus).HasDefaultValue("MATCH");
        b.Property(x => x.ResolutionStatus).HasDefaultValue("PENDING");
        b.Property(x => x.AdjustmentQty).HasDefaultValue(0);
        b.Property(x => x.UnitPrice).HasColumnType("numeric(18,2)");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.Property(x => x.ResolvedDatetime).HasColumnType("timestamptz");
        b.HasInCheck("match_status", "MATCH", "OVER", "SHORT");
        b.HasInCheck("resolution_status", "PENDING", "INVESTIGATING", "RESOLVED");
        // one line per product per stock take
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StockTakeId, x.ProductId }).IsUnique();
        b.WithTenantFk();
        // (tenant_id, org_id, bus_id, stock_take_id) → msg_stock_takes, deleting the
        // header removes its lines
        b.HasOne<StockTake>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StockTakeId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithProductFk(DeleteBehavior.Restrict);
        // resolved_by → core_platform.cp_users(id, tenant_id)
        b.HasOne<User>().WithMany().HasForeignKey("ResolvedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ProductDocumentIdConfiguration : IEntityTypeConfiguration<ProductDocumentId>
{
    public void Configure(EntityTypeBuilder<ProductDocumentId> b)
    {
        b.ToTable("msg_product_document_ids");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.ApplyAuditDefaults();
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithProductFk();
        // (tenant_id, org_id, bus_id, document_id) → msg_document_paths
        b.HasOne<MsgDocumentPath>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "DocumentId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class AssignMetadataToProductConfiguration : IEntityTypeConfiguration<AssignMetadataToProduct>
{
    public void Configure(EntityTypeBuilder<AssignMetadataToProduct> b)
    {
        b.ToTable("msg_assign_metadata_to_products");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.WithTenantFk();
        b.HasOne<ProductMetadata>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "ProductMetadataId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithProductFk();
        // bkup: audit FKs ON DELETE SET NULL for assign_metadata
        b.WithCrossSchemaAuditUserFks(DeleteBehavior.SetNull);
    }
}

public sealed class ProductPriceConfiguration : IEntityTypeConfiguration<ProductPrice>
{
    public void Configure(EntityTypeBuilder<ProductPrice> b)
    {
        b.ToTable("msg_product_prices");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Price).HasColumnType("numeric(10,2)");
        b.Property(x => x.StopsOtherPrices).HasDefaultValue(false);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("of_type", "SKU", "GLOBAL", "LOCATION", "TAG", "CATEGORY", "BRAND", "LABEL",
            "COLOR", "CONDITION");
        // Unique COALESCE-based index applied via Sql/Triggers/01_product_prices_unique_index.sql.
        b.WithTenantOrgBusFks();
        b.WithProductFk();
        b.WithCurrencyFk("Currency");
        b.WithCrossSchemaAuditUserFks();
    }
}
