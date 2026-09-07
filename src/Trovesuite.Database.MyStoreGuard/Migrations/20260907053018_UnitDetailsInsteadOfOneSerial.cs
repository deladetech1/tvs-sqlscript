using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class UnitDetailsInsteadOfOneSerial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_msg_product_units_tenant_id_org_id_bus_id_serial_number",
                schema: "mystoreguard",
                table: "msg_product_units");

            migrationBuilder.DropColumn(
                name: "serial_number",
                schema: "mystoreguard",
                table: "msg_product_units");

            migrationBuilder.CreateTable(
                name: "msg_product_unit_identifiers",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    unit_id = table.Column<string>(type: "text", nullable: false),
                    label = table.Column<string>(type: "text", nullable: false, defaultValue: "Serial number"),
                    value = table.Column<string>(type: "text", nullable: false),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_unit_identifiers", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_cp_organizations_org_id_tenant",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_unit_identifiers_msg_product_units_tenant_id_or",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.unit_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_product_units",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_tenant_id_org_id_bus_id_unit_id",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "unit_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_tenant_id_org_id_bus_id_value",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "value" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_unit_identifiers_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_unit_identifiers",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_product_unit_identifiers",
                schema: "mystoreguard");

            migrationBuilder.AddColumn<string>(
                name: "serial_number",
                schema: "mystoreguard",
                table: "msg_product_units",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_tenant_id_org_id_bus_id_serial_number",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "tenant_id", "org_id", "bus_id", "serial_number" },
                unique: true);
        }
    }
}
