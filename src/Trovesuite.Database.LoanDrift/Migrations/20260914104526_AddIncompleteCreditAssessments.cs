using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddIncompleteCreditAssessments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_credit_scores_band",
                schema: "loandrift",
                table: "ld_credit_scores");

            migrationBuilder.AlterColumn<int>(
                name: "total_score",
                schema: "loandrift",
                table: "ld_credit_scores",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_credit_scores_band",
                schema: "loandrift",
                table: "ld_credit_scores",
                sql: "band IN ('EXCELLENT','GOOD','FAIR','POOR','VERY_POOR','INCOMPLETE')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DO $$ BEGIN IF EXISTS (SELECT 1 FROM loandrift.ld_credit_scores WHERE total_score IS NULL OR band = 'INCOMPLETE') THEN RAISE EXCEPTION 'Resolve incomplete assessments before reverting this migration'; END IF; END $$;");
            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_credit_scores_band",
                schema: "loandrift",
                table: "ld_credit_scores");

            migrationBuilder.AlterColumn<int>(
                name: "total_score",
                schema: "loandrift",
                table: "ld_credit_scores",
                type: "integer",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_credit_scores_band",
                schema: "loandrift",
                table: "ld_credit_scores",
                sql: "band IN ('EXCELLENT','GOOD','FAIR','POOR','VERY_POOR')");
        }
    }
}
