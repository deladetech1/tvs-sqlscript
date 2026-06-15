using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260615160000_AddZhrLeaveTypePolicyFields")]
    public partial class AddZhrLeaveTypePolicyFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "accrual_method",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "front_loaded");

            migrationBuilder.AddColumn<bool>(
                name: "carry_over_allowed",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "applies_to_employment_types",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "min_notice_working_days",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "max_consecutive_days",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "requires_supporting_document",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "accrual_method", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "carry_over_allowed", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "applies_to_employment_types", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "min_notice_working_days", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "max_consecutive_days", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "requires_supporting_document", schema: "zeloshr", table: "zhr_leave_types");
        }
    }
}
