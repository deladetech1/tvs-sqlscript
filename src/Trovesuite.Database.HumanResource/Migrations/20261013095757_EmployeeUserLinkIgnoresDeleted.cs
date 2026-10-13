using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class EmployeeUserLinkIgnoresDeleted : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_tenant_id_user_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_user_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "user_id" },
                unique: true,
                filter: "user_id IS NOT NULL AND NOT is_deleted");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_tenant_id_user_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_user_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "user_id" },
                unique: true,
                filter: "user_id IS NOT NULL");
        }
    }
}
