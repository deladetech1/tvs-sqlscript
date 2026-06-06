using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class ScopeZhrEmployeeCodeUniqueByTenant : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_employee_code",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_employee_code",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "employee_code" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_tenant_id_employee_code",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_employee_code",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "employee_code",
                unique: true);
        }
    }
}
