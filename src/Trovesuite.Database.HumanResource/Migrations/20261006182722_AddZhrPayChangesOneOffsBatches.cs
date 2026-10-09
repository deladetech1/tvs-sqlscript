using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrPayChangesOneOffsBatches : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "change_request_id",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "change_type",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "change_value",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_payment_batches",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    run_id = table.Column<Guid>(type: "uuid", nullable: false),
                    channel = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    reference = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    items_json = table.Column<string>(type: "jsonb", nullable: false),
                    events_json = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payment_batches", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_payroll_one_offs",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    component = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    amount = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    basis = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    taxable = table.Column<bool>(type: "boolean", nullable: false),
                    pay_from = table.Column<DateOnly>(type: "date", nullable: false),
                    recurrence = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    months = table.Column<int>(type: "integer", nullable: true),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    cancelled = table.Column<bool>(type: "boolean", nullable: false),
                    cancel_reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    included_run_ids_json = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payroll_one_offs", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_compensation_versions_change_request_id",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                column: "change_request_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payment_batches_tenant_id_org_id_run_id",
                schema: "zeloshr",
                table: "zhr_payment_batches",
                columns: new[] { "tenant_id", "org_id", "run_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_one_offs_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_payroll_one_offs",
                columns: new[] { "tenant_id", "org_id", "employee_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_payment_batches",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_payroll_one_offs",
                schema: "zeloshr");

            migrationBuilder.DropIndex(
                name: "ix_zhr_compensation_versions_change_request_id",
                schema: "zeloshr",
                table: "zhr_compensation_versions");

            migrationBuilder.DropColumn(
                name: "change_request_id",
                schema: "zeloshr",
                table: "zhr_compensation_versions");

            migrationBuilder.DropColumn(
                name: "change_type",
                schema: "zeloshr",
                table: "zhr_compensation_versions");

            migrationBuilder.DropColumn(
                name: "change_value",
                schema: "zeloshr",
                table: "zhr_compensation_versions");
        }
    }
}
