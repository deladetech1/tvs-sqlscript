using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddLoanPenaltyPeriod : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "penalty_period",
                schema: "loandrift",
                table: "ld_loan_types",
                type: "text",
                nullable: false,
                defaultValue: "DAILY");

            migrationBuilder.AddColumn<string>(
                name: "penalty_period",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "text",
                nullable: false,
                defaultValue: "DAILY");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_loan_types_penalty_period",
                schema: "loandrift",
                table: "ld_loan_types",
                sql: "penalty_period IN ('DAILY','WEEKLY','MONTHLY')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_loan_details_penalty_period",
                schema: "loandrift",
                table: "ld_loan_details",
                sql: "penalty_period IN ('DAILY','WEEKLY','MONTHLY')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_loan_types_penalty_period",
                schema: "loandrift",
                table: "ld_loan_types");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_loan_details_penalty_period",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "penalty_period",
                schema: "loandrift",
                table: "ld_loan_types");

            migrationBuilder.DropColumn(
                name: "penalty_period",
                schema: "loandrift",
                table: "ld_loan_details");
        }
    }
}
