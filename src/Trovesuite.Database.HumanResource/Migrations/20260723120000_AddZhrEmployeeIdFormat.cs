using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrEmployeeIdFormat : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_employee_id_format",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                prefix = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                digit_count = table.Column<int>(type: "integer", nullable: false),
                starting_number = table.Column<int>(type: "integer", nullable: false),
                separator = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                auto_generate = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_id_format", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_id_format_tenant_id_org_id",
            schema: "zeloshr",
            table: "zhr_employee_id_format",
            columns: new[] { "tenant_id", "org_id" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "zhr_employee_id_format",
            schema: "zeloshr");
    }
}
