using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddStockTakes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_stock_takes",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    location_type = table.Column<string>(type: "text", nullable: false),
                    stock_take_number = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "DRAFT"),
                    description = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    completed_datetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    completed_by = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_stock_takes", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_stock_takes_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_stock_takes_location_type", "location_type IN ('STORE','WAREHOUSE')");
                    table.CheckConstraint("ck_msg_stock_takes_status", "status IN ('DRAFT','COMPLETED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_users_completed_by_tenant_id",
                        columns: x => new { x.completed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_takes_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_stock_take_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    stock_take_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    counted_qty = table.Column<int>(type: "integer", nullable: false),
                    system_qty = table.Column<int>(type: "integer", nullable: false),
                    variance_qty = table.Column<int>(type: "integer", nullable: false),
                    match_status = table.Column<string>(type: "text", nullable: false, defaultValue: "MATCH"),
                    resolution_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    note = table.Column<string>(type: "text", nullable: true),
                    resolution_note = table.Column<string>(type: "text", nullable: true),
                    adjustment_qty = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    adjustment_movement_id = table.Column<string>(type: "text", nullable: true),
                    resolved_by = table.Column<string>(type: "text", nullable: true),
                    resolved_datetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_stock_take_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_stock_take_items_match_status", "match_status IN ('MATCH','OVER','SHORT')");
                    table.CheckConstraint("ck_msg_stock_take_items_resolution_status", "resolution_status IN ('PENDING','INVESTIGATING','RESOLVED')");
                    table.ForeignKey(
                        name: "fk_msg_stock_take_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_stock_take_items_cp_users_resolved_by_tenant_id",
                        columns: x => new { x.resolved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_take_items_msg_products_tenant_id_org_id_bus_id_p",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_take_items_msg_stock_takes_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.stock_take_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_stock_takes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_take_items_resolved_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                columns: new[] { "resolved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_take_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_take_items_tenant_id_org_id_bus_id_stock_take_id_",
                schema: "mystoreguard",
                table: "msg_stock_take_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "stock_take_id", "product_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_completed_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "completed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_tenant_id_org_id_bus_id_loc_id_stock_take_n",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "stock_take_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_takes_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_takes",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_stock_take_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_stock_takes",
                schema: "mystoreguard");
        }
    }
}
