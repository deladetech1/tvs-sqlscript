using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentRefundTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "allow_payment_before_approval",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "refund_reminder_enabled",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<int>(
                name: "refund_reminder_interval_minutes",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "integer",
                nullable: false,
                defaultValue: 1440);

            migrationBuilder.AddColumn<int>(
                name: "refund_reminder_max_count",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "refund_amount",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "refund_closed_at",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "refund_closed_by",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "refund_note",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "refund_reminded_at",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "refund_reminder_count",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "refund_status",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                type: "text",
                nullable: false,
                defaultValue: "NONE");

            migrationBuilder.CreateTable(
                name: "msg_installment_policy_refund_closers",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    user_id = table.Column<string>(type: "text", nullable: false),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_policy_refund_closers", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_cp_businesses_bus_id_",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_cp_organizations_org_",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_cp_users_created_by_t",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_cp_users_user_id_tena",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_refund_closers_msg_installment_polic",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_early_payment",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "allow_payment_before_approval = false OR approval_required = true");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_refund_interval",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "refund_reminder_enabled = false OR refund_reminder_interval_minutes > 0");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_plans_refund_amount",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                sql: "refund_status = 'NONE' OR refund_amount > 0");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_plans_refund_closed",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                sql: "refund_status <> 'RETURNED' OR (refund_closed_at IS NOT NULL AND refund_closed_by IS NOT NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_plans_refund_status",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                sql: "refund_status IN ('NONE','PENDING','RETURNED')");

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_refund_closers_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_refund_closers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_refund_closers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_refund_closers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_refund_closers_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_refund_closers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_refund_closers_tenant_id_org_id_bus_",
                schema: "mystoreguard",
                table: "msg_installment_policy_refund_closers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_refund_closers_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_refund_closers",
                columns: new[] { "user_id", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_installment_policy_refund_closers",
                schema: "mystoreguard");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_early_payment",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_refund_interval",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_plans_refund_amount",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_plans_refund_closed",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_plans_refund_status",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "allow_payment_before_approval",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "refund_reminder_enabled",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "refund_reminder_interval_minutes",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "refund_reminder_max_count",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "refund_amount",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_closed_at",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_closed_by",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_note",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_reminded_at",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_reminder_count",
                schema: "mystoreguard",
                table: "msg_installment_plans");

            migrationBuilder.DropColumn(
                name: "refund_status",
                schema: "mystoreguard",
                table: "msg_installment_plans");
        }
    }
}
