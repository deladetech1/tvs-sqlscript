using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddTasksWorkflows : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_task_notification_settings",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    user_id = table.Column<string>(type: "text", nullable: false),
                    opt_in = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    reminder_interval_minutes = table.Column<int>(type: "integer", nullable: false, defaultValue: 120),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_notification_settings", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_businesses_bus_id_tenant_",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_organizations_org_id_tena",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notification_settings_cp_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_workflow_templates",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    template_type = table.Column<string>(type: "text", nullable: false, defaultValue: "OTHERS"),
                    description = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_workflow_templates", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.UniqueConstraint("ak_workflow_templates_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_msg_workflow_templates_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_workflow_templates_template_type", "template_type IN ('SALES','SERVICE','DELIVERY','INSTALLATION','CONSULTATION','OTHERS')");
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_templates_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_tasks",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    title = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    task_type = table.Column<string>(type: "text", nullable: false, defaultValue: "OTHERS"),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    template_id = table.Column<string>(type: "text", nullable: true),
                    origin_location_id = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "ACTIVE"),
                    due_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_tasks", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_tasks_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_tasks_status", "status IN ('ACTIVE','COMPLETED','CANCELLED')");
                    table.CheckConstraint("ck_msg_tasks_task_type", "task_type IN ('SALES','SERVICE','DELIVERY','INSTALLATION','CONSULTATION','OTHERS')");
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_locations_origin_location_id_tenant_id",
                        columns: x => new { x.origin_location_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tasks_msg_customers_tenant_id_org_id_bus_id_customer_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_tasks_workflow_templates_template_id_tenant_id",
                        columns: x => new { x.template_id, x.tenant_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_workflow_templates",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_workflow_template_steps",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    template_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    default_location_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_workflow_template_steps", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_locations_default_location_i",
                        columns: x => new { x.default_location_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_organizations_org_id_tenant_",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_steps_msg_workflow_templates_tenant_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.template_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_workflow_templates",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_steps",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    task_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    location_id = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "TODO"),
                    claimed_by = table.Column<string>(type: "text", nullable: true),
                    claimed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    done_by = table.Column<string>(type: "text", nullable: true),
                    done_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    completed_by = table.Column<string>(type: "text", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_task_steps_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_task_steps_status", "status IN ('TODO','IN_PROGRESS','DONE','COMPLETED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_locations_location_id_tenant_id",
                        columns: x => new { x.location_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_claimed_by_tenant_id",
                        columns: x => new { x.claimed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_completed_by_tenant_id",
                        columns: x => new { x.completed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_done_by_tenant_id",
                        columns: x => new { x.done_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_steps_msg_tasks_tenant_id_org_id_bus_id_task_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.task_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tasks",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_workflow_template_step_deps",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    step_id = table.Column<string>(type: "text", nullable: false),
                    depends_on_step_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_workflow_template_step_deps", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_cp_businesses_bus_id_tenant",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_cp_organizations_org_id_ten",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_cp_users_created_by_tenant_",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_msg_workflow_template_steps",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.depends_on_step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_workflow_template_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_deps_msg_workflow_template_steps1",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_workflow_template_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_workflow_template_step_targets",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    step_id = table.Column<string>(type: "text", nullable: false),
                    target_kind = table.Column<string>(type: "text", nullable: false),
                    target_type = table.Column<string>(type: "text", nullable: false),
                    target_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_workflow_template_step_targets", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_workflow_template_step_targets_target_kind", "target_kind IN ('ASSIGNEE','APPROVER')");
                    table.CheckConstraint("ck_msg_workflow_template_step_targets_target_type", "target_type IN ('USER','GROUP')");
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_targets_cp_businesses_bus_id_ten",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_targets_cp_organizations_org_id_",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_targets_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_targets_cp_users_created_by_tena",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_workflow_template_step_targets_msg_workflow_template_st",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_workflow_template_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_notifications",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    task_id = table.Column<string>(type: "text", nullable: false),
                    step_id = table.Column<string>(type: "text", nullable: true),
                    recipient_user_id = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    picked_up_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    next_remind_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    failure_reason = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_notifications", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_task_notifications_kind", "kind IN ('ASSIGNED','READY','DONE_NEEDS_APPROVAL','REMINDER')");
                    table.CheckConstraint("ck_msg_task_notifications_status", "status IN ('PENDING','SENT','FAILED')");
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_cp_users_recipient_user_id_tenant_id",
                        columns: x => new { x.recipient_user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_msg_tasks_tenant_id_org_id_bus_id_ta",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.task_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tasks",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_notifications_task_steps_tenant_id_org_id_bus_id_s",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_step_deps",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    step_id = table.Column<string>(type: "text", nullable: false),
                    depends_on_step_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_step_deps", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_msg_task_steps_tenant_id_org_id_bus_id_d",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.depends_on_step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_deps_msg_task_steps_tenant_id_org_id_bus_id_s",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_step_targets",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    step_id = table.Column<string>(type: "text", nullable: false),
                    target_kind = table.Column<string>(type: "text", nullable: false),
                    target_type = table.Column<string>(type: "text", nullable: false),
                    target_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_step_targets", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_task_step_targets_target_kind", "target_kind IN ('ASSIGNEE','APPROVER')");
                    table.CheckConstraint("ck_msg_task_step_targets_target_type", "target_type IN ('USER','GROUP')");
                    table.ForeignKey(
                        name: "fk_msg_task_step_targets_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_targets_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_targets_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_step_targets_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_step_targets_msg_task_steps_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.step_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_steps",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_tenant_id_org_id_bus_id_user",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "tenant_id", "org_id", "bus_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notification_settings_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notification_settings",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_recipient_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "recipient_user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_status_picked_up_at",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "status", "picked_up_at" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_notifications_tenant_id_org_id_bus_id_task_id",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "task_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_deps_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_deps",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_deps_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_deps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_deps_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_deps",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_deps_tenant_id_org_id_bus_id_depends_on_step_",
                schema: "mystoreguard",
                table: "msg_task_step_deps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "depends_on_step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_deps_tenant_id_org_id_bus_id_step_id_depends_",
                schema: "mystoreguard",
                table: "msg_task_step_deps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id", "depends_on_step_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_targets_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_targets",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_targets_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_targets",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_targets_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_step_targets",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_step_targets_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_step_targets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_claimed_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "claimed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_completed_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "completed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_done_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "done_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_location_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "location_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_tenant_id_org_id_bus_id_task_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "task_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_steps_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_steps",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_origin_location_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "origin_location_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_template_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "template_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tasks_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_deps_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_deps",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_deps_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_deps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_deps_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_deps",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_deps_tenant_id_org_id_bus_id_dep",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_deps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "depends_on_step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_deps_tenant_id_org_id_bus_id_ste",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_deps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id", "depends_on_step_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_targets_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_targets",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_targets_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_targets",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_targets_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_targets",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_step_targets_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_workflow_template_step_targets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_default_location_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "default_location_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_tenant_id_org_id_bus_id_templat",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "tenant_id", "org_id", "bus_id", "template_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_template_steps_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_template_steps",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_templates_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_templates",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_templates_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_templates",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_templates_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_templates",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_templates_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_templates",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_workflow_templates_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_workflow_templates",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_task_notification_settings",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_notifications",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_step_deps",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_step_targets",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_workflow_template_step_deps",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_workflow_template_step_targets",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_steps",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_workflow_template_steps",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_tasks",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_workflow_templates",
                schema: "mystoreguard");
        }
    }
}
