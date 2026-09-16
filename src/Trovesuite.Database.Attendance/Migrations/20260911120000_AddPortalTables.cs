using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Attendance.Migrations
{
    public partial class AddPortalTables : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "auto_closed",
                schema: "attendance",
                table: "att_attendance_records",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "capture_source",
                schema: "attendance",
                table: "att_attendance_records",
                type: "text",
                nullable: false,
                defaultValue: "web");

            migrationBuilder.AddColumn<bool>(
                name: "is_adjusted",
                schema: "attendance",
                table: "att_attendance_records",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "ix_att_attendance_records_tenant_id_org_id_employee_id_attendance_date",
                schema: "attendance",
                table: "att_attendance_records",
                columns: new[] { "tenant_id", "org_id", "employee_id", "attendance_date" },
                unique: true);

            migrationBuilder.AddColumn<string>(
                name: "job_title",
                schema: "attendance",
                table: "att_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "reports_to_employee_id",
                schema: "attendance",
                table: "att_employees",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "is_line_manager",
                schema: "attendance",
                table: "att_employees",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "is_head_of_department",
                schema: "attendance",
                table: "att_employees",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "ix_att_employees_tenant_id_org_id_reports_to_employee_id",
                schema: "attendance",
                table: "att_employees",
                columns: new[] { "tenant_id", "org_id", "reports_to_employee_id" });

            migrationBuilder.CreateTable(
                name: "att_punches",
                schema: "attendance",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    attendance_id = table.Column<Guid>(type: "uuid", nullable: false),
                    punch_type = table.Column<string>(type: "text", nullable: false),
                    punched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    source = table.Column<string>(type: "text", nullable: false, defaultValue: "web"),
                    device_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_superseded = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_att_punches", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_att_punches_tenant_id_org_id_employee_id_punched_at",
                schema: "attendance",
                table: "att_punches",
                columns: new[] { "tenant_id", "org_id", "employee_id", "punched_at" });

            migrationBuilder.CreateIndex(
                name: "ix_att_punches_attendance_id",
                schema: "attendance",
                table: "att_punches",
                column: "attendance_id");

            migrationBuilder.CreateTable(
                name: "att_adjustments",
                schema: "attendance",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    attendance_id = table.Column<Guid>(type: "uuid", nullable: true),
                    attendance_date = table.Column<DateOnly>(type: "date", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    punch_type = table.Column<string>(type: "text", nullable: true),
                    punch_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    original_punch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    reason = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_att_adjustments", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_att_adjustments_tenant_id_org_id_employee_id_attendance_date",
                schema: "attendance",
                table: "att_adjustments",
                columns: new[] { "tenant_id", "org_id", "employee_id", "attendance_date" });

            migrationBuilder.CreateTable(
                name: "att_devices",
                schema: "attendance",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    vendor = table.Column<string>(type: "text", nullable: true),
                    model = table.Column<string>(type: "text", nullable: true),
                    serial = table.Column<string>(type: "text", nullable: true),
                    location = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_att_devices", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_att_devices_tenant_id_org_id_name",
                schema: "attendance",
                table: "att_devices",
                columns: new[] { "tenant_id", "org_id", "name" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "att_punches", schema: "attendance");
            migrationBuilder.DropTable(name: "att_adjustments", schema: "attendance");
            migrationBuilder.DropTable(name: "att_devices", schema: "attendance");

            migrationBuilder.DropIndex(
                name: "ix_att_attendance_records_tenant_id_org_id_employee_id_attendance_date",
                schema: "attendance",
                table: "att_attendance_records");

            migrationBuilder.DropIndex(
                name: "ix_att_employees_tenant_id_org_id_reports_to_employee_id",
                schema: "attendance",
                table: "att_employees");

            migrationBuilder.DropColumn(name: "auto_closed", schema: "attendance", table: "att_attendance_records");
            migrationBuilder.DropColumn(name: "capture_source", schema: "attendance", table: "att_attendance_records");
            migrationBuilder.DropColumn(name: "is_adjusted", schema: "attendance", table: "att_attendance_records");
            migrationBuilder.DropColumn(name: "job_title", schema: "attendance", table: "att_employees");
            migrationBuilder.DropColumn(name: "reports_to_employee_id", schema: "attendance", table: "att_employees");
            migrationBuilder.DropColumn(name: "is_line_manager", schema: "attendance", table: "att_employees");
            migrationBuilder.DropColumn(name: "is_head_of_department", schema: "attendance", table: "att_employees");
        }
    }
}
