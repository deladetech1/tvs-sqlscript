using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class RenameInstallmentPolicyAmountBandToItem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_amount_band",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.RenameColumn(
                name: "min_sale_amount",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                newName: "min_item_amount");

            migrationBuilder.RenameColumn(
                name: "max_sale_amount",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                newName: "max_item_amount");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_amount_band",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "min_item_amount IS NULL OR max_item_amount IS NULL OR max_item_amount >= min_item_amount");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_amount_band",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.RenameColumn(
                name: "min_item_amount",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                newName: "min_sale_amount");

            migrationBuilder.RenameColumn(
                name: "max_item_amount",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                newName: "max_sale_amount");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_amount_band",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "min_sale_amount IS NULL OR max_sale_amount IS NULL OR max_sale_amount >= min_sale_amount");
        }
    }
}
