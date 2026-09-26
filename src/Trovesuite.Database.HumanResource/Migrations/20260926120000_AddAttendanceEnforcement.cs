using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddAttendanceEnforcement : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_attendance_enforcement",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                require_office_network = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                track_location = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_attendance_enforcement", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_attendance_enforcement_tenant_id_org_id",
            schema: "zeloshr",
            table: "zhr_attendance_enforcement",
            columns: new[] { "tenant_id", "org_id" },
            unique: true);

        migrationBuilder.CreateTable(
            name: "zhr_office_locations",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                label = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                latitude = table.Column<double>(type: "double precision", nullable: false),
                longitude = table.Column<double>(type: "double precision", nullable: false),
                radius_meters = table.Column<int>(type: "integer", nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_office_locations", x => x.id);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_office_locations_tenant_id_org_id_label",
            schema: "zeloshr",
            table: "zhr_office_locations",
            columns: new[] { "tenant_id", "org_id", "label" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "zhr_office_locations", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_attendance_enforcement", schema: "zeloshr");
    }
}
