using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class CustomerDeleteFkNoSetNullOverCompositeKey : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_credit_scores_customers_tenant_id_org_id_bus_id_custome",
                schema: "mystoreguard",
                table: "msg_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_cards_msg_customers_tenant_id_org_id_bus_id_purcha",
                schema: "mystoreguard",
                table: "msg_gift_cards");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_credit_scores_customers_tenant_id_org_id_bus_id_custome",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_cards_msg_customers_tenant_id_org_id_bus_id_purcha",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchased_by_customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_credit_scores_customers_tenant_id_org_id_bus_id_custome",
                schema: "mystoreguard",
                table: "msg_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_cards_msg_customers_tenant_id_org_id_bus_id_purcha",
                schema: "mystoreguard",
                table: "msg_gift_cards");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_credit_scores_customers_tenant_id_org_id_bus_id_custome",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_cards_msg_customers_tenant_id_org_id_bus_id_purcha",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchased_by_customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);
        }
    }
}
