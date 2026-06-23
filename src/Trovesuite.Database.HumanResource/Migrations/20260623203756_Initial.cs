using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // One-time cleanup of the legacy human_resource (hr_*) schema this module
            // used to own. Safe (IF EXISTS) on fresh databases that never had it.
            migrationBuilder.Sql("DROP SCHEMA IF EXISTS human_resource CASCADE;");

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
                    address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    country = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    custom_fields_data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_branches", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_custom_field_audit_log",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    entity_id = table.Column<Guid>(type: "uuid", nullable: false),
                    field_key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    old_value = table.Column<string>(type: "text", nullable: true),
                    new_value = table.Column<string>(type: "text", nullable: true),
                    changed_by = table.Column<string>(type: "text", nullable: false),
                    changed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    change_type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_custom_field_audit_log", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_custom_field_definitions",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    field_key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    label = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    field_type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    is_required = table.Column<bool>(type: "boolean", nullable: false),
                    is_sensitive = table.Column<bool>(type: "boolean", nullable: false),
                    is_filterable = table.Column<bool>(type: "boolean", nullable: false),
                    is_searchable = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    section_name = table.Column<string>(type: "text", nullable: true),
                    section_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    options = table.Column<string>(type: "jsonb", nullable: true),
                    validation_rules = table.Column<string>(type: "jsonb", nullable: true),
                    default_value = table.Column<string>(type: "text", nullable: true),
                    placeholder = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_custom_field_definitions", x => x.id);
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
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    parent_department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    head_of_department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    headcount_capacity = table.Column<int>(type: "integer", nullable: true),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    custom_fields_data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
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
                name: "zhr_employment_types",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_system_default = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employment_types", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_id_card_types",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_system_default = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_id_card_types", x => x.id);
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
                    leave_type_id = table.Column<Guid>(type: "uuid", nullable: true),
                    leave_type = table.Column<string>(type: "text", nullable: false),
                    entitled_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    used_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    remaining_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
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
                    leave_type_id = table.Column<Guid>(type: "uuid", nullable: true),
                    leave_type = table.Column<string>(type: "text", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: false),
                    days_requested = table.Column<decimal>(type: "numeric(4,1)", precision: 4, scale: 1, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    approval_stage = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    lm_approver_id = table.Column<string>(type: "text", nullable: true),
                    lm_decided_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    hod_approver_id = table.Column<string>(type: "text", nullable: true),
                    hod_decided_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    approver_id = table.Column<string>(type: "text", nullable: true),
                    approver_name = table.Column<string>(type: "text", nullable: true),
                    decided_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    submitted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_leave_requests", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_leave_types",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    country_code = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: true),
                    default_entitled_days = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    is_paid = table.Column<bool>(type: "boolean", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    accrual_method = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "front_loaded"),
                    carry_over_allowed = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    applies_to_employment_types = table.Column<string>(type: "jsonb", nullable: true),
                    min_notice_working_days = table.Column<int>(type: "integer", nullable: true),
                    max_consecutive_days = table.Column<int>(type: "integer", nullable: true),
                    requires_supporting_document = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_leave_types", x => x.id);
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
                    custom_fields_data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
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
                name: "zhr_public_holidays",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    country_code = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    holiday_date = table.Column<DateOnly>(type: "date", nullable: false),
                    is_recurring = table.Column<bool>(type: "boolean", nullable: false),
                    branch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_public_holidays", x => x.id);
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
                    user_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    full_name = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    first_name = table.Column<string>(type: "text", nullable: true),
                    middle_name = table.Column<string>(type: "text", nullable: true),
                    last_name = table.Column<string>(type: "text", nullable: true),
                    date_of_birth = table.Column<DateOnly>(type: "date", nullable: true),
                    gender = table.Column<string>(type: "text", nullable: true),
                    nationality = table.Column<string>(type: "text", nullable: true),
                    nationality_id_type = table.Column<string>(type: "text", nullable: true),
                    id_issue_date = table.Column<DateOnly>(type: "date", nullable: true),
                    id_expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                    id_number = table.Column<string>(type: "text", nullable: true),
                    ghana_card_number = table.Column<string>(type: "text", nullable: true),
                    personal_email = table.Column<string>(type: "text", nullable: true),
                    work_email = table.Column<string>(type: "text", nullable: true),
                    personal_phone = table.Column<string>(type: "text", nullable: true),
                    phone = table.Column<string>(type: "text", nullable: true),
                    linked_in_url = table.Column<string>(type: "text", nullable: true),
                    residential_address = table.Column<string>(type: "text", nullable: true),
                    ghana_post_gps = table.Column<string>(type: "text", nullable: true),
                    state = table.Column<string>(type: "text", nullable: true),
                    profile_photo_url = table.Column<string>(type: "text", nullable: true),
                    lifecycle_state = table.Column<string>(type: "text", nullable: false, defaultValue: "Pre-hire"),
                    lifecycle_status = table.Column<string>(type: "text", nullable: false, defaultValue: "draft"),
                    is_draft = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    job_title = table.Column<string>(type: "text", nullable: true),
                    department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    branch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employment_type = table.Column<string>(type: "text", nullable: true),
                    employment_type_id = table.Column<Guid>(type: "uuid", nullable: true),
                    work_arrangement = table.Column<string>(type: "text", nullable: true),
                    work_location = table.Column<string>(type: "text", nullable: true),
                    pay_grade = table.Column<string>(type: "text", nullable: true),
                    manager_id = table.Column<Guid>(type: "uuid", nullable: true),
                    reports_to_id = table.Column<Guid>(type: "uuid", nullable: true),
                    dotted_line_manager_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employment_status = table.Column<string>(type: "text", nullable: true, defaultValue: "Active"),
                    contract_type = table.Column<string>(type: "text", nullable: true),
                    probation_end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    employment_start_date = table.Column<DateOnly>(type: "date", nullable: true),
                    start_date = table.Column<DateOnly>(type: "date", nullable: true),
                    working_hours = table.Column<string>(type: "text", nullable: true),
                    notice_period = table.Column<string>(type: "text", nullable: true),
                    gross_salary = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: true),
                    pay_frequency = table.Column<string>(type: "text", nullable: true),
                    annualized_cost = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: true),
                    salary_effective_from = table.Column<DateOnly>(type: "date", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    document_ids = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'[]'::jsonb"),
                    ssnit_number = table.Column<string>(type: "text", nullable: true),
                    tin_number = table.Column<string>(type: "text", nullable: true),
                    tier2pension_provider = table.Column<string>(type: "text", nullable: true),
                    tier3pension_provider = table.Column<string>(type: "text", nullable: true),
                    payment_method = table.Column<string>(type: "text", nullable: true),
                    bank_account_number = table.Column<string>(type: "text", nullable: true),
                    mobile_money_number = table.Column<string>(type: "text", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    custom_fields_data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employees", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_employees_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
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
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_employees_dotted_line_manager_id",
                        column: x => x.dotted_line_manager_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_employees_manager_id",
                        column: x => x.manager_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_employees_reports_to_id",
                        column: x => x.reports_to_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_zhr_employees_zhr_employment_types_employment_type_id",
                        column: x => x.employment_type_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employment_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "zhr_employee_certifications",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    issuing_body = table.Column<string>(type: "text", nullable: true),
                    issue_date = table.Column<DateOnly>(type: "date", nullable: true),
                    expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                    credential_url = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_certifications", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_employee_certifications_zhr_employees_employee_id",
                        column: x => x.employee_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
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
                    employee_full_name = table.Column<string>(type: "text", nullable: true),
                    category = table.Column<string>(type: "text", nullable: false),
                    file_name = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: false),
                    file_size_bytes = table.Column<long>(type: "bigint", nullable: false),
                    blob_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: false),
                    content_type = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    uploaded_by = table.Column<string>(type: "text", nullable: true),
                    uploaded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    custom_fields_data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    status = table.Column<string>(type: "text", nullable: true),
                    file_size_kb = table.Column<int>(type: "integer", nullable: true),
                    document_name = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_documents", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_employee_documents_zhr_employees_employee_id",
                        column: x => x.employee_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "zhr_employee_education",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    institution = table.Column<string>(type: "text", nullable: false),
                    degree = table.Column<string>(type: "text", nullable: true),
                    field_of_study = table.Column<string>(type: "text", nullable: true),
                    start_date = table.Column<DateOnly>(type: "date", nullable: true),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    is_current = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employee_education", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_employee_education_zhr_employees_employee_id",
                        column: x => x.employee_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_employees",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
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
                name: "ix_zhr_branches_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_branches",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_branches_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_branches",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_audit_log_tenant_id_org_id_entity_type_ent",
                schema: "zeloshr",
                table: "zhr_custom_field_audit_log",
                columns: new[] { "tenant_id", "org_id", "entity_type", "entity_id", "changed_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_definitions_tenant_id_org_id_entity_type_f",
                schema: "zeloshr",
                table: "zhr_custom_field_definitions",
                columns: new[] { "tenant_id", "org_id", "entity_type", "field_key" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_definitions_tenant_id_org_id_entity_type_s",
                schema: "zeloshr",
                table: "zhr_custom_field_definitions",
                columns: new[] { "tenant_id", "org_id", "entity_type", "section_order", "display_order" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_departments_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_departments",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

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
                name: "ix_zhr_employee_certifications_employee_id",
                schema: "zeloshr",
                table: "zhr_employee_certifications",
                column: "employee_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_documents_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_documents_employee_id",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                column: "employee_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_documents_tenant_id_org_id_employee_id_category",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                columns: new[] { "tenant_id", "org_id", "employee_id", "category" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_education_employee_id",
                schema: "zeloshr",
                table: "zhr_employee_education",
                column: "employee_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_branch_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "branch_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_currency_id_tenant_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_department_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "department_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_dotted_line_manager_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "dotted_line_manager_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "employment_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_manager_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "manager_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_reports_to_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "reports_to_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_employee_code",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "employee_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_tenant_id_ghana_card_number",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "ghana_card_number" },
                unique: true,
                filter: "ghana_card_number IS NOT NULL AND ghana_card_number <> ''");

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
                name: "ix_zhr_employees_tenant_id_user_id",
                schema: "zeloshr",
                table: "zhr_employees",
                columns: new[] { "tenant_id", "user_id" },
                unique: true,
                filter: "user_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employment_types_tenant_id_org_id_is_active",
                schema: "zeloshr",
                table: "zhr_employment_types",
                columns: new[] { "tenant_id", "org_id", "is_active" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employment_types_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_employment_types",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_id_card_types_tenant_id_org_id_is_active",
                schema: "zeloshr",
                table: "zhr_id_card_types",
                columns: new[] { "tenant_id", "org_id", "is_active" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_id_card_types_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_id_card_types",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_balances_tenant_id_org_id_employee_id_leave_type_",
                schema: "zeloshr",
                table: "zhr_leave_balances",
                columns: new[] { "tenant_id", "org_id", "employee_id", "leave_type_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_leave_types_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_leave_types",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_lifecycle_events_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_lifecycle_events_tenant_id_org_id_due_date",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                columns: new[] { "tenant_id", "org_id", "due_date" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_public_holidays_tenant_id_org_id_country_code_holiday_d",
                schema: "zeloshr",
                table: "zhr_public_holidays",
                columns: new[] { "tenant_id", "org_id", "country_code", "holiday_date", "name" });
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
                name: "zhr_custom_field_audit_log",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_custom_field_definitions",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_disciplinary_cases",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employee_certifications",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employee_documents",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employee_education",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_id_card_types",
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
                name: "zhr_leave_types",
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
                name: "zhr_public_holidays",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employees",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_branches",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_departments",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_employment_types",
                schema: "zeloshr");
        }
    }
}
