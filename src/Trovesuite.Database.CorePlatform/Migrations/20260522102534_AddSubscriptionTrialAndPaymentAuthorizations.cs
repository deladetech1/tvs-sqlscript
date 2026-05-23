using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddSubscriptionTrialAndPaymentAuthorizations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_cp_app_subscription_histories_cp_app_subscriptions_app_subs",
                schema: "core_platform",
                table: "cp_app_subscription_histories");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_billings_logs_paid_method",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_billings_logs_paid_status",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropIndex(
                name: "ix_cp_app_subscription_histories_app_subscription_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories");

            migrationBuilder.AddColumn<string>(
                name: "free_trial_consumed_app_subscription_id",
                schema: "core_platform",
                table: "cp_tenants",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "free_trial_ends_at",
                schema: "core_platform",
                table: "cp_tenants",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "free_trial_started_at",
                schema: "core_platform",
                table: "cp_tenants",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "free_trial_used",
                schema: "core_platform",
                table: "cp_tenants",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "paystack_invoice_code",
                schema: "core_platform",
                table: "cp_billings_logs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "paystack_reference",
                schema: "core_platform",
                table: "cp_billings_logs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "current_period_end",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "current_period_start",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "next_charge_date",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "status",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "text",
                nullable: false,
                defaultValue: "TRIALING");

            migrationBuilder.CreateTable(
                name: "cp_payment_authorizations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    paystack_customer_code = table.Column<string>(type: "text", nullable: true),
                    authorization_code = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    last4 = table.Column<string>(type: "text", nullable: true),
                    card_type = table.Column<string>(type: "text", nullable: true),
                    exp_month = table.Column<string>(type: "text", nullable: true),
                    exp_year = table.Column<string>(type: "text", nullable: true),
                    bank = table.Column<string>(type: "text", nullable: true),
                    signature = table.Column<string>(type: "text", nullable: true),
                    reusable = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    is_default = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_payment_authorizations", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_payment_authorizations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_payment_authorizations_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_payment_authorizations_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_payment_authorizations_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_payment_authorizations_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Tenant-level saved Paystack card reference. Holds only the reusable authorization token and non-sensitive display metadata — never the PAN or CVV.");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_billings_logs_paid_method",
                schema: "core_platform",
                table: "cp_billings_logs",
                sql: "paid_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','CARD','OTHERS',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_billings_logs_paid_status",
                schema: "core_platform",
                table: "cp_billings_logs",
                sql: "paid_status IN ('PENDING','PAID','FAILED','CANCELLED','REFUNDED','WAIVED','OTHERS',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                sql: "status IN ('TRIALING','ACTIVE','PAST_DUE','SUSPENDED','CANCELLED')");

            migrationBuilder.CreateIndex(
                name: "ix_cp_payment_authorizations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_payment_authorizations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_payment_authorizations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_payment_authorizations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_payment_authorizations_tenant_id_authorization_code",
                schema: "core_platform",
                table: "cp_payment_authorizations",
                columns: new[] { "tenant_id", "authorization_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_payment_authorizations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_payment_authorizations",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "cp_payment_authorizations",
                schema: "core_platform");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_billings_logs_paid_method",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_billings_logs_paid_status",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "free_trial_consumed_app_subscription_id",
                schema: "core_platform",
                table: "cp_tenants");

            migrationBuilder.DropColumn(
                name: "free_trial_ends_at",
                schema: "core_platform",
                table: "cp_tenants");

            migrationBuilder.DropColumn(
                name: "free_trial_started_at",
                schema: "core_platform",
                table: "cp_tenants");

            migrationBuilder.DropColumn(
                name: "free_trial_used",
                schema: "core_platform",
                table: "cp_tenants");

            migrationBuilder.DropColumn(
                name: "paystack_invoice_code",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropColumn(
                name: "paystack_reference",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropColumn(
                name: "current_period_end",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "current_period_start",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "next_charge_date",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "status",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_billings_logs_paid_method",
                schema: "core_platform",
                table: "cp_billings_logs",
                sql: "paid_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','OTHERS',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_billings_logs_paid_status",
                schema: "core_platform",
                table: "cp_billings_logs",
                sql: "paid_status IN ('PENDING','PAID','FAILED','CANCELLED','REFUNDED','OTHERS',NULL)");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_app_subscription_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "app_subscription_id", "tenant_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_cp_app_subscription_histories_cp_app_subscriptions_app_subs",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "app_subscription_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_app_subscriptions",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Cascade);
        }
    }
}
