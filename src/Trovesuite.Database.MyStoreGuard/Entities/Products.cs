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

    /// <summary>
    /// How this product is tracked in stock.
    ///
    /// COUNTED is what the system has always done and what every existing product
    /// gets: stock is a number, and one unit is as good as another. SERIALISED
    /// means every single unit is identified — a phone by its IMEI, a vehicle by
    /// its VIN — and the shop needs to know which one it sold, transferred or took
    /// back, not merely how many.
    ///
    /// It sits on the product rather than on each receipt of stock deliberately.
    /// Decided per delivery, one consignment of iPhones would arrive with serials
    /// and the next without, and nothing afterwards could tell you which half of
    /// your stock was accounted for.
    /// </summary>
    public string TrackingType { get; set; } = "COUNTED";

}

/// <summary>
/// One physical unit of a serialised product — one handset, one vehicle.
///
/// The row is created when stock is received and lives as long as the unit does,
/// changing status and location as it moves. It is deliberately not deleted when
/// sold: the whole reason for recording an IMEI is to be able to answer, months
/// later, who bought this one and is it still under warranty.
/// </summary>
public class ProductUnit
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;

    public string ProductId { get; set; } = default!;
    /// <summary>The consignment this unit arrived in. One batch holds many units.</summary>
    public string BatchId { get; set; } = default!;

    // The numbers themselves live in ProductUnitIdentifier, one row each. A unit
    // does not have a number, it has a set of them: a dual-SIM handset carries two
    // IMEIs and a serial that is none of them, and a vehicle carries a VIN, an
    // engine number and a chassis number. A column, or two columns, is a guess at
    // how many — and the guess is wrong for most of what this shop sells.

    /// <summary>
    /// Where the unit is now, or null while it is still in the unallocated pool.
    ///
    /// Stock does not arrive at a branch. A batch is received against the business
    /// and distributed to a store or warehouse afterwards, which is why the batch
    /// itself carries no location either. Null here means the same thing it means
    /// for a batch: received, not yet anywhere. Once allocated it names the branch,
    /// because a handset at Osu must not be sellable from Accra.
    /// </summary>
    public string? LocId { get; set; }

    /// <summary>
    /// IN_STOCK is offered for sale; SOLD is not, but stays findable by serial for
    /// warranty. RETURNED goes back to IN_STOCK when a customer brings it back —
    /// hiding a unit forever the moment it sells would lose it on the first return.
    /// FAULTY and WRITTEN_OFF are present but not sellable.
    /// </summary>
    public string Status { get; set; } = "IN_STOCK";

    /// <summary>The sale that took it out, kept so a serial can be traced to a customer.</summary>
    public string? SaleId { get; set; }
    public DateTimeOffset? SoldAt { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// One number printed on one physical unit.
///
/// A phone carries two IMEIs and a serial number that is neither of them; a
/// vehicle carries a VIN, an engine number and a chassis number. Any of them may
/// be the one a customer quotes, a warranty claim cites or the police check, so
/// each is a row and any of them finds the unit.
///
/// Unique on the value across the business, whatever kind it is: a number
/// identifies one physical thing, and the same string turning up on two units
/// means somebody has mistyped or the box was scanned twice.
/// </summary>
public class ProductUnitIdentifier
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;

    public string UnitId { get; set; } = default!;

    /// <summary>
    /// What this number is called on the item itself — "IMEI 1", "IMEI 2",
    /// "Serial number", "VIN", "Engine number".
    ///
    /// Free text rather than a fixed list, because the list is never finished. A
    /// phone shop, a car dealer and a pharmacy print different things on their
    /// stock, and a shop that sells something nobody anticipated should type the
    /// label rather than wait for it to be added to an enum.
    /// </summary>
    public string Label { get; set; } = "Serial number";

    public string Value { get; set; } = default!;

    /// <summary>
    /// The one shown in lists and on the till, where there is room for a single
    /// number. Exactly one per unit — a unit with none would appear nameless, and
    /// a unit with two would appear differently depending on which was read first.
    /// </summary>
    public bool IsPrimary { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
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
    // Unit price supplied by the caller at count time (price is not stored on the
    // product itself — it lives per delivery). Snapshotted here so the variance can
    // be valued; variance value = variance_qty * unit_price.
    public decimal? UnitPrice { get; set; }
    // Currency snapshotted per line (plain text, not an FK): different products in
    // one count may be priced in different currencies, and a completed take must
    // stay frozen even if the currency record changes later.
    public string? CurrencyId { get; set; }
    public string? CurrencyName { get; set; }
    public string? CurrencySymbol { get; set; }
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
