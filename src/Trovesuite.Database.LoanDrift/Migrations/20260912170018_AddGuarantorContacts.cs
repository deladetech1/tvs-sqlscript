using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddGuarantorContacts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                -- Keep all guarantor contacts; contact remains the primary number.
                ALTER TABLE loandrift.ld_guarantors
                    ADD COLUMN IF NOT EXISTS contacts text[] NOT NULL DEFAULT ARRAY[]::text[];
                UPDATE loandrift.ld_guarantors SET contacts = ARRAY[contact]
                WHERE cardinality(contacts) = 0 AND NULLIF(btrim(contact), '') IS NOT NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "contacts",
                schema: "loandrift",
                table: "ld_guarantors");
        }
    }
}
