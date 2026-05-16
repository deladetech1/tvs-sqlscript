using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "core_platform");

            migrationBuilder.CreateTable(
                name: "cp_app_features",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    feature_type = table.Column<string>(type: "varchar(50)", nullable: false),
                    title = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_app_features", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "cp_apps",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    app_name = table.Column<string>(type: "text", nullable: true),
                    feature1 = table.Column<string>(type: "text", nullable: true),
                    feature2 = table.Column<string>(type: "text", nullable: true),
                    feature3 = table.Column<string>(type: "text", nullable: true),
                    feature4 = table.Column<string>(type: "text", nullable: true),
                    feature5 = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "coming_soon"),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_apps", x => x.id);
                    table.CheckConstraint("ck_cp_apps_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_apps_status", "status IN ('coming_soon','live','deprecated','beta')");
                });

            migrationBuilder.CreateTable(
                name: "cp_enterprise_subscriptions",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    contact = table.Column<string>(type: "text", nullable: false),
                    company_name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_enterprise_subscriptions", x => x.id);
                    table.CheckConstraint("ck_cp_enterprise_subscriptions_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                });

            migrationBuilder.CreateTable(
                name: "cp_resource_types",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    resource_type_name = table.Column<string>(type: "text", nullable: false),
                    parent_resource_id = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_resource_types", x => x.id);
                    table.CheckConstraint("ck_cp_resource_types_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_resource_types_cp_resource_types_parent_resource_id",
                        column: x => x.parent_resource_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_subscriptions",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    subscription_name = table.Column<string>(type: "text", nullable: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_subscriptions", x => x.id);
                    table.CheckConstraint("ck_cp_subscriptions_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                });

            migrationBuilder.CreateTable(
                name: "cp_tenant_owners_registry",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    fullname = table.Column<string>(type: "text", nullable: true),
                    email = table.Column<string>(type: "text", nullable: true),
                    contact = table.Column<string>(type: "text", nullable: true),
                    dob = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true, comment: "False once the owner has closed the account."),
                    reason = table.Column<string>(type: "text", nullable: true, comment: "Why the owner stopped using the app. Collected at account closure."),
                    stopped_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    mdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_tenant_owners_registry", x => x.tenant_id);
                },
                comment: "Internal Trovesuite-ops record of tenant owners. No FKs by design — rows persist after tenant hard-delete so churn/ownership history survives.");

            migrationBuilder.CreateTable(
                name: "cp_tenants",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    description = table.Column<string>(type: "text", nullable: true),
                    is_verified = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_tenants", x => x.id);
                    table.CheckConstraint("ck_cp_tenants_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                });

            migrationBuilder.CreateTable(
                name: "cp_permissions",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    permission_name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    resource_type_id = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_permissions", x => x.id);
                    table.CheckConstraint("ck_cp_permissions_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_permissions_resource_types_resource_type_id",
                        column: x => x.resource_type_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_shared_resource_ids",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    resource_type_id = table.Column<string>(type: "text", nullable: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_shared_resource_ids", x => x.id);
                    table.CheckConstraint("ck_cp_shared_resource_ids_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_shared_resource_ids_cp_resource_types_resource_type_id",
                        column: x => x.resource_type_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_app_tier_configs",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    app_id = table.Column<string>(type: "text", nullable: false),
                    subscription_id = table.Column<string>(type: "text", nullable: false),
                    max_login_users = table.Column<int>(type: "integer", nullable: true),
                    price = table.Column<decimal>(type: "numeric(12,2)", nullable: false, defaultValue: 0m),
                    rate = table.Column<decimal>(type: "numeric(12,2)", nullable: false, defaultValue: 12.0m),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_app_tier_configs", x => x.id);
                    table.CheckConstraint("ck_cp_app_tier_configs_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_app_tier_configs_cp_apps_app_id",
                        column: x => x.app_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_apps",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_tier_configs_subscriptions_subscription_id",
                        column: x => x.subscription_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_subscriptions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_activity_logs",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    action = table.Column<string>(type: "text", nullable: true),
                    resource_type = table.Column<string>(type: "text", nullable: true),
                    old_data = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    new_data = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    performed_by_email = table.Column<string>(type: "text", nullable: true),
                    performed_by_contact = table.Column<string>(type: "text", nullable: true),
                    performed_by_fullname = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_activity_logs", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_activity_logs_resource_types_resource_type",
                        column: x => x.resource_type,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_activity_logs_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "cp_users",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    contact = table.Column<string>(type: "text", nullable: false),
                    is_owner = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    gender = table.Column<string>(type: "text", nullable: true),
                    dob = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    profile_pic = table.Column<string>(type: "text", nullable: true),
                    login_password = table.Column<string>(type: "text", nullable: true),
                    can_login = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
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
                    table.PrimaryKey("ak_users_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_users_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_users_gender", "gender IN ('MALE','FEMALE',NULL)");
                    table.ForeignKey(
                        name: "fk_cp_users_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_users_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_users_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_users_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_change_password_policy",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    allow_password_change = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_change_password_policy", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_change_password_policy_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_change_password_policy_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_change_password_policy_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_currencies",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    name = table.Column<string>(type: "text", nullable: false),
                    code = table.Column<string>(type: "text", nullable: false),
                    symbol = table.Column<string>(type: "text", nullable: false),
                    country = table.Column<string>(type: "text", nullable: true),
                    decimal_places = table.Column<int>(type: "integer", nullable: false, defaultValue: 2),
                    thousand_separator = table.Column<string>(type: "text", nullable: true, defaultValue: ","),
                    decimal_separator = table.Column<string>(type: "text", nullable: true, defaultValue: "."),
                    currency_position = table.Column<string>(type: "text", nullable: false, defaultValue: "before"),
                    locale = table.Column<string>(type: "text", nullable: true),
                    minor_unit_name = table.Column<string>(type: "text", nullable: true),
                    is_default = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(20,6)", nullable: true),
                    exchange_rate_source = table.Column<string>(type: "text", nullable: true, defaultValue: "manual"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_currencies", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_currencies_currency_position", "currency_position IN ('before','after')");
                    table.CheckConstraint("ck_cp_currencies_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_currencies_exchange_rate_source", "exchange_rate_source IN ('manual','auto')");
                    table.ForeignKey(
                        name: "fk_cp_currencies_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_currencies_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_currencies_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_currencies_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_groups",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    group_name = table.Column<string>(type: "text", nullable: false),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_groups_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_groups_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_groups_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_groups_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_groups_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_groups_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_locations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    loc_name = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_locations_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_locations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_locations_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_locations_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_locations_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_locations_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_members",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: false),
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
                    table.PrimaryKey("pk_cp_members", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_members_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_members_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_members_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_members_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_members_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_members_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                },
                comment: "Rows here are users added directly at the core-platform level. HR-onboarded users live in cp_users + human_resource.hr_employees, NOT here.");

            migrationBuilder.CreateTable(
                name: "cp_multi_factor_settings",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    is_multi_factor = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_multi_factor_settings", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_multi_factor_settings_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_multi_factor_settings_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_multi_factor_settings_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_notification_email_credentials",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    notification_email = table.Column<string>(type: "text", nullable: false, comment: "Tenant-specific email address for sending notifications."),
                    notification_password = table.Column<string>(type: "text", nullable: false, comment: "Password for the tenant-specific notification email."),
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
                    table.PrimaryKey("pk_cp_notification_email_credentials", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_notification_email_credentials_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_notification_email_credentials_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_notification_email_credentials_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_notification_email_credentials_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_notification_email_credentials_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                },
                comment: "Stores tenant-specific email credentials for sending notifications. If a tenant has credentials here, they will be used instead of system defaults.");

            migrationBuilder.CreateTable(
                name: "cp_organizations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    logo_id = table.Column<string>(type: "text", nullable: true),
                    org_name = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_organizations_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_organizations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_organizations_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_organizations_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_organizations_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_organizations_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_otps",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    otp_code = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    email = table.Column<string>(type: "text", nullable: false),
                    contact = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_otps", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_otps_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_otps_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_otps_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "cp_password_policies",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    enforce_password_policy = table.Column<bool>(type: "boolean", nullable: false),
                    min_length = table.Column<int>(type: "integer", nullable: false, defaultValue: 8),
                    require_uppercase = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    require_lowercase = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    require_numbers = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    require_special_chars = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    special_chars_list = table.Column<string>(type: "text", nullable: true, defaultValue: "!@#$%^&*()_+-=[]{}|;:,.<>?"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_password_policies", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_password_policies_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_password_policies_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_password_policies_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_resource_deletion_chat_histories",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    resource_id = table.Column<string>(type: "text", nullable: true),
                    message = table.Column<string>(type: "text", nullable: true),
                    sent_by = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_resource_deletion_chat_histories", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_resource_deletion_chat_histories_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_resource_deletion_chat_histories_users_sent_by_tenant_id",
                        columns: x => new { x.sent_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_roles",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    role_name = table.Column<string>(type: "text", nullable: false),
                    resource_type_id = table.Column<string>(type: "text", nullable: true),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "CURRENT_TIMESTAMP"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_roles", x => x.id);
                    table.CheckConstraint("ck_cp_roles_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_roles_cp_resource_types_resource_type_id",
                        column: x => x.resource_type_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_roles_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_roles_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_roles_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_roles_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_themes",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: false),
                    theme_name = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_themes", x => new { x.id, x.tenant_id, x.user_id });
                    table.CheckConstraint("ck_cp_themes_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_themes_theme_name", "theme_name IN ('light','dark','system')");
                    table.ForeignKey(
                        name: "fk_cp_themes_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_themes_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_themes_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_themes_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_themes_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_unit_of_measures",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    name = table.Column<string>(type: "text", nullable: false),
                    symbol = table.Column<string>(type: "text", nullable: false),
                    decimal_place = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_unit_of_measures", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_unit_of_measures_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_unit_of_measures_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_unit_of_measures_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_unit_of_measures_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_unit_of_measures_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_user_login_tracking",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    user_id = table.Column<string>(type: "text", nullable: false),
                    login_attempts_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    last_failed_login_attempt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_successful_login = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    password_last_changed = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    password_expiry_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    password_history = table.Column<string[]>(type: "text[]", nullable: true),
                    is_locked = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    locked_until = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_user_login_tracking", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_cp_user_login_tracking_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_user_login_tracking_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_login_tracking_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_login_tracking_cp_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_login_settings",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: true),
                    group_id = table.Column<string>(type: "text", nullable: true),
                    is_suspended = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_multi_factor_enabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_login_before = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    working_days = table.Column<string[]>(type: "text[]", nullable: true),
                    login_on = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    logout_on = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    can_always_login = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_login_settings", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_login_settings_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_login_settings_cp_groups_group_id_tenant_id",
                        columns: x => new { x.group_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_groups",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_login_settings_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_login_settings_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_login_settings_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_login_settings_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_login_settings_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_user_groups",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: true),
                    group_id = table.Column<string>(type: "text", nullable: true),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_user_groups", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_user_groups_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_groups_group_id_tenant_id",
                        columns: x => new { x.group_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_groups",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_groups_cp_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_businesses",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    logo_id = table.Column<string>(type: "text", nullable: true),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_name = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_businesses_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_businesses_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_businesses_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_businesses_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_businesses_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_businesses_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_businesses_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_assign_roles",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: true),
                    group_id = table.Column<string>(type: "text", nullable: true),
                    role_id = table.Column<string>(type: "text", nullable: true),
                    resource_type = table.Column<string>(type: "text", nullable: true),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_assign_roles", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_assign_roles_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_groups_group_id_tenant_id",
                        columns: x => new { x.group_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_groups",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_roles_role_id",
                        column: x => x.role_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_assign_roles_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_role_permissions",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    role_id = table.Column<string>(type: "text", nullable: true),
                    permission_id = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_cp_role_permissions", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_role_permissions_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_cp_permissions_permission_id",
                        column: x => x.permission_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_permissions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_cp_roles_role_id",
                        column: x => x.role_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_role_permissions_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_billings_logs",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    organization_id = table.Column<string>(type: "text", nullable: false),
                    organization_name = table.Column<string>(type: "text", nullable: false),
                    business_id = table.Column<string>(type: "text", nullable: false),
                    business_name = table.Column<string>(type: "text", nullable: false),
                    location_id = table.Column<string>(type: "text", nullable: false),
                    location_name = table.Column<string>(type: "text", nullable: false),
                    app_id = table.Column<string>(type: "text", nullable: false),
                    app_name = table.Column<string>(type: "text", nullable: false),
                    price = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    rate = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    subscription_id = table.Column<string>(type: "text", nullable: true),
                    month = table.Column<string>(type: "text", nullable: true),
                    is_paid = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    paid_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    paid_date = table.Column<string>(type: "text", nullable: true),
                    paid_by = table.Column<string>(type: "text", nullable: true),
                    paid_method = table.Column<string>(type: "text", nullable: true),
                    paid_note = table.Column<string>(type: "text", nullable: true),
                    paid_status = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true, defaultValue: "SYSTEM"),
                    updated_by = table.Column<string>(type: "text", nullable: true, defaultValue: "SYSTEM"),
                    deleted_by = table.Column<string>(type: "text", nullable: true, defaultValue: "SYSTEM"),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_billings_logs", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_billings_logs_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_billings_logs_paid_method", "paid_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','OTHERS',NULL)");
                    table.CheckConstraint("ck_cp_billings_logs_paid_status", "paid_status IN ('PENDING','PAID','FAILED','CANCELLED','REFUNDED','OTHERS',NULL)");
                    table.ForeignKey(
                        name: "fk_cp_billings_logs_businesses_business_id_tenant_id",
                        columns: x => new { x.business_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_billings_logs_cp_apps_app_id",
                        column: x => x.app_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_apps",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_billings_logs_locations_location_id_tenant_id",
                        columns: x => new { x.location_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_billings_logs_organizations_organization_id_tenant_id",
                        columns: x => new { x.organization_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_billings_logs_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "cp_business_apps",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    app_id = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_business_apps", x => new { x.tenant_id, x.id });
                    table.UniqueConstraint("ak_business_apps_id_tenant_id", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_business_apps_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_business_apps_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_apps_cp_apps_app_id",
                        column: x => x.app_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_apps",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_apps_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_business_apps_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_apps_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_apps_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_document_paths",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    document_path = table.Column<string>(type: "text", nullable: false),
                    file_name = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_document_paths", x => new { x.tenant_id, x.org_id, x.id });
                    table.CheckConstraint("ck_cp_document_paths_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_document_paths_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_document_paths_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_document_paths_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_document_paths_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_document_paths_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_cp_document_paths_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "cp_expense",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    loc_id = table.Column<string>(type: "text", nullable: true),
                    exp_name = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_expense", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_expense_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_expense_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expense_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expense_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expense_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_expense_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expense_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expense_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_expenses_history",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    balance = table.Column<decimal>(type: "numeric(20,6)", nullable: true, defaultValue: 0m),
                    used_by = table.Column<string>(type: "text", nullable: true),
                    used_for = table.Column<string>(type: "text", nullable: true),
                    source = table.Column<string>(type: "text", nullable: false, defaultValue: "ALLOCATED"),
                    app = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_expenses_history", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_cp_expenses_history_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_cp_expenses_history_source", "source IN ('ALLOCATED','CONTIGENCY','FIXED','REIMBURSABLE')");
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_expenses_history_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_app_subscriptions",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    business_app_id = table.Column<string>(type: "text", nullable: false),
                    business_id = table.Column<string>(type: "text", nullable: false),
                    app_id = table.Column<string>(type: "text", nullable: false),
                    shared_subscription_id = table.Column<string>(type: "text", nullable: false),
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
                    table.PrimaryKey("pk_cp_app_subscriptions", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_app_subscriptions_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_business_apps_business_app_id_tenant_id",
                        columns: x => new { x.business_app_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_business_apps",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_businesses_business_id_tenant_id",
                        columns: x => new { x.business_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_cp_apps_app_id",
                        column: x => x.app_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_apps",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_subscriptions_shared_subscription_id",
                        column: x => x.shared_subscription_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_subscriptions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscriptions_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Per-business subscription. One tier per (tenant, business, app). Seat caps and pricing are scoped to this row.");

            migrationBuilder.CreateTable(
                name: "cp_business_app_locations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    business_app_id = table.Column<string>(type: "text", nullable: true),
                    loc_id = table.Column<string>(type: "text", nullable: true),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    app_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_business_app_locations", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_business_app_locations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_cp_business_apps_business_app_id_",
                        columns: x => new { x.business_app_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_business_apps",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_business_app_locations_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_app_subscription_histories",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    app_subscription_id = table.Column<string>(type: "text", nullable: false),
                    business_id = table.Column<string>(type: "text", nullable: false),
                    app_id = table.Column<string>(type: "text", nullable: false),
                    shared_subscription_id = table.Column<string>(type: "text", nullable: false),
                    start_at = table.Column<string>(type: "text", nullable: true),
                    end_at = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_app_subscription_histories", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_app_subscription_histories_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_businesses_business_id_tenant",
                        columns: x => new { x.business_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_cp_app_subscriptions_app_subs",
                        columns: x => new { x.app_subscription_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_app_subscriptions",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_cp_apps_app_id",
                        column: x => x.app_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_apps",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_subscriptions_shared_subscrip",
                        column: x => x.shared_subscription_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_subscriptions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_app_subscription_histories_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_group_locations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    group_id = table.Column<string>(type: "text", nullable: true),
                    bus_app_loc_id = table.Column<string>(type: "text", nullable: true),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    app_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_group_locations", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_group_locations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_group_locations_cp_business_app_locations_bus_app_loc_id",
                        columns: x => new { x.bus_app_loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_business_app_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_group_locations_cp_groups_group_id_tenant_id",
                        columns: x => new { x.group_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_groups",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_group_locations_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_group_locations_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_group_locations_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_group_locations_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_user_locations",
                schema: "core_platform",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    user_id = table.Column<string>(type: "text", nullable: true),
                    bus_app_loc_id = table.Column<string>(type: "text", nullable: true),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    app_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_user_locations", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_user_locations_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_business_app_locations_bus_app_loc_id_",
                        columns: x => new { x.bus_app_loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_business_app_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_user_locations_cp_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_cp_activity_logs_resource_type",
                schema: "core_platform",
                table: "cp_activity_logs",
                column: "resource_type");

            migrationBuilder.CreateIndex(
                name: "ix_cp_activity_logs_tenant_id",
                schema: "core_platform",
                table: "cp_activity_logs",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_app_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                column: "app_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_app_subscription_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "app_subscription_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_business_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "business_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_shared_subscription_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                column: "shared_subscription_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscription_histories_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscription_histories",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_app_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                column: "app_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_business_app_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "business_app_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_business_id_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "business_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_shared_subscription_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                column: "shared_subscription_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_tenant_id_business_id_app_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "tenant_id", "business_id", "app_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_subscriptions_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_app_subscriptions",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_tier_configs_app_id_subscription_id",
                schema: "core_platform",
                table: "cp_app_tier_configs",
                columns: new[] { "app_id", "subscription_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_app_tier_configs_subscription_id",
                schema: "core_platform",
                table: "cp_app_tier_configs",
                column: "subscription_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_apps_app_name",
                schema: "core_platform",
                table: "cp_apps",
                column: "app_name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "group_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_role_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_tenant_id_group_id_role_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "tenant_id", "group_id", "role_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_tenant_id_user_id_role_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "tenant_id", "user_id", "role_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_assign_roles_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_assign_roles",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_billings_logs_app_id",
                schema: "core_platform",
                table: "cp_billings_logs",
                column: "app_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_billings_logs_business_id_tenant_id",
                schema: "core_platform",
                table: "cp_billings_logs",
                columns: new[] { "business_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_billings_logs_location_id_tenant_id",
                schema: "core_platform",
                table: "cp_billings_logs",
                columns: new[] { "location_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_billings_logs_organization_id_tenant_id",
                schema: "core_platform",
                table: "cp_billings_logs",
                columns: new[] { "organization_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_billings_logs_tenant_id",
                schema: "core_platform",
                table: "cp_billings_logs",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_business_app_id_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                columns: new[] { "business_app_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_loc_id_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_app_locations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_app_locations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_app_id",
                schema: "core_platform",
                table: "cp_business_apps",
                column: "app_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_bus_id_tenant_id",
                schema: "core_platform",
                table: "cp_business_apps",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_apps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_apps",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_tenant_id_bus_id_app_id",
                schema: "core_platform",
                table: "cp_business_apps",
                columns: new[] { "tenant_id", "bus_id", "app_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_business_apps_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_business_apps",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_businesses_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_businesses",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_businesses_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_businesses",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_businesses_org_id_tenant_id",
                schema: "core_platform",
                table: "cp_businesses",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_businesses_tenant_id_bus_name",
                schema: "core_platform",
                table: "cp_businesses",
                columns: new[] { "tenant_id", "bus_name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_businesses_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_businesses",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_change_password_policy_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_change_password_policy",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_change_password_policy_tenant_id",
                schema: "core_platform",
                table: "cp_change_password_policy",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_change_password_policy_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_change_password_policy",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_currencies_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_currencies",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_currencies_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_currencies",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_currencies_tenant_id_code",
                schema: "core_platform",
                table: "cp_currencies",
                columns: new[] { "tenant_id", "code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_currencies_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_currencies",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_document_paths_bus_id_tenant_id",
                schema: "core_platform",
                table: "cp_document_paths",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_document_paths_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_document_paths",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_document_paths_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_document_paths",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_document_paths_org_id_tenant_id",
                schema: "core_platform",
                table: "cp_document_paths",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_document_paths_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_document_paths",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_bus_id_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_loc_id_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_org_id_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_tenant_id_org_id_bus_id_loc_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_expense_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_expense",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_bus_id_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_currency_id_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_loc_id_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_org_id_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_expenses_history_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_expenses_history",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_bus_app_loc_id_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                columns: new[] { "bus_app_loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                columns: new[] { "group_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_group_locations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_group_locations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_groups_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_groups",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_groups_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_groups",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_groups_tenant_id_group_name",
                schema: "core_platform",
                table: "cp_groups",
                columns: new[] { "tenant_id", "group_name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_groups_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_groups",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_locations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_locations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_locations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_locations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_locations_tenant_id_loc_name",
                schema: "core_platform",
                table: "cp_locations",
                columns: new[] { "tenant_id", "loc_name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_locations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_locations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "group_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_members_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_members",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_members_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_members",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_members_tenant_id",
                schema: "core_platform",
                table: "cp_members",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_members_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_members",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_members_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_members",
                columns: new[] { "user_id", "tenant_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_multi_factor_settings_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_multi_factor_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_multi_factor_settings_tenant_id",
                schema: "core_platform",
                table: "cp_multi_factor_settings",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_multi_factor_settings_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_multi_factor_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_notification_email_credentials_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_notification_email_credentials",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_notification_email_credentials_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_notification_email_credentials",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_notification_email_credentials_tenant_id",
                schema: "core_platform",
                table: "cp_notification_email_credentials",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_notification_email_credentials_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_notification_email_credentials",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_organizations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_organizations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_organizations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_organizations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_organizations_tenant_id_org_name",
                schema: "core_platform",
                table: "cp_organizations",
                columns: new[] { "tenant_id", "org_name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_organizations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_organizations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_otps_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_otps",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_otps_tenant_id",
                schema: "core_platform",
                table: "cp_otps",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_otps_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_otps",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_password_policies_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_password_policies",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_password_policies_tenant_id",
                schema: "core_platform",
                table: "cp_password_policies",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_password_policies_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_password_policies",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_permissions_resource_type_id",
                schema: "core_platform",
                table: "cp_permissions",
                column: "resource_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_resource_deletion_chat_histories_sent_by_tenant_id",
                schema: "core_platform",
                table: "cp_resource_deletion_chat_histories",
                columns: new[] { "sent_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_resource_deletion_chat_histories_tenant_id",
                schema: "core_platform",
                table: "cp_resource_deletion_chat_histories",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_resource_types_parent_resource_id",
                schema: "core_platform",
                table: "cp_resource_types",
                column: "parent_resource_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_permission_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                column: "permission_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_role_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_tenant_id_role_id_permission_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                columns: new[] { "tenant_id", "role_id", "permission_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_role_permissions_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_role_permissions",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_roles_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_roles",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_roles_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_roles",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_roles_resource_type_id",
                schema: "core_platform",
                table: "cp_roles",
                column: "resource_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_roles_tenant_id_role_name",
                schema: "core_platform",
                table: "cp_roles",
                columns: new[] { "tenant_id", "role_name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_roles_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_roles",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_shared_resource_ids_resource_type_id",
                schema: "core_platform",
                table: "cp_shared_resource_ids",
                column: "resource_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_themes_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_themes",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_themes_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_themes",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_themes_tenant_id_theme_name_user_id",
                schema: "core_platform",
                table: "cp_themes",
                columns: new[] { "tenant_id", "theme_name", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_themes_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_themes",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_themes_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_themes",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_unit_of_measures_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_unit_of_measures",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_unit_of_measures_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_unit_of_measures",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_unit_of_measures_tenant_id_name",
                schema: "core_platform",
                table: "cp_unit_of_measures",
                columns: new[] { "tenant_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_unit_of_measures_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_unit_of_measures",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "group_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_tenant_id_user_id_group_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "tenant_id", "user_id", "group_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_groups_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_user_groups",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_bus_app_loc_id_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                columns: new[] { "bus_app_loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_locations_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_user_locations",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_login_tracking_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_login_tracking_tenant_id_user_id",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                columns: new[] { "tenant_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_login_tracking_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_login_tracking_user_id_tenant_id",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_contact",
                schema: "core_platform",
                table: "cp_users",
                column: "contact",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_users",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_deleted_by_tenant_id",
                schema: "core_platform",
                table: "cp_users",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_email",
                schema: "core_platform",
                table: "cp_users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_tenant_id",
                schema: "core_platform",
                table: "cp_users",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_cp_users_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_users",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "cp_activity_logs",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_app_features",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_app_subscription_histories",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_app_tier_configs",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_assign_roles",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_billings_logs",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_change_password_policy",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_document_paths",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_enterprise_subscriptions",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_expense",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_expenses_history",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_group_locations",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_login_settings",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_members",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_multi_factor_settings",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_notification_email_credentials",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_otps",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_password_policies",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_resource_deletion_chat_histories",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_role_permissions",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_shared_resource_ids",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_tenant_owners_registry",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_themes",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_unit_of_measures",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_user_groups",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_user_locations",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_user_login_tracking",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_app_subscriptions",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_currencies",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_permissions",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_roles",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_groups",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_business_app_locations",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_subscriptions",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_resource_types",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_business_apps",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_locations",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_businesses",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_apps",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_organizations",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_users",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_tenants",
                schema: "core_platform");
        }
    }
}
