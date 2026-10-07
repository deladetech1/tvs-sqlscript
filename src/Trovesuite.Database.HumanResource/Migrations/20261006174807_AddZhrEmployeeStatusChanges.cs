using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrEmployeeStatusChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "zhr_employee_status_changes",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    from_status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    to_status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    effective_date = table.Column<DateOnly>(type: "date", nullable: false),
                    reason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    source = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    changed_by = table.Column<string>(type: "text", nullable: true),
                    changed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_status_changes", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_status_changes_employee_id",
                schema: "zeloshr",
                table: "zhr_employee_status_changes",
                column: "employee_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_status_changes_tenant_id_org_id_changed_at",
                schema: "zeloshr",
                table: "zhr_employee_status_changes",
                columns: new[] { "tenant_id", "org_id", "changed_at" });

            // Everyone already on record starts with the status they have now, dated when the record was made.
            migrationBuilder.Sql(@"
INSERT INTO zeloshr.zhr_employee_status_changes
    (id, tenant_id, org_id, employee_id, from_status, to_status, effective_date, reason, source, changed_by, changed_at)
SELECT gen_random_uuid(), e.tenant_id, e.org_id, e.id, NULL, e.employment_status,
       COALESCE(e.start_date, e.created_at::date), 'On record when status history began', 'registration', e.created_by, e.created_at
FROM zeloshr.zhr_employees e
WHERE e.employment_status IS NOT NULL AND NOT e.is_deleted;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_employee_status_changes",
                schema: "zeloshr");
        }
    }
}
