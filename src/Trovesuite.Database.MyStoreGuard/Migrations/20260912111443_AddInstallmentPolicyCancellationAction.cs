using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentPolicyCancellationAction : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "cancellation_action",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "text",
                nullable: false,
                defaultValue: "PREVENT");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_cancellation_action",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "cancellation_action IN ('PREVENT','RESTOCK','RELEASE_ONLY')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_cancellation_action",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "cancellation_action",
                schema: "mystoreguard",
                table: "msg_installment_policies");
        }
    }
}
