using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddSerialisedProductTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "tracking_type",
                schema: "mystoreguard",
                table: "msg_products",
                type: "text",
                nullable: false,
                defaultValue: "COUNTED");

            migrationBuilder.CreateTable(
                name: "msg_inventory_settings",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    serialised_enabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_inventory_settings", x => new { x.tenant_id, x.org_id, x.bus_id });
                    table.ForeignKey(
                        name: "fk_msg_inventory_settings_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_inventory_settings_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_inventory_settings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_inventory_settings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_inventory_settings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_units",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: false),
                    serial_number = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "IN_STOCK"),
                    sale_id = table.Column<string>(type: "text", nullable: true),
                    sold_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_units", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_units_status", "status IN ('IN_STOCK','SOLD','RETURNED','FAULTY','WRITTEN_OFF')");
                    table.ForeignKey(
                        name: "fk_msg_product_units_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_units_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_units_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_units_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_units_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_products_tracking_type",
                schema: "mystoreguard",
                table: "msg_products",
                sql: "tracking_type IN ('COUNTED','SERIALISED')");

            migrationBuilder.CreateIndex(
                name: "ix_msg_inventory_settings_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_inventory_settings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_inventory_settings_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_inventory_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_inventory_settings_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_inventory_settings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_inventory_settings_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_inventory_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_tenant_id_org_id_bus_id_product_id_loc_id",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id", "loc_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_tenant_id_org_id_bus_id_serial_number",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "tenant_id", "org_id", "bus_id", "serial_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_units_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_units",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_inventory_settings",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_units",
                schema: "mystoreguard");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_products_tracking_type",
                schema: "mystoreguard",
                table: "msg_products");

            migrationBuilder.DropColumn(
                name: "tracking_type",
                schema: "mystoreguard",
                table: "msg_products");
        }
    }
}
