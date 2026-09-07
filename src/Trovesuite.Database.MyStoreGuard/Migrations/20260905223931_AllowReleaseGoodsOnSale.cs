using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AllowReleaseGoodsOnSale : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_release_goods_on",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_release_goods_on",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "release_goods_on IN ('FULL_PAYMENT','INITIAL_PAYMENT','APPROVAL','ON_SALE')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_release_goods_on",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_release_goods_on",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "release_goods_on IN ('FULL_PAYMENT','INITIAL_PAYMENT','APPROVAL')");
        }
    }
}
