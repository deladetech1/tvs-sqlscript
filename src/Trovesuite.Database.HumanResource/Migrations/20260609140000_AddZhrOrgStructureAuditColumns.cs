using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260609140000_AddZhrOrgStructureAuditColumns")]
    public partial class AddZhrOrgStructureAuditColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_departments",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_departments",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_departments");

            migrationBuilder.DropColumn(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_departments");

            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_branches");
        }
    }
}
