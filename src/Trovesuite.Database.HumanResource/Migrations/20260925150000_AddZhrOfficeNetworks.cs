using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrOfficeNetworks : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_office_networks",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                label = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                notation = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                start_address = table.Column<string>(type: "character varying(45)", maxLength: 45, nullable: false),
                end_address = table.Column<string>(type: "character varying(45)", maxLength: 45, nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_office_networks", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_office_networks_tenant_id_org_id_notation",
            schema: "zeloshr",
            table: "zhr_office_networks",
            columns: new[] { "tenant_id", "org_id", "notation" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "zhr_office_networks", schema: "zeloshr");
    }
}
