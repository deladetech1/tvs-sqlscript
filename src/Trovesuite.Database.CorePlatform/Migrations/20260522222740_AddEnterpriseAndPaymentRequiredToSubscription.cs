using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddEnterpriseAndPaymentRequiredToSubscription : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.AddColumn<bool>(
                name: "is_enterprise",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "is_payment_required",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                sql: "status IN ('TRIALING','ACTIVE','PENDING_PAYMENT','PAST_DUE','SUSPENDED','CANCELLED')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "is_enterprise",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.DropColumn(
                name: "is_payment_required",
                schema: "core_platform",
                table: "cp_app_subscriptions");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_app_subscriptions_status",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                sql: "status IN ('TRIALING','ACTIVE','PAST_DUE','SUSPENDED','CANCELLED')");
        }
    }
}
