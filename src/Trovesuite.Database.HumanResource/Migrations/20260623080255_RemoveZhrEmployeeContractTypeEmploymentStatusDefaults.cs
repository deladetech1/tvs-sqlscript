using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class RemoveZhrEmployeeContractTypeEmploymentStatusDefaults : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "employment_status",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "text",
                nullable: true,
                defaultValue: "Active",
                oldClrType: typeof(string),
                oldType: "text",
                oldDefaultValue: "Active");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "employment_status",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "text",
                nullable: false,
                defaultValue: "Active",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true,
                oldDefaultValue: "Active");
        }
    }
}
