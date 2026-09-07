using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class CommittedStockCheckOffByDefault : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_store_configs_committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs");

            migrationBuilder.AlterColumn<string>(
                name: "committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs",
                type: "text",
                nullable: false,
                defaultValue: "OFF",
                oldClrType: typeof(string),
                oldType: "text",
                oldDefaultValue: "WARN");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_store_configs_committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs",
                sql: "committed_stock_action IN ('OFF','WARN','BLOCK')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_store_configs_committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs");

            migrationBuilder.AlterColumn<string>(
                name: "committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs",
                type: "text",
                nullable: false,
                defaultValue: "WARN",
                oldClrType: typeof(string),
                oldType: "text",
                oldDefaultValue: "OFF");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_store_configs_committed_stock_action",
                schema: "mystoreguard",
                table: "msg_store_configs",
                sql: "committed_stock_action IN ('WARN','BLOCK')");
        }
    }
}
