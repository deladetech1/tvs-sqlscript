using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.MyStoreGuard.Entities;

public class ProductMetadata : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string OfType { get; set; } = default!;
}

public class Supplier : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Fullname { get; set; } = default!;
    public string? Email { get; set; }
    public string? Contact { get; set; }
    public string? Address { get; set; }
}

public class Customer : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string Fullname { get; set; } = default!;
    public string? Email { get; set; }
    public string? Contact { get; set; }
    public string? Address { get; set; }
}

public class MsgDocumentPath : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string DocumentPathValue { get; set; } = default!;
    public string? FileName { get; set; }
}

public class PurchaseBatch
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;

    public string ProductId { get; set; } = default!;
    public string? SupplierId { get; set; }
    public string BatchNumber { get; set; } = default!;
    public string CurrencyId { get; set; } = default!;

    public decimal? CostPrice { get; set; }
    public decimal? BaseSellingPrice { get; set; }

    public string? ProductSize { get; set; }
    public string? UnitOfMeasureId { get; set; }
    public DateOnly? ProductExpiryDate { get; set; }

    public decimal? QtyOrdered { get; set; }
    public decimal QtyReceived { get; set; }
    public decimal QtyRemainingForPurchaseOrder { get; set; }
    public decimal QtyRemaining { get; set; }

    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public bool IsActive { get; set; } = true;
    public string BatchType { get; set; } = "PURCHASE";
    public string Status { get; set; } = default!;
    public DateOnly? ReceivedDate { get; set; }
    public TimeOnly? ReceivedTime { get; set; }
    public DateTimeOffset Cdatetime { get; set; }
    public string Cdate { get; set; } = default!;
    public string Ctime { get; set; } = default!;
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class Product : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Sku { get; set; }
    public string? BarCode { get; set; }
}

public class PurchaseOrder
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string SupplierId { get; set; } = default!;
    public string PoNumber { get; set; } = default!;
    public string? AssignTo { get; set; }
    public string Status { get; set; } = default!;
    public DateOnly OrderDate { get; set; }
    public DateOnly? ExpectedDeliveryDate { get; set; }
    public string? Notes { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string CreatedBy { get; set; } = default!;
}

public class PurchaseOrderItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PurchaseOrderId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public int QtyOrdered { get; set; }
    public int QtyReceived { get; set; }
    public int QtyRemaining { get; set; }
    public string CurrencyId { get; set; } = default!;
    public decimal CostPrice { get; set; }
    public decimal BaseSellingPrice { get; set; }
    public string? ProductSize { get; set; }
    public string? UnitOfMeasureId { get; set; }
    public DateOnly? ProductExpiryDate { get; set; }
}

public class PurchaseReceipt
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string PurchaseOrderId { get; set; } = default!;
    public string ReceiptNumber { get; set; } = default!;
    public DateOnly ReceivedDate { get; set; }
    public string? Description { get; set; }
    public string? CreatedBy { get; set; }
    public string? DeletedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string Status { get; set; } = default!;
}

public class StoreProduct : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public int CurrentQty { get; set; }
    public string? Comment { get; set; }
    public int ReorderLevel { get; set; }
    public int ReorderQuantity { get; set; }
}

public class WarehouseProduct : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public int CurrentQty { get; set; }
    public string? Comment { get; set; }
    public int ReorderLevel { get; set; }
    public int ReorderQuantity { get; set; }
}

public class BatchLocation
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string? PurchaseBatcheId { get; set; }
    public string LocationType { get; set; } = default!;
    public int Qty { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class ProductMovement
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? BatchId { get; set; }
    public string? LocationType { get; set; }
    public string? LocationId { get; set; }
    public string MovementType { get; set; } = default!;
    public int Qty { get; set; }
    public string? Reason { get; set; }
    public string? ReferenceId { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class ProductTransfer
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Source { get; set; } = default!;
    public string SourceId { get; set; } = default!;
    public string Destination { get; set; } = default!;
    public string DestinationId { get; set; } = default!;
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string Status { get; set; } = "PENDING_APPROVAL";
    public string? Description { get; set; }
    public string TransferNumber { get; set; } = default!;
    public string? PersonToApproveId { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

// Line items for a product transfer. Each row is one product + quantity that
// belongs to the parent transfer (msg_product_transfers). A transfer can carry
// many items; the header holds the shared source/destination/approval context.
public class ProductTransferItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TransferId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public int Qty { get; set; }
    public string Status { get; set; } = "PENDING_APPROVAL";
}

// Approval / rejection decisions recorded against a transfer. One row per
// decision: who acted, whether they APPROVED or REJECTED, and an optional reason.
public class ProductTransferApproval
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TransferId { get; set; } = default!;
    public string Action { get; set; } = default!;   // APPROVED | REJECTED
    public string? Reason { get; set; }
    public string PerformedBy { get; set; } = default!;
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
}

// A manual stock-taking session at a single location. Captures one physical
// count of on-hand stock for a store or warehouse so discrepancies between the
// shelf and the system can be detected and investigated. The counted lines live
// in msg_stock_take_items. Status moves DRAFT -> COMPLETED (counting finished)
// or DRAFT -> CANCELLED. Completing does NOT change stock on its own.
public class StockTake
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;
    public string LocationType { get; set; } = default!;   // STORE | WAREHOUSE
    public string StockTakeNumber { get; set; } = default!;
    public string Status { get; set; } = "DRAFT";          // DRAFT | COMPLETED | CANCELLED
    public string? Description { get; set; }
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public DateTimeOffset? CompletedDatetime { get; set; }
    public string? CompletedBy { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

// One counted product line within a stock take. system_qty is snapshotted from
// the location's on-hand qty (msg_store_products / msg_warehouse_products) at the
// time the line is recorded; variance_qty = counted_qty - system_qty and
// match_status summarises the comparison (MATCH | OVER | SHORT). A mismatch is
// worked through resolution_status (PENDING -> INVESTIGATING -> RESOLVED).
//
// Correcting stock is OPTIONAL and explicit: at resolution adjustment_qty may be
// set (signed: positive adds stock, negative reduces it). When non-zero, the
// service applies it to current_qty and writes a matching msg_product_movements
// row whose id is kept in adjustment_movement_id. Counting alone never moves stock.
public class StockTakeItem
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string StockTakeId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public int CountedQty { get; set; }
    public int SystemQty { get; set; }
    public int VarianceQty { get; set; }
    public string MatchStatus { get; set; } = "MATCH";        // MATCH | OVER | SHORT
    public string ResolutionStatus { get; set; } = "PENDING"; // PENDING | INVESTIGATING | RESOLVED
    public string? Note { get; set; }
    public string? ResolutionNote { get; set; }
    public int AdjustmentQty { get; set; }                    // signed correction applied at resolution; 0 = none
    public string? AdjustmentMovementId { get; set; }         // FK-ish link to the msg_product_movements row created
    public string? ResolvedBy { get; set; }
    public DateTimeOffset? ResolvedDatetime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
}

public class ProductDocumentId : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string DocumentId { get; set; } = default!;
}

public class AssignMetadataToProduct
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string ProductMetadataId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class ProductPrice
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string ProductId { get; set; } = default!;
    public string OfType { get; set; } = default!;
    public string? TargetId { get; set; }
    public decimal Price { get; set; }
    public string Currency { get; set; } = default!;
    public int Priority { get; set; }
    public bool StopsOtherPrices { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}
