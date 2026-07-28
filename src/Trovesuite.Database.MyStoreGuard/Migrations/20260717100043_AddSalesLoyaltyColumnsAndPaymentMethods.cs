using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddSalesLoyaltyColumnsAndPaymentMethods : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_sales_payments_payment_method",
                schema: "mystoreguard",
                table: "msg_sales_payments");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_purchase_orders_status",
                schema: "mystoreguard",
                table: "msg_purchase_orders");

            migrationBuilder.AddColumn<decimal>(
                name: "loyalty_amount_used",
                schema: "mystoreguard",
                table: "msg_sales",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "loyalty_points_used",
                schema: "mystoreguard",
                table: "msg_sales",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_sales_payments_payment_method",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                sql: "payment_method IN ('CASH','CARD','BANK_TRANSFER','MOBILE_MONEY','CHEQUE','BITCOIN','GIFT_CARD','LOYALTY_POINTS','OTHERS')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_purchase_orders_status",
                schema: "mystoreguard",
                table: "msg_purchase_orders",
                sql: "status IN ('DRAFT','APPROVED','PARTIALLY_RECEIVED','RECEIVED','CANCELLED','COMPLETED')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_sales_payments_payment_method",
                schema: "mystoreguard",
                table: "msg_sales_payments");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_purchase_orders_status",
                schema: "mystoreguard",
                table: "msg_purchase_orders");

            migrationBuilder.DropColumn(
                name: "loyalty_amount_used",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropColumn(
                name: "loyalty_points_used",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_sales_payments_payment_method",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                sql: "payment_method IN ('CASH','CARD','BANK_TRANSFER','MOBILE_MONEY','CHEQUE','BITCOIN','GIFT_CARD','OTHERS')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_purchase_orders_status",
                schema: "mystoreguard",
                table: "msg_purchase_orders",
                sql: "status IN ('DRAFT','APPROVED','PARTIALLY_RECEIVED','CANCELLED','COMPLETED')");
        }
    }
}
