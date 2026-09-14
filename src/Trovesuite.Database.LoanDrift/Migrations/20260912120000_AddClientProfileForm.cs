using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations;

public partial class AddClientProfileForm : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Also applied by the shared SQL runner; safe whichever deploy path runs first.
        migrationBuilder.Sql("""
            ALTER TABLE loandrift.ld_clients ADD COLUMN IF NOT EXISTS profile_photo_path text;
            ALTER TABLE loandrift.ld_client_documents_paths
                ALTER COLUMN client_id DROP NOT NULL,
                ALTER COLUMN loan_id DROP NOT NULL;
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Restoring NOT NULL will fail if staged/client-only documents remain;
        // leave the data intact for an operator to resolve before rolling back.
        migrationBuilder.Sql("""
            ALTER TABLE loandrift.ld_client_documents_paths
                ALTER COLUMN client_id SET NOT NULL,
                ALTER COLUMN loan_id SET NOT NULL;
            ALTER TABLE loandrift.ld_clients DROP COLUMN IF EXISTS profile_photo_path;
            """);
    }
}
