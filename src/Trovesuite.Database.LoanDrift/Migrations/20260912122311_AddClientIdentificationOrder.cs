using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddClientIdentificationOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The shared SQL runner can apply the same change before EF.
            migrationBuilder.Sql("""
                ALTER TABLE loandrift.ld_client_identifications
                    ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "sort_order",
                schema: "loandrift",
                table: "ld_client_identifications");
        }
    }
}
