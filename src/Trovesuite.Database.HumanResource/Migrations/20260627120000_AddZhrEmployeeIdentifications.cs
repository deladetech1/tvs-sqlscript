using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrEmployeeIdentifications : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_employee_identifications",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                id_card_type_id = table.Column<Guid>(type: "uuid", nullable: false),
                id_number = table.Column<string>(type: "text", nullable: false),
                id_issue_date = table.Column<DateOnly>(type: "date", nullable: true),
                id_expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_identifications", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_identifications_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "fk_zhr_employee_identifications_zhr_id_card_types_id_card_type_id",
                    column: x => x.id_card_type_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_id_card_types",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_identifications_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_identifications",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_identifications_employee_id_id_card_type_id",
            schema: "zeloshr",
            table: "zhr_employee_identifications",
            columns: new[] { "employee_id", "id_card_type_id" },
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "zhr_employee_identifications",
            schema: "zeloshr");
    }
}
