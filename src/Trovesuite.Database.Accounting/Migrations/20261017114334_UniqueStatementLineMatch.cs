using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class UniqueStatementLineMatch : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Before the index: keep the earliest match per journal (by created_at, then id) and return any other
            // line matched to the same journal to UNMATCHED, so the unique index can be built.
            migrationBuilder.Sql("""
                UPDATE accounting.acc_bank_statement_lines l
                SET status = 'UNMATCHED', matched_journal_id = NULL, updated_at = now()
                FROM (
                    SELECT id, row_number() OVER (
                        PARTITION BY tenant_id, org_id, matched_journal_id ORDER BY created_at, id) AS rn
                    FROM accounting.acc_bank_statement_lines
                    WHERE matched_journal_id IS NOT NULL
                ) d
                WHERE d.id = l.id AND d.rn > 1;
                """);

            migrationBuilder.DropIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                columns: new[] { "tenant_id", "org_id", "matched_journal_id" },
                unique: true,
                filter: "matched_journal_id IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                columns: new[] { "tenant_id", "org_id", "matched_journal_id" });
        }
    }
}
