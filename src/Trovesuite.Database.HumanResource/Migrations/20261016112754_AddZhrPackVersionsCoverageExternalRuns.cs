using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrPackVersionsCoverageExternalRuns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "receipt_file_id",
                schema: "zeloshr",
                table: "zhr_payroll_filings");

            migrationBuilder.AddColumn<string>(
                name: "calculation_mode",
                schema: "zeloshr",
                table: "zhr_payroll_runs",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "native");

            migrationBuilder.AddColumn<string>(
                name: "receipt_document_id",
                schema: "zeloshr",
                table: "zhr_payroll_filings",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_country_coverage",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    choice = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    note = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    document_ids_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'[]'::jsonb"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_country_coverage", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pack_acknowledgements",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    version = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pack_acknowledgements", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pack_issue_reports",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    version = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    field = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    comment = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "sent"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pack_issue_reports", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_country_coverage_tenant_id_org_id_country",
                schema: "zeloshr",
                table: "zhr_country_coverage",
                columns: new[] { "tenant_id", "org_id", "country" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pack_acknowledgements_tenant_id_org_id_country_version",
                schema: "zeloshr",
                table: "zhr_pack_acknowledgements",
                columns: new[] { "tenant_id", "org_id", "country", "version" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pack_issue_reports_tenant_id_org_id_country",
                schema: "zeloshr",
                table: "zhr_pack_issue_reports",
                columns: new[] { "tenant_id", "org_id", "country" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_country_coverage",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_pack_acknowledgements",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_pack_issue_reports",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "calculation_mode",
                schema: "zeloshr",
                table: "zhr_payroll_runs");

            migrationBuilder.DropColumn(
                name: "receipt_document_id",
                schema: "zeloshr",
                table: "zhr_payroll_filings");

            migrationBuilder.AddColumn<Guid>(
                name: "receipt_file_id",
                schema: "zeloshr",
                table: "zhr_payroll_filings",
                type: "uuid",
                nullable: true);
        }
    }
}
