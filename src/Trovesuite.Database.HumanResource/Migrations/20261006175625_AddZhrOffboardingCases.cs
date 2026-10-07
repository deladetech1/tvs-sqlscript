using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrOffboardingCases : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "zhr_offboarding_cases",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    reference = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    lifecycle_event_id = table.Column<Guid>(type: "uuid", nullable: true),
                    reason = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    notice_given_on = table.Column<DateOnly>(type: "date", nullable: false),
                    last_working_day = table.Column<DateOnly>(type: "date", nullable: false),
                    notice_period_days = table.Column<int>(type: "integer", nullable: false),
                    state = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    assets_returned = table.Column<bool>(type: "boolean", nullable: false),
                    access_revoked = table.Column<bool>(type: "boolean", nullable: false),
                    settlement_calculated = table.Column<bool>(type: "boolean", nullable: false),
                    handover_done = table.Column<bool>(type: "boolean", nullable: false),
                    exit_interview_done = table.Column<bool>(type: "boolean", nullable: false),
                    accrued_leave_days = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    final_settlement = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: true),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    sent_to_payroll_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    closed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_offboarding_cases", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_offboarding_cases_employee_id",
                schema: "zeloshr",
                table: "zhr_offboarding_cases",
                column: "employee_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_offboarding_cases_lifecycle_event_id",
                schema: "zeloshr",
                table: "zhr_offboarding_cases",
                column: "lifecycle_event_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_offboarding_cases_tenant_id_org_id_reference",
                schema: "zeloshr",
                table: "zhr_offboarding_cases",
                columns: new[] { "tenant_id", "org_id", "reference" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_offboarding_cases",
                schema: "zeloshr");
        }
    }
}
