using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class RenameCredentialIdToCredentialUrl : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "credential_id",
                schema: "zeloshr",
                table: "zhr_employee_certifications",
                newName: "credential_url");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "credential_url",
                schema: "zeloshr",
                table: "zhr_employee_certifications",
                newName: "credential_id");
        }
    }
}
