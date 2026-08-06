using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class SplitZhrEmployeeCodeSystemAndCustom : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "employee_code_system",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(32)",
            maxLength: 32,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "employee_code_custom",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(32)",
            maxLength: 32,
            nullable: true);

        migrationBuilder.Sql(
            """
            UPDATE zeloshr.zhr_employees
            SET employee_code_system = employee_code
            WHERE employee_code_system IS NULL;
            """);

        migrationBuilder.AlterColumn<string>(
            name: "employee_code_system",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(32)",
            maxLength: 32,
            nullable: false,
            oldClrType: typeof(string),
            oldType: "character varying(32)",
            oldMaxLength: 32,
            oldNullable: true);

        migrationBuilder.DropIndex(
            name: "ix_zhr_employees_tenant_id_employee_code",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropColumn(
            name: "employee_code",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_employee_code_system",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "employee_code_system" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_employee_code_custom",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "employee_code_custom" },
            unique: true,
            filter: "employee_code_custom IS NOT NULL AND employee_code_custom <> ''");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "employee_code",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(32)",
            maxLength: 32,
            nullable: true);

        migrationBuilder.Sql(
            """
            UPDATE zeloshr.zhr_employees
            SET employee_code = COALESCE(NULLIF(employee_code_custom, ''), employee_code_system);
            """);

        migrationBuilder.AlterColumn<string>(
            name: "employee_code",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(32)",
            maxLength: 32,
            nullable: false,
            oldClrType: typeof(string),
            oldType: "character varying(32)",
            oldMaxLength: 32,
            oldNullable: true);

        migrationBuilder.DropIndex(
            name: "ix_zhr_employees_tenant_id_employee_code_custom",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropIndex(
            name: "ix_zhr_employees_tenant_id_employee_code_system",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropColumn(
            name: "employee_code_custom",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropColumn(
            name: "employee_code_system",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_employee_code",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "employee_code" },
            unique: true);
    }
}
