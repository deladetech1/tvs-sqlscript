using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddInkAbyssCarbonDarkSchemes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes",
                sql: "dark_scheme IN ('CHARCOAL','MIDNIGHT','OBSIDIAN','GRAPHITE','HARBOR','INK','ABYSS','CARBON')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes",
                sql: "dark_scheme IN ('CHARCOAL','MIDNIGHT','OBSIDIAN','GRAPHITE','HARBOR')");
        }
    }
}
