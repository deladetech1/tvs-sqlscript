using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class EmployeeOnboarding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_hr_employees_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.AddColumn<string>(
                name: "department_id",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "dotted_line_manager_id",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "employee_code",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "employment_status",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: false,
                defaultValue: "ACTIVE");

            migrationBuilder.AddColumn<string>(
                name: "employment_type",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "gps_digital_address",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "job_title",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "line_manager_id",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "linkedin",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "nationality",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "nationality_id_number",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "nationality_id_type",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "notice_period_days",
                schema: "human_resource",
                table: "hr_employees",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "pay_grade",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "personal_email",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "phone_number",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "probation_end_date",
                schema: "human_resource",
                table: "hr_employees",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "residential_address",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "start_date",
                schema: "human_resource",
                table: "hr_employees",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "state",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "work_arrangement",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "work_email",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "work_location",
                schema: "human_resource",
                table: "hr_employees",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "working_hours_per_week",
                schema: "human_resource",
                table: "hr_employees",
                type: "numeric",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "hr_banks",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    name = table.Column<string>(type: "text", nullable: false),
                    swift_code = table.Column<string>(type: "text", nullable: true),
                    sort_code = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_banks_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_banks_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_banks_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_banks_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_banks_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_banks_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "hr_departments",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    name = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_departments", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_departments_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_departments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_departments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_departments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_departments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "hr_document_paths",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    document_path = table.Column<string>(type: "text", nullable: false),
                    file_name = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_hr_document_paths_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_document_paths_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_document_paths_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_document_paths_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_hr_document_paths_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_hr_document_paths_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "hr_employee_emergency_contacts",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    employee_id = table.Column<string>(type: "text", nullable: false),
                    full_name = table.Column<string>(type: "text", nullable: false),
                    relationship = table.Column<string>(type: "text", nullable: true),
                    phone_number = table.Column<string>(type: "text", nullable: true),
                    email = table.Column<string>(type: "text", nullable: true),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_employee_emergency_contacts", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_employee_emergency_contacts_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_hr_employee_emergency_contacts_relationship", "relationship IN ('SPOUSE','PARENT','SIBLING','CHILD','FRIEND','OTHER',NULL)");
                    table.ForeignKey(
                        name: "fk_hr_employee_emergency_contacts_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_emergency_contacts_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_emergency_contacts_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_emergency_contacts_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_emergency_contacts_hr_employees_employee_id_ten",
                        columns: x => new { x.employee_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_employees",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "hr_employee_salaries",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    employee_id = table.Column<string>(type: "text", nullable: false),
                    gross_monthly_salary = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    pay_frequency = table.Column<string>(type: "text", nullable: false, defaultValue: "MONTHLY"),
                    pay_grade = table.Column<string>(type: "text", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    effective_from = table.Column<DateOnly>(type: "date", nullable: false),
                    effective_to = table.Column<DateOnly>(type: "date", nullable: true),
                    is_current = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    reason = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_employee_salaries", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_employee_salaries_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_hr_employee_salaries_pay_frequency", "pay_frequency IN ('MONTHLY','BIWEEKLY','WEEKLY')");
                    table.CheckConstraint("ck_hr_employee_salaries_reason", "reason IN ('INITIAL','RAISE','PROMOTION','CORRECTION',NULL)");
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_salaries_hr_employees_employee_id_tenant_id",
                        columns: x => new { x.employee_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_employees",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "hr_pension_providers",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    name = table.Column<string>(type: "text", nullable: false),
                    tier = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_pension_providers_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_pension_providers_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_hr_pension_providers_tier", "tier IN ('TIER_2','TIER_3')");
                    table.ForeignKey(
                        name: "fk_hr_pension_providers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_pension_providers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_pension_providers_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_pension_providers_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "hr_bank_branches",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    bank_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    branch_code = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_bank_branches", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_bank_branches_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_bank_branches_banks_bank_id_tenant_id",
                        columns: x => new { x.bank_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_banks",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_bank_branches_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_bank_branches_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_bank_branches_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_bank_branches_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "hr_employee_documents",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    employee_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    document_type = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_employee_documents", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_employee_documents_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_hr_employee_documents_document_type", "document_type IN ('CONTRACT','NATIONAL_ID','CERTIFICATE','OTHER')");
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_hr_document_paths_document_id_tenant_",
                        columns: x => new { x.document_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_document_paths",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_documents_hr_employees_employee_id_tenant_id",
                        columns: x => new { x.employee_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_employees",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "hr_employee_statutory",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    employee_id = table.Column<string>(type: "text", nullable: false),
                    ssnit_number = table.Column<string>(type: "text", nullable: true),
                    tin = table.Column<string>(type: "text", nullable: true),
                    tier2provider_id = table.Column<string>(type: "text", nullable: true),
                    tier3provider_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_employee_statutory", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_employee_statutory_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_hr_employees_employee_id_tenant_id",
                        columns: x => new { x.employee_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_employees",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_pension_providers_tier2provider_id_te",
                        columns: x => new { x.tier2provider_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_pension_providers",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_statutory_pension_providers_tier3provider_id_te",
                        columns: x => new { x.tier3provider_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_pension_providers",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "hr_employee_payment_methods",
                schema: "human_resource",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    employee_id = table.Column<string>(type: "text", nullable: false),
                    bank_id = table.Column<string>(type: "text", nullable: false),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    account_name = table.Column<string>(type: "text", nullable: false),
                    account_number = table.Column<string>(type: "text", nullable: false),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hr_employee_payment_methods", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_hr_employee_payment_methods_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_hr_bank_branches_branch_id_tena",
                        columns: x => new { x.branch_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_bank_branches",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_hr_banks_bank_id_tenant_id",
                        columns: x => new { x.bank_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_banks",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_hr_employee_payment_methods_hr_employees_employee_id_tenant",
                        columns: x => new { x.employee_id, x.tenant_id },
                        principalSchema: "human_resource",
                        principalTable: "hr_employees",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employees_department_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "department_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employees_dotted_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "dotted_line_manager_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employees_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "line_manager_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employees_tenant_id_employee_code",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "tenant_id", "employee_code" },
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_employment_status",
                schema: "human_resource",
                table: "hr_employees",
                sql: "employment_status IN ('ACTIVE','ON_LEAVE','TERMINATED','SUSPENDED')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_employment_type",
                schema: "human_resource",
                table: "hr_employees",
                sql: "employment_type IN ('FULL_TIME','PART_TIME','CONTRACT','INTERN',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_nationality_id_type",
                schema: "human_resource",
                table: "hr_employees",
                sql: "nationality_id_type IN ('PASSPORT','NATIONAL_ID','DRIVERS_LICENSE','OTHER',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_no_self_dotted_manager",
                schema: "human_resource",
                table: "hr_employees",
                sql: "dotted_line_manager_id IS NULL OR dotted_line_manager_id <> id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_no_self_manager",
                schema: "human_resource",
                table: "hr_employees",
                sql: "line_manager_id IS NULL OR line_manager_id <> id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_hr_employees_work_arrangement",
                schema: "human_resource",
                table: "hr_employees",
                sql: "work_arrangement IN ('ONSITE','REMOTE','HYBRID',NULL)");

            migrationBuilder.CreateIndex(
                name: "ix_hr_bank_branches_bank_id_tenant_id",
                schema: "human_resource",
                table: "hr_bank_branches",
                columns: new[] { "bank_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_bank_branches_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_bank_branches",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_bank_branches_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_bank_branches",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_bank_branches_tenant_id_bank_id_name",
                schema: "human_resource",
                table: "hr_bank_branches",
                columns: new[] { "tenant_id", "bank_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_hr_bank_branches_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_bank_branches",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_banks_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_banks",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_banks_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_banks",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_banks_tenant_id_name",
                schema: "human_resource",
                table: "hr_banks",
                columns: new[] { "tenant_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_hr_banks_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_banks",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_departments_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_departments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_departments_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_departments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_departments_tenant_id_name",
                schema: "human_resource",
                table: "hr_departments",
                columns: new[] { "tenant_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_hr_departments_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_departments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_document_paths_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_document_paths",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_document_paths_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_document_paths",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_document_paths_tenant_id",
                schema: "human_resource",
                table: "hr_document_paths",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_hr_document_paths_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_document_paths",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_document_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                columns: new[] { "document_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_employee_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                columns: new[] { "employee_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_documents_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_documents",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_emergency_contacts_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_emergency_contacts",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_emergency_contacts_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_emergency_contacts",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_emergency_contacts_employee_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_emergency_contacts",
                columns: new[] { "employee_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_emergency_contacts_tenant_id",
                schema: "human_resource",
                table: "hr_employee_emergency_contacts",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_emergency_contacts_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_emergency_contacts",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_bank_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "bank_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_branch_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "branch_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_employee_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "employee_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_tenant_id_employee_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "tenant_id", "employee_id" },
                unique: true,
                filter: "is_primary = true AND delete_status = 'NOT_DELETED'");

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_payment_methods_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_payment_methods",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_currency_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_employee_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "employee_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_tenant_id_employee_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "tenant_id", "employee_id" },
                unique: true,
                filter: "is_current = true AND delete_status = 'NOT_DELETED'");

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_salaries_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_salaries",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_employee_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "employee_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_tenant_id_employee_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "tenant_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_tier2provider_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "tier2provider_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_tier3provider_id_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "tier3provider_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_employee_statutory_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_employee_statutory",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_pension_providers_created_by_tenant_id",
                schema: "human_resource",
                table: "hr_pension_providers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_pension_providers_deleted_by_tenant_id",
                schema: "human_resource",
                table: "hr_pension_providers",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_hr_pension_providers_tenant_id_name_tier",
                schema: "human_resource",
                table: "hr_pension_providers",
                columns: new[] { "tenant_id", "name", "tier" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_hr_pension_providers_updated_by_tenant_id",
                schema: "human_resource",
                table: "hr_pension_providers",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_hr_employees_hr_departments_department_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "department_id", "tenant_id" },
                principalSchema: "human_resource",
                principalTable: "hr_departments",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_hr_employees_hr_employees_dotted_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "dotted_line_manager_id", "tenant_id" },
                principalSchema: "human_resource",
                principalTable: "hr_employees",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_hr_employees_hr_employees_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                columns: new[] { "line_manager_id", "tenant_id" },
                principalSchema: "human_resource",
                principalTable: "hr_employees",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_hr_employees_hr_departments_department_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropForeignKey(
                name: "fk_hr_employees_hr_employees_dotted_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropForeignKey(
                name: "fk_hr_employees_hr_employees_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropTable(
                name: "hr_departments",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_employee_documents",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_employee_emergency_contacts",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_employee_payment_methods",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_employee_salaries",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_employee_statutory",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_document_paths",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_bank_branches",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_pension_providers",
                schema: "human_resource");

            migrationBuilder.DropTable(
                name: "hr_banks",
                schema: "human_resource");

            migrationBuilder.DropIndex(
                name: "ix_hr_employees_department_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropIndex(
                name: "ix_hr_employees_dotted_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropIndex(
                name: "ix_hr_employees_line_manager_id_tenant_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropIndex(
                name: "ix_hr_employees_tenant_id_employee_code",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_employment_status",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_employment_type",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_nationality_id_type",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_no_self_dotted_manager",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_no_self_manager",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropCheckConstraint(
                name: "ck_hr_employees_work_arrangement",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "department_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "dotted_line_manager_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "employee_code",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "employment_status",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "employment_type",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "gps_digital_address",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "job_title",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "line_manager_id",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "linkedin",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "nationality",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "nationality_id_number",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "nationality_id_type",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "notice_period_days",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "pay_grade",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "personal_email",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "phone_number",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "probation_end_date",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "residential_address",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "start_date",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "state",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "work_arrangement",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "work_email",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "work_location",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.DropColumn(
                name: "working_hours_per_week",
                schema: "human_resource",
                table: "hr_employees");

            migrationBuilder.CreateIndex(
                name: "ix_hr_employees_tenant_id",
                schema: "human_resource",
                table: "hr_employees",
                column: "tenant_id");
        }
    }
}
