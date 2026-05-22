using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddProductTransferItems : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_product_transfers_msg_products_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_product_transfers");

            migrationBuilder.DropIndex(
                name: "ix_msg_product_transfers_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_transfers");

            migrationBuilder.DropColumn(
                name: "product_id",
                schema: "mystoreguard",
                table: "msg_product_transfers");

            migrationBuilder.DropColumn(
                name: "qty",
                schema: "mystoreguard",
                table: "msg_product_transfers");

            migrationBuilder.CreateTable(
                name: "msg_product_transfer_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    transfer_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    qty = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING_APPROVAL")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_transfer_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_transfer_items_status", "status IN ('PENDING_APPROVAL','APPROVED','REJECTED','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_items_msg_product_transfers_tenant_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.transfer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_product_transfers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_items_msg_products_tenant_id_org_id_bu",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfer_items_tenant_id_org_id_bus_id_product_",
                schema: "mystoreguard",
                table: "msg_product_transfer_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfer_items_tenant_id_org_id_bus_id_transfer",
                schema: "mystoreguard",
                table: "msg_product_transfer_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "transfer_id", "product_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_product_transfer_items",
                schema: "mystoreguard");

            migrationBuilder.AddColumn<string>(
                name: "product_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "qty",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_msg_product_transfers_msg_products_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_products",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);
        }
    }
}
