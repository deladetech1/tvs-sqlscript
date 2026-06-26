using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddStockTakeItemUnitPrice : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "unit_price",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                type: "numeric(18,2)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "unit_price",
                schema: "mystoreguard",
                table: "msg_stock_take_items");
        }
    }
}
