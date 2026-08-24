using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class RenameDepositSaleModeToInstallment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_sales_sale_mode",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_invoices_sale_mode",
                schema: "mystoreguard",
                table: "msg_invoices");

            // Backfill BEFORE re-adding the constraint. Postgres validates every
            // existing row when a CHECK is added, so any live DEPOSIT sale would
            // abort the migration. This has to sit inside the migration rather
            // than in migrations/shared/ — shared SQL runs after EF, i.e. too late.
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_sales SET sale_mode = 'INSTALLMENT' WHERE sale_mode = 'DEPOSIT';");
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_invoices SET sale_mode = 'INSTALLMENT' WHERE sale_mode = 'DEPOSIT';");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_sales_sale_mode",
                schema: "mystoreguard",
                table: "msg_sales",
                sql: "sale_mode IN ('INSTANT','INSTALLMENT','CREDIT')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_invoices_sale_mode",
                schema: "mystoreguard",
                table: "msg_invoices",
                sql: "sale_mode IN ('INSTANT','INSTALLMENT','CREDIT')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_sales_sale_mode",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_invoices_sale_mode",
                schema: "mystoreguard",
                table: "msg_invoices");

            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_sales SET sale_mode = 'DEPOSIT' WHERE sale_mode = 'INSTALLMENT';");
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_invoices SET sale_mode = 'DEPOSIT' WHERE sale_mode = 'INSTALLMENT';");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_sales_sale_mode",
                schema: "mystoreguard",
                table: "msg_sales",
                sql: "sale_mode IN ('INSTANT','DEPOSIT','CREDIT')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_invoices_sale_mode",
                schema: "mystoreguard",
                table: "msg_invoices",
                sql: "sale_mode IN ('INSTANT','DEPOSIT','CREDIT')");
        }
    }
}
