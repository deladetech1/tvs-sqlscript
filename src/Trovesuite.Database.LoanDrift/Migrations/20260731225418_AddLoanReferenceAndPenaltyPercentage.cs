using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddLoanReferenceAndPenaltyPercentage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Feeds the ld_loan_details.loan_reference default. A single global sequence
            // guarantees the reference is unique across every loan in the system.
            migrationBuilder.Sql(
                "CREATE SEQUENCE IF NOT EXISTS loandrift.ld_loan_reference_seq AS bigint START WITH 1 INCREMENT BY 1;");

            migrationBuilder.AddColumn<decimal>(
                name: "penalty_percentage",
                schema: "loandrift",
                table: "ld_loan_types",
                type: "numeric(7,4)",
                nullable: true);

            // Add nullable, backfill every existing loan from the sequence, then lock the
            // column down. Done in explicit steps rather than relying on ADD COLUMN with a
            // volatile default, so the backfill is unambiguous before the unique index is
            // built below. New rows get their reference from the default.
            migrationBuilder.Sql(@"
                ALTER TABLE loandrift.ld_loan_details ADD COLUMN loan_reference text;

                UPDATE loandrift.ld_loan_details
                   SET loan_reference = 'LN-' || to_char(COALESCE(cdatetime, now()), 'YYYYMMDD') || '-'
                                     || lpad(nextval('loandrift.ld_loan_reference_seq')::text, 6, '0')
                 WHERE loan_reference IS NULL;

                ALTER TABLE loandrift.ld_loan_details
                    ALTER COLUMN loan_reference SET DEFAULT
                        'LN-' || to_char(now(), 'YYYYMMDD') || '-'
                              || lpad(nextval('loandrift.ld_loan_reference_seq')::text, 6, '0'),
                    ALTER COLUMN loan_reference SET NOT NULL;
            ");

            migrationBuilder.AddColumn<decimal>(
                name: "penalty_percentage",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "numeric(7,4)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_loan_reference",
                schema: "loandrift",
                table: "ld_loan_details",
                column: "loan_reference",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_ld_loan_details_loan_reference",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "penalty_percentage",
                schema: "loandrift",
                table: "ld_loan_types");

            migrationBuilder.DropColumn(
                name: "penalty_percentage",
                schema: "loandrift",
                table: "ld_loan_details");

            // The column default references the sequence, so drop it first.
            migrationBuilder.Sql(@"
                DROP TRIGGER IF EXISTS trg_ld_loan_reference ON loandrift.ld_loan_details;
                DROP FUNCTION IF EXISTS loandrift.ld_enforce_loan_reference();
                ALTER TABLE loandrift.ld_loan_details DROP COLUMN IF EXISTS loan_reference;
                DROP SEQUENCE IF EXISTS loandrift.ld_loan_reference_seq;
            ");
        }
    }
}
