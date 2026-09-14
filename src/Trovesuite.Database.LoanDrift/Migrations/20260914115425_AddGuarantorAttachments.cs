using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddGuarantorAttachments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string[]>(
                name: "document_ids",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text[]",
                nullable: false,
                defaultValueSql: "ARRAY[]::text[]");

            migrationBuilder.AddColumn<string>(
                name: "profile_photo_path",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "document_ids",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropColumn(
                name: "profile_photo_path",
                schema: "loandrift",
                table: "ld_guarantors");
        }
    }
}
