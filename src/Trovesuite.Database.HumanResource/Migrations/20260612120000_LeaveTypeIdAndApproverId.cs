using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class LeaveTypeIdAndApproverId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE zeloshr.zhr_leave_requests r
                SET leave_type_id = t.id
                FROM zeloshr.zhr_leave_types t
                WHERE r.leave_type = t.name
                  AND r.tenant_id = t.tenant_id
                  AND r.org_id = t.org_id
                  AND r.leave_type_id IS NULL;
                """);

            migrationBuilder.Sql(
                """
                UPDATE zeloshr.zhr_leave_balances b
                SET leave_type_id = t.id
                FROM zeloshr.zhr_leave_types t
                WHERE b.leave_type = t.name
                  AND b.tenant_id = t.tenant_id
                  AND b.org_id = t.org_id
                  AND b.leave_type_id IS NULL;
                """);

            migrationBuilder.DropIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type",
                schema: "zeloshr",
                table: "zhr_leave_balances");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                columns: new[] { "tenant_id", "org_id", "employee_id", "leave_type_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_balances");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                columns: new[] { "tenant_id", "org_id", "employee_id", "leave_type" },
                unique: true);

            migrationBuilder.DropColumn(
                name: "approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_balances");

            migrationBuilder.DropColumn(
                name: "leave_type_id",
                schema: "zeloshr",
                table: "zhr_leave_requests");
        }
    }
}
