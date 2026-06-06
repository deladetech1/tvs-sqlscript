using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrBranchLocationFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "city",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "region",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "country_code",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(2)",
                maxLength: 2,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "city",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "region",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "country_code",
                schema: "zeloshr",
                table: "zhr_branches");
        }
    }
}
