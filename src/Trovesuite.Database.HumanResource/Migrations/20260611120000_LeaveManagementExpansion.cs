using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260611120000_LeaveManagementExpansion")]
    public partial class LeaveManagementExpansion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "notes",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_leave_types",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    country_code = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: true),
                    default_entitled_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    is_paid = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_leave_types", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_public_holidays",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    country_code = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    holiday_date = table.Column<DateOnly>(type: "date", nullable: false),
                    is_recurring = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    branch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_public_holidays", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                columns: new[] { "tenant_id", "org_id", "employee_id", "leave_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_types_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_leave_types",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_public_holidays_tenant_id_org_id_country_code_holiday_d",
                schema: "zeloshr",
                table: "zhr_public_holidays",
                columns: new[] { "tenant_id", "org_id", "country_code", "holiday_date", "name" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_public_holidays",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_leave_types",
                schema: "zeloshr");

            migrationBuilder.DropIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type",
                schema: "zeloshr",
                table: "zhr_leave_balances");

            migrationBuilder.DropColumn(
                name: "notes",
                schema: "zeloshr",
                table: "zhr_leave_requests");
        }
    }
}
