using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrBranchCoreLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "core_loc_id",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_branches_tenant_id_org_id_core_loc_id",
                schema: "zeloshr",
                table: "zhr_branches",
                columns: new[] { "tenant_id", "org_id", "core_loc_id" },
                unique: true,
                filter: "core_loc_id IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_branches_tenant_id_org_id_core_loc_id",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "core_loc_id",
                schema: "zeloshr",
                table: "zhr_branches");
        }
    }
}
