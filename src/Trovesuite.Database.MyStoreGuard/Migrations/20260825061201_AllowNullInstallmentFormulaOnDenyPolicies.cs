using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AllowNullInstallmentFormulaOnDenyPolicies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "installment_formula",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            // Deny policies written before the column was nullable hold the
            // string "0", because it was NOT NULL and a deny has no formula to
            // put there. Clear them, or every read of those rows carries a
            // sentinel that looks like a real formula.
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_installment_policies " +
                "SET installment_formula = NULL " +
                "WHERE policy_mode = 'DENY' AND installment_formula = '0';");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_allow_formula",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "policy_mode <> 'ALLOW' OR installment_formula IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_allow_formula",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.AlterColumn<string>(
                name: "installment_formula",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);
        }
    }
}
