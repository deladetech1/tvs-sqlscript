using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrLeaveTypeAnnualEntitlement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "is_annual_entitlement",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // One-time carry-over of the old rule (a type named "annual" was the entitlement), so
            // existing companies keep the same figures. From here on the flag decides.
            migrationBuilder.Sql(
                "UPDATE zeloshr.zhr_leave_types SET is_annual_entitlement = true WHERE name ILIKE '%annual%';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "is_annual_entitlement",
                schema: "zeloshr",
                table: "zhr_leave_types");
        }
    }
}
