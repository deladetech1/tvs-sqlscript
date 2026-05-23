using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddProductTransferApprovals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_product_transfer_approvals",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    transfer_id = table.Column<string>(type: "text", nullable: false),
                    action = table.Column<string>(type: "text", nullable: false),
                    reason = table.Column<string>(type: "text", nullable: true),
                    performed_by = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_transfer_approvals", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_transfer_approvals_action", "action IN ('APPROVED','REJECTED')");
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_approvals_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_approvals_cp_users_performed_by_tenant",
                        columns: x => new { x.performed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_transfer_approvals_product_transfers_tenant_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.transfer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_product_transfers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfer_approvals_performed_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_transfer_approvals",
                columns: new[] { "performed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfer_approvals_tenant_id_org_id_bus_id_tran",
                schema: "mystoreguard",
                table: "msg_product_transfer_approvals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "transfer_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_product_transfer_approvals",
                schema: "mystoreguard");
        }
    }
}
