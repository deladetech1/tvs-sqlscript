using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrCompanySettingsTables : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_company_profile",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                legal_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                trading_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                industry = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                company_size = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                business_registration_number = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                tin = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                primary_work_country = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                company_email = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                website = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                logo_document_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                banner_document_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_company_profile", x => x.id);
            });

        migrationBuilder.CreateTable(
            name: "zhr_company_offices",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                country = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                city = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                phone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                is_head_office = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_company_offices", x => x.id);
            });

        migrationBuilder.CreateTable(
            name: "zhr_company_localization",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                time_zone = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                currency_id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                date_format = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                number_format = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                first_day_of_week = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                year_start_month = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                year_start_day = table.Column<int>(type: "integer", nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_company_localization", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_company_profile_tenant_id_org_id",
            schema: "zeloshr",
            table: "zhr_company_profile",
            columns: new[] { "tenant_id", "org_id" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_company_offices_tenant_id_org_id",
            schema: "zeloshr",
            table: "zhr_company_offices",
            columns: new[] { "tenant_id", "org_id" });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_company_offices_tenant_id_org_id_name",
            schema: "zeloshr",
            table: "zhr_company_offices",
            columns: new[] { "tenant_id", "org_id", "name" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_company_localization_tenant_id_org_id",
            schema: "zeloshr",
            table: "zhr_company_localization",
            columns: new[] { "tenant_id", "org_id" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "zhr_company_localization",
            schema: "zeloshr");

        migrationBuilder.DropTable(
            name: "zhr_company_offices",
            schema: "zeloshr");

        migrationBuilder.DropTable(
            name: "zhr_company_profile",
            schema: "zeloshr");
    }
}
