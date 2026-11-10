using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrTalentDetailsReportsAlertsReturns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "details",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "details",
                schema: "zeloshr",
                table: "zhr_offboarding_cases",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "details",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "details",
                schema: "zeloshr",
                table: "zhr_candidates",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.CreateTable(
                name: "zhr_alert_settings",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    lead_days = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    last_emailed_on = table.Column<DateOnly>(type: "date", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_alert_settings", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_external_return_files",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    pay_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    document_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    name = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    size_kb = table.Column<int>(type: "integer", nullable: false),
                    uploaded_by = table.Column<string>(type: "text", nullable: true),
                    uploaded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_external_return_files", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_saved_reports",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    report_id = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    options = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    schedule = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "none"),
                    last_run_on = table.Column<DateOnly>(type: "date", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_saved_reports", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_alert_settings_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_alert_settings",
                columns: new[] { "tenant_id", "org_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_external_return_files_tenant_id_org_id_pay_group_id",
                schema: "zeloshr",
                table: "zhr_external_return_files",
                columns: new[] { "tenant_id", "org_id", "pay_group_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_saved_reports_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_saved_reports",
                columns: new[] { "tenant_id", "org_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_alert_settings",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_external_return_files",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_saved_reports",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "details",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "details",
                schema: "zeloshr",
                table: "zhr_offboarding_cases");

            migrationBuilder.DropColumn(
                name: "details",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "details",
                schema: "zeloshr",
                table: "zhr_candidates");
        }
    }
}
