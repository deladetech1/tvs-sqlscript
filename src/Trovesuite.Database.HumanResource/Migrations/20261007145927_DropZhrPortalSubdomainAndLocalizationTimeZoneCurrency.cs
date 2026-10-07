using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class DropZhrPortalSubdomainAndLocalizationTimeZoneCurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_employee_portal_subdomain",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "currency_id",
                schema: "zeloshr",
                table: "zhr_company_localization");

            migrationBuilder.DropColumn(
                name: "time_zone",
                schema: "zeloshr",
                table: "zhr_company_localization");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "currency_id",
                schema: "zeloshr",
                table: "zhr_company_localization",
                type: "character varying(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "time_zone",
                schema: "zeloshr",
                table: "zhr_company_localization",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "zhr_employee_portal_subdomain",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    bus_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    loc_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    subdomain = table.Column<string>(type: "character varying(63)", maxLength: 63, nullable: false),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_portal_subdomain", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_portal_subdomain_subdomain",
                schema: "zeloshr",
                table: "zhr_employee_portal_subdomain",
                column: "subdomain",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_portal_subdomain_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_employee_portal_subdomain",
                columns: new[] { "tenant_id", "org_id" },
                unique: true);
        }
    }
}
