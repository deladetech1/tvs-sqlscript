using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrPayrollSettingsComponentsLoans : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "zhr_employee_loans",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    principal = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    installment = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    start_period = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_loans", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pay_component_assignments",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    component_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    value = table.Column<decimal>(type: "numeric(14,3)", precision: 14, scale: 3, nullable: true),
                    from_period = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: true),
                    to_period = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pay_component_assignments", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pay_components",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    calculation = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    value = table.Column<decimal>(type: "numeric(14,3)", precision: 14, scale: 3, nullable: false),
                    taxable = table.Column<bool>(type: "boolean", nullable: false),
                    pre_tax = table.Column<bool>(type: "boolean", nullable: false),
                    applies_to = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pay_components", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_payroll_settings",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    deduct_social_security = table.Column<bool>(type: "boolean", nullable: false),
                    employee_social_security_percent = table.Column<decimal>(type: "numeric(6,3)", precision: 6, scale: 3, nullable: true),
                    employer_social_security_percent = table.Column<decimal>(type: "numeric(6,3)", precision: 6, scale: 3, nullable: true),
                    deduct_income_tax = table.Column<bool>(type: "boolean", nullable: false),
                    prorate_new_starters = table.Column<bool>(type: "boolean", nullable: false),
                    use_record_salary = table.Column<bool>(type: "boolean", nullable: false),
                    pay_day = table.Column<int>(type: "integer", nullable: true),
                    cut_off_day = table.Column<int>(type: "integer", nullable: true),
                    overtime_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    overtime_rate = table.Column<decimal>(type: "numeric(6,3)", precision: 6, scale: 3, nullable: false),
                    overtime_rest_day_rate = table.Column<decimal>(type: "numeric(6,3)", precision: 6, scale: 3, nullable: false),
                    standard_daily_hours = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false),
                    standard_monthly_hours = table.Column<decimal>(type: "numeric(8,2)", precision: 8, scale: 2, nullable: false),
                    overtime_taxable = table.Column<bool>(type: "boolean", nullable: false),
                    min_net_percent_of_gross = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payroll_settings", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_loans_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_employee_loans",
                columns: new[] { "tenant_id", "org_id", "employee_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_component_assignments_tenant_id_org_id_component_id",
                schema: "zeloshr",
                table: "zhr_pay_component_assignments",
                columns: new[] { "tenant_id", "org_id", "component_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_component_assignments_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_pay_component_assignments",
                columns: new[] { "tenant_id", "org_id", "employee_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_components_tenant_id_org_id_kind",
                schema: "zeloshr",
                table: "zhr_pay_components",
                columns: new[] { "tenant_id", "org_id", "kind" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_settings_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                columns: new[] { "tenant_id", "org_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_employee_loans",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_pay_component_assignments",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_pay_components",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_payroll_settings",
                schema: "zeloshr");
        }
    }
}
