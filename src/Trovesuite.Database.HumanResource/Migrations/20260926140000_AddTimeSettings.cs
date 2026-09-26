using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddTimeSettings : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_time_settings",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                payload = table.Column<string>(type: "jsonb", nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_time_settings", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_time_settings_tenant_id_org_id_key",
            schema: "zeloshr",
            table: "zhr_time_settings",
            columns: new[] { "tenant_id", "org_id", "key" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "zhr_time_settings", schema: "zeloshr");
    }
}
