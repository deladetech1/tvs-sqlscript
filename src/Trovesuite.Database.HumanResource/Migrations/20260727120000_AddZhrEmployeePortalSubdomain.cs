using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrEmployeePortalSubdomain : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_employee_portal_subdomain",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                bus_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                loc_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                subdomain = table.Column<string>(type: "character varying(63)", maxLength: 63, nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
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

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "zhr_employee_portal_subdomain",
            schema: "zeloshr");
    }
}
