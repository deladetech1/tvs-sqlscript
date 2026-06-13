using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260613150000_AddZhrLeaveAuditColumns")]
    public partial class AddZhrLeaveAuditColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_leave_requests
                SET created_at = submitted_at,
                    updated_at = COALESCE(decided_at, hod_decided_at, lm_decided_at, submitted_at)
                """);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_leave_types",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_public_holidays",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_public_holidays",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "created_at", schema: "zeloshr", table: "zhr_leave_requests");
            migrationBuilder.DropColumn(name: "updated_at", schema: "zeloshr", table: "zhr_leave_requests");
            migrationBuilder.DropColumn(name: "created_by", schema: "zeloshr", table: "zhr_leave_requests");
            migrationBuilder.DropColumn(name: "updated_by", schema: "zeloshr", table: "zhr_leave_requests");

            migrationBuilder.DropColumn(name: "created_at", schema: "zeloshr", table: "zhr_leave_balances");
            migrationBuilder.DropColumn(name: "updated_at", schema: "zeloshr", table: "zhr_leave_balances");
            migrationBuilder.DropColumn(name: "created_by", schema: "zeloshr", table: "zhr_leave_balances");
            migrationBuilder.DropColumn(name: "updated_by", schema: "zeloshr", table: "zhr_leave_balances");

            migrationBuilder.DropColumn(name: "created_by", schema: "zeloshr", table: "zhr_leave_types");
            migrationBuilder.DropColumn(name: "updated_by", schema: "zeloshr", table: "zhr_leave_types");

            migrationBuilder.DropColumn(name: "created_by", schema: "zeloshr", table: "zhr_public_holidays");
            migrationBuilder.DropColumn(name: "updated_by", schema: "zeloshr", table: "zhr_public_holidays");
        }
    }
}
