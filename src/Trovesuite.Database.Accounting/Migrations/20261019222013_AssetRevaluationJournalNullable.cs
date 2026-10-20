using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AssetRevaluationJournalNullable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "journal_id",
                schema: "accounting",
                table: "acc_asset_revaluations",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            // Revaluations with nothing to post were stored with an empty journal id; they have no journal.
            migrationBuilder.Sql("UPDATE accounting.acc_asset_revaluations SET journal_id = NULL WHERE journal_id = '';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("UPDATE accounting.acc_asset_revaluations SET journal_id = '' WHERE journal_id IS NULL;");

            migrationBuilder.AlterColumn<string>(
                name: "journal_id",
                schema: "accounting",
                table: "acc_asset_revaluations",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);
        }
    }
}
