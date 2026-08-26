using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddPolicyProductScope : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "text",
                nullable: false,
                defaultValue: "ALL");

            migrationBuilder.CreateTable(
                name: "msg_installment_policy_products",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_policy_products", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_products_cp_businesses_bus_id_tenant",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_products_cp_organizations_org_id_ten",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_products_msg_installment_policies_te",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_products_products_tenant_id_org_id_b",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "product_scope IN ('ALL','INCLUDE','EXCLUDE')");

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_products_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_products_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_products_tenant_id_org_id_bus_id_pol",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "product_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_products_tenant_id_org_id_bus_id_pro",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_installment_policy_products",
                schema: "mystoreguard");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies");
        }
    }
}
