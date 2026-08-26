using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentSettlementDiscount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_allocations_allocation_type",
                schema: "mystoreguard",
                table: "msg_installment_allocations");

            migrationBuilder.AddColumn<decimal>(
                name: "settlement_discount",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_allocations_allocation_type",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                sql: "allocation_type IN ('INITIAL','SCHEDULED','OVERPAYMENT','SETTLEMENT_DISCOUNT')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_allocations_allocation_type",
                schema: "mystoreguard",
                table: "msg_installment_allocations");

            migrationBuilder.DropColumn(
                name: "settlement_discount",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_allocations_allocation_type",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                sql: "allocation_type IN ('INITIAL','SCHEDULED','OVERPAYMENT')");
        }
    }
}
