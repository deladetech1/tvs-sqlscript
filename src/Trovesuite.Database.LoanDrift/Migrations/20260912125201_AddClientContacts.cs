using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddClientContacts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Shared SQL deploys may have already added the column.
            migrationBuilder.Sql("""
                ALTER TABLE loandrift.ld_clients
                    ADD COLUMN IF NOT EXISTS contacts text[] NOT NULL DEFAULT ARRAY[]::text[];
                UPDATE loandrift.ld_clients SET contacts = ARRAY[contact]
                WHERE cardinality(contacts) = 0 AND NULLIF(btrim(contact), '') IS NOT NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "contacts",
                schema: "loandrift",
                table: "ld_clients");
        }
    }
}
