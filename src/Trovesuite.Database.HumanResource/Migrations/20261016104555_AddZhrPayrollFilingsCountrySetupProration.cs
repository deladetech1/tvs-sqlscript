using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrPayrollFilingsCountrySetupProration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "country_setup_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'{}'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "proration",
                schema: "zeloshr",
                table: "zhr_pay_groups",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "calendar_days");

            migrationBuilder.CreateTable(
                name: "zhr_payroll_filings",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    deadline_id = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    period = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: false),
                    filed_on = table.Column<DateOnly>(type: "date", nullable: true),
                    filed_ref = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    filed_by = table.Column<string>(type: "text", nullable: true),
                    paid_on = table.Column<DateOnly>(type: "date", nullable: true),
                    paid_ref = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    paid_by = table.Column<string>(type: "text", nullable: true),
                    receipt_file_id = table.Column<Guid>(type: "uuid", nullable: true),
                    receipt_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payroll_filings", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_filings_tenant_id_org_id_country_deadline_id_pe",
                schema: "zeloshr",
                table: "zhr_payroll_filings",
                columns: new[] { "tenant_id", "org_id", "country", "deadline_id", "period" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_payroll_filings",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "country_setup_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "proration",
                schema: "zeloshr",
                table: "zhr_pay_groups");
        }
    }
}
