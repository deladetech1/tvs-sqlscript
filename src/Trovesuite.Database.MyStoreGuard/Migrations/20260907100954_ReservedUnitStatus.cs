using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class ReservedUnitStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_units_status",
                schema: "mystoreguard",
                table: "msg_product_units");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_units_status",
                schema: "mystoreguard",
                table: "msg_product_units",
                sql: "status IN ('IN_STOCK','RESERVED','SOLD','RETURNED','FAULTY','WRITTEN_OFF')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_units_status",
                schema: "mystoreguard",
                table: "msg_product_units");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_units_status",
                schema: "mystoreguard",
                table: "msg_product_units",
                sql: "status IN ('IN_STOCK','SOLD','RETURNED','FAULTY','WRITTEN_OFF')");
        }
    }
}
