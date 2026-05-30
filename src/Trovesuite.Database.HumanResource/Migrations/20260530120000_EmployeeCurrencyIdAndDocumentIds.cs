using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class EmployeeCurrencyIdAndDocumentIds : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "currency_id",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "document_ids",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "jsonb",
                nullable: false,
                defaultValue: "[]");

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_employees e
                SET currency_id = c.id
                FROM core_platform.cp_currencies c
                WHERE c.tenant_id = e.tenant_id
                  AND UPPER(c.code) = UPPER(e.currency)
                  AND c.delete_status = 'NOT_DELETED';
                """);

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_employees e
                SET currency_id = c.id
                FROM core_platform.cp_currencies c
                WHERE e.currency_id IS NULL
                  AND c.tenant_id = e.tenant_id
                  AND c.is_default = true
                  AND c.delete_status = 'NOT_DELETED';
                """);

            migrationBuilder.DropColumn(
                name: "currency",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_currency_id_tenant_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_zhr_employees_cp_currencies_currency_id_tenant_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "currency_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_currencies",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_zhr_employees_cp_currencies_currency_id_tenant_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_currency_id_tenant_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "document_ids",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "currency_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.AddColumn<string>(
                name: "currency",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "character varying(8)",
                maxLength: 8,
                nullable: false,
                defaultValue: "GHS");
        }
    }
}
