using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <summary>
    /// Pay: compensation versions, payroll runs and their lines. Offboarding: a kind on
    /// onboarding tasks so the same checklist serves both ends of employment.
    /// Hand-trimmed to these changes only; the model snapshot was regenerated alongside.
    /// </summary>
    public partial class AddZhrPayrollAndOffboarding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "kind",
                schema: "zeloshr",
                table: "zhr_onboarding_tasks",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "onboarding");

            migrationBuilder.CreateTable(
                name: "zhr_compensation_versions",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    version_number = table.Column<int>(type: "integer", nullable: false),
                    effective_from = table.Column<DateOnly>(type: "date", nullable: false),
                    base_amount = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    components_json = table.Column<string>(type: "jsonb", nullable: false),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    pay_frequency = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    supersedes_version_id = table.Column<Guid>(type: "uuid", nullable: true),
                    proposed_by = table.Column<string>(type: "text", nullable: false),
                    proposed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    decided_by = table.Column<string>(type: "text", nullable: true),
                    decided_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    decision_note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_compensation_versions", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_payroll_runs",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    period = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: false),
                    period_start = table.Column<DateOnly>(type: "date", nullable: false),
                    period_end = table.Column<DateOnly>(type: "date", nullable: false),
                    pay_date = table.Column<DateOnly>(type: "date", nullable: false),
                    kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    rule_pack_version = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    employee_count = table.Column<int>(type: "integer", nullable: false),
                    total_gross = table.Column<decimal>(type: "numeric(16,2)", precision: 16, scale: 2, nullable: false),
                    total_deductions = table.Column<decimal>(type: "numeric(16,2)", precision: 16, scale: 2, nullable: false),
                    total_employer_cost = table.Column<decimal>(type: "numeric(16,2)", precision: 16, scale: 2, nullable: false),
                    total_net = table.Column<decimal>(type: "numeric(16,2)", precision: 16, scale: 2, nullable: false),
                    prepared_by = table.Column<string>(type: "text", nullable: true),
                    submitted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    approved_by = table.Column<string>(type: "text", nullable: true),
                    approved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    events_json = table.Column<string>(type: "jsonb", nullable: false),
                    acknowledgements_json = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payroll_runs", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_payroll_lines",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    run_id = table.Column<Guid>(type: "uuid", nullable: false),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    employee_code = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    department_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    compensation_version_id = table.Column<Guid>(type: "uuid", nullable: true),
                    earnings_json = table.Column<string>(type: "jsonb", nullable: false),
                    deductions_json = table.Column<string>(type: "jsonb", nullable: false),
                    employer_contributions_json = table.Column<string>(type: "jsonb", nullable: false),
                    gross = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    total_deductions = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    total_employer_contributions = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    net = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    previous_net = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: true),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    payment_channel = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    payment_destination_masked = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    flags_json = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_payroll_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_payroll_lines_zhr_payroll_runs_run_id",
                        column: x => x.run_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_payroll_runs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_compensation_versions_tenant_id_org_id_employee_id_vers",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                columns: new[] { "tenant_id", "org_id", "employee_id", "version_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_compensation_versions_tenant_id_org_id_status",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                columns: new[] { "tenant_id", "org_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_lines_run_id_employee_id",
                schema: "zeloshr",
                table: "zhr_payroll_lines",
                columns: new[] { "run_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_lines_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_payroll_lines",
                columns: new[] { "tenant_id", "org_id", "employee_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_payroll_runs_tenant_id_org_id_period",
                schema: "zeloshr",
                table: "zhr_payroll_runs",
                columns: new[] { "tenant_id", "org_id", "period" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "zhr_payroll_lines", schema: "zeloshr");
            migrationBuilder.DropTable(name: "zhr_payroll_runs", schema: "zeloshr");
            migrationBuilder.DropTable(name: "zhr_compensation_versions", schema: "zeloshr");
            migrationBuilder.DropColumn(name: "kind", schema: "zeloshr", table: "zhr_onboarding_tasks");
        }
    }
}
