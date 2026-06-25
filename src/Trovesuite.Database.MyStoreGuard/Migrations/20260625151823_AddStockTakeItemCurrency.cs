using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddStockTakeItemCurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "currency_id",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "currency_name",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "currency_symbol",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "currency_id",
                schema: "mystoreguard",
                table: "msg_stock_take_items");

            migrationBuilder.DropColumn(
                name: "currency_name",
                schema: "mystoreguard",
                table: "msg_stock_take_items");

            migrationBuilder.DropColumn(
                name: "currency_symbol",
                schema: "mystoreguard",
                table: "msg_stock_take_items");
        }
    }
}
