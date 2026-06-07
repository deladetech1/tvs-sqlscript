using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceZhrBranchLocationAndAddDepartmentDescription : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "address",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "country",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "description",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_branches
                SET address = TRIM(BOTH FROM CONCAT_WS(', ', region, city))
                WHERE (city IS NOT NULL OR region IS NOT NULL);
                """);

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

            migrationBuilder.AddColumn<string>(
                name: "description",
                schema: "zeloshr",
                table: "zhr_departments",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "description",
                schema: "zeloshr",
                table: "zhr_departments");

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

            migrationBuilder.DropColumn(
                name: "address",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "country",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "description",
                schema: "zeloshr",
                table: "zhr_branches");
        }
    }
}
