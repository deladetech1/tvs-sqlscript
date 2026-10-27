using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddColoredSidebar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Raw SQL with IF NOT EXISTS so a database that already has the
            // column (a re-run, or one patched by hand) is left alone. Defaulted
            // true: the coloured sidebar is the live look, so every existing row
            // keeps it and no reader has to treat null as a third case.
            migrationBuilder.Sql(
                "ALTER TABLE core_platform.cp_themes " +
                "ADD COLUMN IF NOT EXISTS colored_sidebar boolean NOT NULL DEFAULT true;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "ALTER TABLE core_platform.cp_themes DROP COLUMN IF EXISTS colored_sidebar;");
        }
    }
}
