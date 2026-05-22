using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class RemoveProductNameUniqueConstraint : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_msg_products_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_products");

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "name" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_msg_products_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_products");

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "name" },
                unique: true);
        }
    }
}
