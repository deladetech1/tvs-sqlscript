using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrEmployeeChangeRequests : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "zhr_employee_change_requests",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                field_path = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                old_value_json = table.Column<string>(type: "jsonb", nullable: true),
                new_value_json = table.Column<string>(type: "jsonb", nullable: false),
                status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                requested_by = table.Column<string>(type: "text", nullable: false),
                reviewed_by = table.Column<string>(type: "text", nullable: true),
                review_note = table.Column<string>(type: "text", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                created_by = table.Column<string>(type: "text", nullable: true),
                updated_by = table.Column<string>(type: "text", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_change_requests", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_change_requests_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_change_requests_employee_id_field_path_status",
            schema: "zeloshr",
            table: "zhr_employee_change_requests",
            columns: new[] { "employee_id", "field_path", "status" },
            filter: "status = 'pending'");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_change_requests_tenant_id_org_id_employee_id_status",
            schema: "zeloshr",
            table: "zhr_employee_change_requests",
            columns: new[] { "tenant_id", "org_id", "employee_id", "status" });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_change_requests_tenant_id_org_id_status_created_at",
            schema: "zeloshr",
            table: "zhr_employee_change_requests",
            columns: new[] { "tenant_id", "org_id", "status", "created_at" });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "zhr_employee_change_requests",
            schema: "zeloshr");
    }
}
