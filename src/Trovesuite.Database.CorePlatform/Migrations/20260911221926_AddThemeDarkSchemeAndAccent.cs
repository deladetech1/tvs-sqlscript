using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddThemeDarkSchemeAndAccent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "accent_color",
                schema: "core_platform",
                table: "cp_themes",
                type: "text",
                nullable: false,
                defaultValue: "ORANGE");

            migrationBuilder.AddColumn<string>(
                name: "dark_scheme",
                schema: "core_platform",
                table: "cp_themes",
                type: "text",
                nullable: false,
                defaultValue: "CHARCOAL");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_themes_accent_color",
                schema: "core_platform",
                table: "cp_themes",
                sql: "accent_color IN ('ORANGE','PURPLE','BLUE','GREEN')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes",
                sql: "dark_scheme IN ('CHARCOAL','MIDNIGHT','OBSIDIAN')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_themes_accent_color",
                schema: "core_platform",
                table: "cp_themes");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_themes_dark_scheme",
                schema: "core_platform",
                table: "cp_themes");

            migrationBuilder.DropColumn(
                name: "accent_color",
                schema: "core_platform",
                table: "cp_themes");

            migrationBuilder.DropColumn(
                name: "dark_scheme",
                schema: "core_platform",
                table: "cp_themes");
        }
    }
}
