using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class ZelosHrAppTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "zeloshr");

            migrationBuilder.CreateTable(
                name: "zhr_attendance_records",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    employee_code = table.Column<string>(type: "text", nullable: true),
                    department_name = table.Column<string>(type: "text", nullable: true),
                    branch_name = table.Column<string>(type: "text", nullable: true),
                    attendance_date = table.Column<DateOnly>(type: "date", nullable: false),
                    clock_in = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    clock_out = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    hours_worked = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_attendance_records", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_audit_logs",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    occurred_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    action_title = table.Column<string>(type: "text", nullable: false),
                    action_description = table.Column<string>(type: "text", nullable: true),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employee_display_code = table.Column<string>(type: "text", nullable: true),
                    employee_full_name = table.Column<string>(type: "text", nullable: true),
                    actor_id = table.Column<string>(type: "text", nullable: true),
                    actor_full_name = table.Column<string>(type: "text", nullable: false),
                    category = table.Column<string>(type: "text", nullable: false),
                    severity = table.Column<string>(type: "text", nullable: false),
                    is_flagged = table.Column<bool>(type: "boolean", nullable: false),
                    is_sensitive_read = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_audit_logs", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_branches",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_branches", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_departments",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    parent_department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    head_of_department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_departments", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_departments_zhr_departments_parent_department_id",
                        column: x => x.parent_department_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_departments",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "zhr_disciplinary_cases",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    case_type = table.Column<string>(type: "text", nullable: false),
                    severity = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    opened_at = table.Column<DateOnly>(type: "date", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_disciplinary_cases", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_employee_documents",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    document_name = table.Column<string>(type: "text", nullable: false),
                    category = table.Column<string>(type: "text", nullable: false),
                    file_size_kb = table.Column<int>(type: "integer", nullable: false),
                    uploaded_by = table.Column<string>(type: "text", nullable: false),
                    uploaded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "Active")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_documents", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_job_postings",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    title = table.Column<string>(type: "text", nullable: false),
                    department_name = table.Column<string>(type: "text", nullable: true),
                    branch_name = table.Column<string>(type: "text", nullable: true),
                    employment_type = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    applicants_count = table.Column<int>(type: "integer", nullable: false),
                    posted_at = table.Column<DateOnly>(type: "date", nullable: false),
                    closing_date = table.Column<DateOnly>(type: "date", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_job_postings", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_leave_balances",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    leave_type = table.Column<string>(type: "text", nullable: false),
                    entitled_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    used_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    remaining_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_leave_balances", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_leave_requests",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    leave_type = table.Column<string>(type: "text", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: false),
                    days_requested = table.Column<decimal>(type: "numeric(4,1)", precision: 4, scale: 1, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    approver_name = table.Column<string>(type: "text", nullable: true),
                    submitted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_leave_requests", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_lifecycle_events",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    event_type = table.Column<string>(type: "text", nullable: false),
                    department_name = table.Column<string>(type: "text", nullable: true),
                    branch_name = table.Column<string>(type: "text", nullable: true),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    urgency = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_lifecycle_events", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_onboarding_tasks",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    task_name = table.Column<string>(type: "text", nullable: false),
                    category = table.Column<string>(type: "text", nullable: false),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    assigned_to = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_onboarding_tasks", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_performance_reviews",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_full_name = table.Column<string>(type: "text", nullable: false),
                    review_period = table.Column<string>(type: "text", nullable: false),
                    reviewer_name = table.Column<string>(type: "text", nullable: true),
                    overall_rating = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_performance_reviews", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_employees",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    employee_code = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    first_name = table.Column<string>(type: "text", nullable: false),
                    middle_name = table.Column<string>(type: "text", nullable: true),
                    last_name = table.Column<string>(type: "text", nullable: false),
                    date_of_birth = table.Column<DateOnly>(type: "date", nullable: false),
                    gender = table.Column<string>(type: "text", nullable: false),
                    nationality = table.Column<string>(type: "text", nullable: false),
                    ghana_card_number = table.Column<string>(type: "text", nullable: false),
                    personal_email = table.Column<string>(type: "text", nullable: false),
                    personal_phone = table.Column<string>(type: "text", nullable: false),
                    residential_address = table.Column<string>(type: "text", nullable: false),
                    ghana_post_gps = table.Column<string>(type: "text", nullable: false),
                    lifecycle_state = table.Column<string>(type: "text", nullable: false),
                    job_title = table.Column<string>(type: "text", nullable: true),
                    department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    branch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employment_type = table.Column<string>(type: "text", nullable: true),
                    manager_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employment_status = table.Column<string>(type: "text", nullable: false),
                    contract_type = table.Column<string>(type: "text", nullable: true),
                    probation_end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    employment_start_date = table.Column<DateOnly>(type: "date", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employees", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_branches_branch_id",
                        column: x => x.branch_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_branches",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_departments_department_id",
                        column: x => x.department_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_departments",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_attendance_records_tenant_id_org_id_attendance_date",
                schema: "zeloshr",
                table: "zhr_attendance_records",
                columns: new[] { "tenant_id", "org_id", "attendance_date" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_audit_logs_tenant_id_org_id_occurred_at",
                schema: "zeloshr",
                table: "zhr_audit_logs",
                columns: new[] { "tenant_id", "org_id", "occurred_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_branches_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_branches",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_departments_parent_department_id",
                schema: "zeloshr",
                table: "zhr_departments",
                column: "parent_department_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_departments_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_departments",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_branch_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "branch_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_department_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "department_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_employee_code",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "employee_code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_ghana_card_number",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "ghana_card_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "org_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_org_id_employment_status_department",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "org_id", "employment_status", "department_id", "branch_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_lifecycle_events_tenant_id_org_id_due_date",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                columns: new[] { "tenant_id", "org_id", "due_date" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_attendance_records",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_audit_logs",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_disciplinary_cases",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employee_documents",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employees",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_job_postings",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_leave_balances",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_leave_requests",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_lifecycle_events",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_onboarding_tasks",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_performance_reviews",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_branches",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_departments",
                schema: "zeloshr");
        }
    }
}
