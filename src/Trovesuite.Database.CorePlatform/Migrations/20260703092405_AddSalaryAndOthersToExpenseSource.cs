using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddSalaryAndOthersToExpenseSource : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_expenses_history_source",
                schema: "core_platform",
                table: "cp_expenses_history");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_expenses_history_source",
                schema: "core_platform",
                table: "cp_expenses_history",
                sql: "source IN ('ALLOCATED','CONTIGENCY','FIXED','REIMBURSABLE','SALARY','OTHERS')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_expenses_history_source",
                schema: "core_platform",
                table: "cp_expenses_history");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_expenses_history_source",
                schema: "core_platform",
                table: "cp_expenses_history",
                sql: "source IN ('ALLOCATED','CONTIGENCY','FIXED','REIMBURSABLE')");
        }
    }
}
