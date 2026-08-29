using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddPolicyAmountEditRules : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "allow_initial_payment_edit",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "allow_installment_amount_edit",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "boolean",
                nullable: false,
                defaultValue: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "allow_initial_payment_edit",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "allow_installment_amount_edit",
                schema: "mystoreguard",
                table: "msg_installment_policies");
        }
    }
}
