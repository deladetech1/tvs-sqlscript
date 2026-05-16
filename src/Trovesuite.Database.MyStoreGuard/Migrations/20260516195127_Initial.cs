using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "mystoreguard");

            migrationBuilder.CreateTable(
                name: "msg_activity_logs",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
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
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_activity_logs", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_msg_activity_logs_cp_resource_types_resource_type",
                        column: x => x.resource_type,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_activity_logs_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_affiliates",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    affiliate_code = table.Column<string>(type: "text", nullable: false),
                    affiliate_name = table.Column<string>(type: "text", nullable: false),
                    contact_email = table.Column<string>(type: "text", nullable: true),
                    contact_phone = table.Column<string>(type: "text", nullable: true),
                    commission_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    commission_type = table.Column<string>(type: "text", nullable: false, defaultValue: "PERCENTAGE"),
                    fixed_commission_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "ACTIVE"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    total_referrals = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    total_conversions = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    total_commission_earned = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    total_commission_paid = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    description = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    applicable_to_locations = table.Column<string[]>(type: "text[]", nullable: true),
                    applicable_to_products = table.Column<string[]>(type: "text[]", nullable: true),
                    applicable_to_product_metadata = table.Column<string[]>(type: "text[]", nullable: true),
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
                    table.PrimaryKey("ak_affiliates_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_affiliates_commission_type", "commission_type IN ('PERCENTAGE','FIXED_AMOUNT')");
                    table.CheckConstraint("ck_msg_affiliates_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_affiliates_status", "status IN ('ACTIVE','INACTIVE','SUSPENDED')");
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliates_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_appointments",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    appointment_type = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    is_walk_in = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    assigned_to = table.Column<string>(type: "text", nullable: true),
                    start_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    end_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_appointments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_appointments_appointment_type", "appointment_type IN ('SALES','SERVICE','DELIVERY','INSTALLATION','CONSULTATION','OTHERS')");
                    table.CheckConstraint("ck_msg_appointments_status", "status IN ('PENDING','CONFIRMED','IN_PROGRESS','COMPLETED','NO_SHOW','CANCELLED','RESCHEDULED')");
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_users_assigned_to_tenant_id",
                        columns: x => new { x.assigned_to, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_appointments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_customers",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: true),
                    contact = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_customers_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_customers_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_customers_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_document_paths",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    document_path = table.Column<string>(type: "text", nullable: false),
                    file_name = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_document_paths", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_document_paths_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_document_paths_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_meetings",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    title = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    location = table.Column<string>(type: "text", nullable: true),
                    meeting_date = table.Column<string>(type: "text", nullable: false),
                    start_time = table.Column<string>(type: "text", nullable: false),
                    end_time = table.Column<string>(type: "text", nullable: true),
                    start_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    end_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    participant_type = table.Column<string>(type: "text", nullable: false),
                    reminder_minutes = table.Column<int>(type: "integer", nullable: false, defaultValue: 30),
                    reminder_channel = table.Column<string>(type: "text", nullable: false, defaultValue: "SMS"),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "SCHEDULED"),
                    reminder_picked_up_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    reminder_sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_meetings", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_meetings_participant_type", "participant_type IN ('SUPPLIER','CUSTOMER')");
                    table.CheckConstraint("ck_msg_meetings_reminder_channel", "reminder_channel IN ('SMS','EMAIL','WHATSAPP')");
                    table.CheckConstraint("ck_msg_meetings_status", "status IN ('SCHEDULED','REMINDER_SENT','IN_PROGRESS','COMPLETED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meetings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_messages",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    subject = table.Column<string>(type: "varchar(255)", nullable: false),
                    body = table.Column<string>(type: "text", nullable: false),
                    channel = table.Column<string>(type: "text", nullable: false, defaultValue: "SMS"),
                    recipient_type = table.Column<string>(type: "text", nullable: false),
                    scheduled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "DRAFT"),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    picked_up_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_messages", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_messages_channel", "channel IN ('SMS','EMAIL','WHATSAPP')");
                    table.CheckConstraint("ck_msg_messages_recipient_type", "recipient_type IN ('SUPPLIER','CUSTOMER')");
                    table.CheckConstraint("ck_msg_messages_status", "status IN ('DRAFT','SCHEDULED','QUEUED','SENDING','SENT','FAILED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_messages_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_pricing_rule",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    rule_category = table.Column<string>(type: "text", nullable: false),
                    rule_type = table.Column<string>(type: "text", nullable: false),
                    rule_target_type = table.Column<string>(type: "text", nullable: false),
                    rule_target_id = table.Column<string>(type: "text", nullable: true),
                    quantity_min = table.Column<int>(type: "integer", nullable: true),
                    quantity_max = table.Column<int>(type: "integer", nullable: true),
                    discount_value = table.Column<decimal>(type: "numeric(10,2)", nullable: true),
                    discount_percent = table.Column<decimal>(type: "numeric(5,2)", nullable: true),
                    free_qty = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    stops_other_rules = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    priority = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    start_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    end_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_pricing_rule", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_pricing_rule_rule_category", "rule_category IN ('PRICE_ADJUSTMENT','QUANTITY_BASED')");
                    table.CheckConstraint("ck_msg_pricing_rule_rule_target_type", "rule_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL')");
                    table.CheckConstraint("ck_msg_pricing_rule_rule_type", "rule_type IN ('FIXED_AMOUNT','PRICE_DISCOUNT','PERCENTAGE_DISCOUNT','PRICE_MARKUP','PERCENTAGE_MARKUP','BUNDLE','BOGO','QUANTITY_BREAK')");
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_pricing_rule_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_metadata",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    of_type = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_product_metadata_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_metadata_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_product_metadata_of_type", "of_type IN ('TAG','CATEGORY','BRAND','LABEL')");
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_metadata_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_products",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    sku = table.Column<string>(type: "text", nullable: true),
                    bar_code = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_products_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_products_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_products_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_products_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_products_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_products_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_products_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_promo_codes",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    promo_code = table.Column<string>(type: "text", nullable: false),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    discount_type = table.Column<string>(type: "text", nullable: false),
                    discount_value = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    min_purchase_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    max_discount_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    usage_limit_per_customer = table.Column<int>(type: "integer", nullable: true),
                    total_usage_limit = table.Column<int>(type: "integer", nullable: true),
                    current_usage_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    start_date = table.Column<DateOnly>(type: "date", nullable: true, defaultValueSql: "CURRENT_DATE"),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "ACTIVE"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    applicable_to_customers_only = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    applicable_to_locations = table.Column<string[]>(type: "text[]", nullable: false),
                    applicable_to_products = table.Column<string[]>(type: "text[]", nullable: true),
                    applicable_to_product_metadata = table.Column<string[]>(type: "text[]", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("ak_promo_codes_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_promo_codes_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_promo_codes_discount_type", "discount_type IN ('PERCENTAGE','FIXED_AMOUNT','FREE_SHIPPING')");
                    table.CheckConstraint("ck_msg_promo_codes_status", "status IN ('ACTIVE','INACTIVE','EXPIRED')");
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_codes_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_purchase_batches",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    supplier_id = table.Column<string>(type: "text", nullable: true),
                    batch_number = table.Column<string>(type: "text", nullable: false),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    cost_price = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    base_selling_price = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    product_size = table.Column<string>(type: "text", nullable: true),
                    unit_of_measure_id = table.Column<string>(type: "text", nullable: true),
                    product_expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                    qty_ordered = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    qty_received = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    qty_remaining_for_purchase_order = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    qty_remaining = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    batch_type = table.Column<string>(type: "text", nullable: false, defaultValue: "PURCHASE"),
                    status = table.Column<string>(type: "text", nullable: false),
                    received_date = table.Column<DateOnly>(type: "date", nullable: true, defaultValueSql: "CURRENT_DATE"),
                    received_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true, defaultValueSql: "CURRENT_TIME"),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: false),
                    ctime = table.Column<string>(type: "text", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_purchase_batches_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_purchase_batches_batch_type", "batch_type IN ('OPENING_STOCK','ADJUSTMENT','PURCHASE')");
                    table.CheckConstraint("ck_msg_purchase_batches_delete_status", "delete_status IN ('NOT_DELETED','DELETED')");
                    table.CheckConstraint("ck_msg_purchase_batches_status", "status IN ('OPENING_STOCK','RECEIVED','PARTIALLY_ALLOCATED','FULLY_ALLOCATED','VOID','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_batches_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_return_policies",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    policy_target_type = table.Column<string>(type: "text", nullable: false),
                    policy_target_id = table.Column<string>(type: "text", nullable: true),
                    return_window_days = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    condition_required = table.Column<string>(type: "text", nullable: false, defaultValue: "ANY"),
                    receipt_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    allow_expired_returns = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    restocking_fee_percent = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    refund_method = table.Column<string>(type: "text", nullable: false, defaultValue: "ANY"),
                    approval_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    approvers = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    approval_threshold_amount = table.Column<decimal>(type: "numeric(10,2)", nullable: true),
                    stops_other_policies = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    priority = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    start_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    end_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_return_policies", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_return_policies_condition_required", "condition_required IN ('ANY','UNOPENED','WITH_TAGS','UNDAMAGED')");
                    table.CheckConstraint("ck_msg_return_policies_policy_target_type", "policy_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL')");
                    table.CheckConstraint("ck_msg_return_policies_refund_method", "refund_method IN ('ORIGINAL_PAYMENT','STORE_CREDIT','CASH','ANY')");
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_policies_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_stock_taking_audit",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    start_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    next_stock_take_datetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_stock_taking_audit", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id });
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_stock_taking_audit_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_store_configs",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    store_name = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    is_visible_on_ecommerce = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    address = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    manager_id = table.Column<string>(type: "text", nullable: true),
                    enable_auto_stock_take = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    num_of_days_to_take_stock = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    enable_daily_sales_reports = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    openning_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    closing_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    lock_based_on_closing_time = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    change_to_card = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    enable_out_of_stock_notification = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    out_of_stock_notification_email = table.Column<string>(type: "text", nullable: true),
                    out_of_stock_notification_occurrence = table.Column<int>(type: "integer", nullable: true),
                    sales_notification_emails = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_store_configs", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id });
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_users_manager_id_tenant_id",
                        columns: x => new { x.manager_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_store_configs_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_suppliers",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: true),
                    contact = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_suppliers_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_suppliers_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_suppliers_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_taxes",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false),
                    is_inclusive = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
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
                    table.PrimaryKey("pk_msg_taxes", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_taxes_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_warehouse_configs",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    warehouse_name = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    aadress = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    manager_id = table.Column<string>(type: "text", nullable: true),
                    openning_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    closing_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    change_to_card = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    enable_out_of_stock_notification = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    out_of_stock_notification_email = table.Column<string>(type: "text", nullable: true),
                    out_of_stock_notification_occurrence = table.Column<int>(type: "integer", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_warehouse_configs", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id });
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_users_manager_id_tenant_id",
                        columns: x => new { x.manager_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_configs_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_gift_cards",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    gift_card_code = table.Column<string>(type: "text", nullable: false),
                    initial_value = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    current_balance = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "ACTIVE"),
                    expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                    purchase_date = table.Column<DateOnly>(type: "date", nullable: true, defaultValueSql: "CURRENT_DATE"),
                    purchased_by_customer_id = table.Column<string>(type: "text", nullable: true),
                    purchased_by_user_id = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    applicable_to_locations = table.Column<string[]>(type: "text[]", nullable: true),
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
                    table.PrimaryKey("pk_msg_gift_cards", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_gift_cards_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_gift_cards_status", "status IN ('ACTIVE','USED','EXPIRED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_users_purchased_by_user_id_tenant_id",
                        columns: x => new { x.purchased_by_user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_cards_msg_customers_tenant_id_org_id_bus_id_purcha",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.purchased_by_customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_meeting_participants",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    meeting_id = table.Column<string>(type: "text", nullable: false),
                    participant_type = table.Column<string>(type: "text", nullable: false),
                    participant_id = table.Column<string>(type: "text", nullable: false),
                    participant_name = table.Column<string>(type: "text", nullable: true),
                    participant_email = table.Column<string>(type: "text", nullable: true),
                    participant_contact = table.Column<string>(type: "text", nullable: true),
                    rsvp_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    reminder_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    reminder_failure_reason = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_meeting_participants", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_meeting_participants_participant_type", "participant_type IN ('SUPPLIER','CUSTOMER')");
                    table.CheckConstraint("ck_msg_meeting_participants_reminder_status", "reminder_status IN ('PENDING','SENT','DELIVERED','FAILED')");
                    table.CheckConstraint("ck_msg_meeting_participants_rsvp_status", "rsvp_status IN ('PENDING','ACCEPTED','DECLINED')");
                    table.ForeignKey(
                        name: "fk_msg_meeting_participants_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meeting_participants_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meeting_participants_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_meeting_participants_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_meeting_participants_msg_meetings_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.meeting_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_meetings",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_message_recipients",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    message_id = table.Column<string>(type: "text", nullable: false),
                    recipient_type = table.Column<string>(type: "text", nullable: false),
                    recipient_id = table.Column<string>(type: "text", nullable: false),
                    recipient_name = table.Column<string>(type: "text", nullable: true),
                    recipient_email = table.Column<string>(type: "text", nullable: true),
                    recipient_contact = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    failure_reason = table.Column<string>(type: "text", nullable: true),
                    delivered_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_message_recipients", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_message_recipients_recipient_type", "recipient_type IN ('SUPPLIER','CUSTOMER')");
                    table.CheckConstraint("ck_msg_message_recipients_status", "status IN ('PENDING','SENT','DELIVERED','FAILED')");
                    table.ForeignKey(
                        name: "fk_msg_message_recipients_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_message_recipients_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_message_recipients_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_message_recipients_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_message_recipients_msg_messages_tenant_id_org_id_bus_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.message_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_messages",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_assign_metadata_to_products",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_metadata_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_assign_metadata_to_products", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_cp_users_created_by_tenant_",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_cp_users_deleted_by_tenant_",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_cp_users_updated_by_tenant_",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_product_metadata_tenant_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_metadata_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_product_metadata",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_assign_metadata_to_products_products_tenant_id_org_id_b",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_open_and_closing_stock",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    period_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    period_type = table.Column<string>(type: "text", nullable: false, defaultValue: "DAILY"),
                    opening_stock = table.Column<int>(type: "integer", nullable: false),
                    closing_stock = table.Column<int>(type: "integer", nullable: false),
                    total_stock_in = table.Column<int>(type: "integer", nullable: false),
                    total_stock_out = table.Column<int>(type: "integer", nullable: false),
                    total_sales_quantity = table.Column<int>(type: "integer", nullable: false),
                    total_sales_value = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    total_purchase_quantity = table.Column<int>(type: "integer", nullable: false),
                    total_purchase_value = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_open_and_closing_stock", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_open_and_closing_stock_period_type", "period_type IN ('DAILY','MONTHLY')");
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_open_and_closing_stock_products_tenant_id_org_id_bus_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_document_ids",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_document_ids", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_document_ids_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_msg_document_paths_tenant_id_org_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.document_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_document_paths",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_document_ids_msg_products_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_prices",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    of_type = table.Column<string>(type: "text", nullable: false),
                    target_id = table.Column<string>(type: "text", nullable: true),
                    price = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    priority = table.Column<int>(type: "integer", nullable: false),
                    stops_other_prices = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_prices", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_prices_of_type", "of_type IN ('SKU','GLOBAL','LOCATION','TAG','CATEGORY','BRAND','LABEL')");
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_currencies_currency_tenant_id",
                        columns: x => new { x.currency, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_prices_msg_products_tenant_id_org_id_bus_id_pro",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_transfers",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    source = table.Column<string>(type: "text", nullable: false),
                    source_id = table.Column<string>(type: "text", nullable: false),
                    destination = table.Column<string>(type: "text", nullable: false),
                    destination_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING_APPROVAL"),
                    description = table.Column<string>(type: "text", nullable: true),
                    qty = table.Column<int>(type: "integer", nullable: false),
                    transfer_number = table.Column<string>(type: "text", nullable: false),
                    person_to_approve_id = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_transfers", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_transfers_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_msg_product_transfers_destination", "destination IN ('STORE','WAREHOUSE')");
                    table.CheckConstraint("ck_msg_product_transfers_source", "source IN ('STORE','WAREHOUSE')");
                    table.CheckConstraint("ck_msg_product_transfers_status", "status IN ('PENDING_APPROVAL','APPROVED','REJECTED','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_cp_locations_destination_id_tenant_id",
                        columns: x => new { x.destination_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_cp_locations_source_id_tenant_id",
                        columns: x => new { x.source_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_cp_users_person_to_approve_id_tenant_",
                        columns: x => new { x.person_to_approve_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_transfers_msg_products_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_store_products",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    current_qty = table.Column<int>(type: "integer", nullable: false),
                    comment = table.Column<string>(type: "text", nullable: true),
                    reorder_level = table.Column<int>(type: "integer", nullable: false),
                    reorder_quantity = table.Column<int>(type: "integer", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_store_products", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.product_id });
                    table.CheckConstraint("ck_msg_store_products_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_store_products_msg_products_tenant_id_org_id_bus_id_pro",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_warehouse_products",
                schema: "mystoreguard",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: true, defaultValueSql: "gen_random_uuid()::text"),
                    current_qty = table.Column<int>(type: "integer", nullable: false),
                    comment = table.Column<string>(type: "text", nullable: true),
                    reorder_level = table.Column<int>(type: "integer", nullable: false),
                    reorder_quantity = table.Column<int>(type: "integer", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_warehouse_products", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.product_id });
                    table.CheckConstraint("ck_msg_warehouse_products_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_warehouse_products_msg_products_tenant_id_org_id_bus_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_invoices",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    invoice_number = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: false),
                    sale_date = table.Column<DateOnly>(type: "date", nullable: false, defaultValueSql: "CURRENT_DATE"),
                    due_date = table.Column<DateOnly>(type: "date", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    sale_mode = table.Column<string>(type: "text", nullable: false, defaultValue: "INSTANT"),
                    description = table.Column<string>(type: "text", nullable: true),
                    total_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    balance_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    gift_card_amount_used = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    promo_code_id = table.Column<string>(type: "text", nullable: true),
                    promo_discount_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    affiliate_id = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_invoices", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_invoices_sale_mode", "sale_mode IN ('INSTANT','DEPOSIT','CREDIT')");
                    table.CheckConstraint("ck_msg_invoices_status", "status IN ('DRAFT','COMPLETED','PARTIALLY_PAID','OVERDUE','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_msg_affiliates_tenant_id_org_id_bus_id_affilia",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.affiliate_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_affiliates",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_invoices_msg_customers_tenant_id_org_id_bus_id_customer",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoices_promo_codes_tenant_id_org_id_bus_id_promo_code",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.promo_code_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_promo_codes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_sales",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_number = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    sale_date = table.Column<DateOnly>(type: "date", nullable: false, defaultValueSql: "CURRENT_DATE"),
                    status = table.Column<string>(type: "text", nullable: false),
                    sale_mode = table.Column<string>(type: "text", nullable: false),
                    fulfillment_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    fulfillment_date_time = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    description = table.Column<string>(type: "text", nullable: true),
                    total_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    balance_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    gift_card_amount_used = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    promo_code_id = table.Column<string>(type: "text", nullable: true),
                    promo_discount_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    affiliate_id = table.Column<string>(type: "text", nullable: true),
                    taxes_applied = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_sales_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_sales_fulfillment_status", "fulfillment_status IN ('PENDING','PARTIALLY_FULFILLED','FULFILLED')");
                    table.CheckConstraint("ck_msg_sales_sale_mode", "sale_mode IN ('INSTANT','DEPOSIT','CREDIT')");
                    table.CheckConstraint("ck_msg_sales_status", "status IN ('ON_HOLD','PAID','PARTIALLY_PAID','OVERDUE','CANCELLED','QUEUED')");
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_msg_affiliates_tenant_id_org_id_bus_id_affiliate_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.affiliate_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_affiliates",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_sales_msg_customers_tenant_id_org_id_bus_id_customer_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_msg_promo_codes_tenant_id_org_id_bus_id_promo_cod",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.promo_code_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_promo_codes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_batch_locations",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    purchase_batche_id = table.Column<string>(type: "text", nullable: true),
                    location_type = table.Column<string>(type: "text", nullable: false),
                    qty = table.Column<int>(type: "integer", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_batch_locations", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_batch_locations_location_type", "location_type IN ('STORE','WAREHOUSE')");
                    table.ForeignKey(
                        name: "fk_msg_batch_locations_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_batch_locations_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_batch_locations_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_batch_locations_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_batch_locations_purchase_batches_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.purchase_batche_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_batches",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_product_movements",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: true),
                    location_type = table.Column<string>(type: "text", nullable: true),
                    location_id = table.Column<string>(type: "text", nullable: true),
                    movement_type = table.Column<string>(type: "text", nullable: false),
                    qty = table.Column<int>(type: "integer", nullable: false),
                    reason = table.Column<string>(type: "text", nullable: true),
                    reference_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_product_movements", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_product_movements_location_type", "location_type IN ('STORE','WAREHOUSE','SYSTEM',NULL)");
                    table.CheckConstraint("ck_msg_product_movements_movement_type", "movement_type IN ('IN','OUT','TRANSFER','REVERSAL')");
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_msg_products_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_product_movements_purchase_batches_tenant_id_org_id_bus",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.batch_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_batches",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_purchase_orders",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    supplier_id = table.Column<string>(type: "text", nullable: false),
                    po_number = table.Column<string>(type: "text", nullable: false),
                    assign_to = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    order_date = table.Column<DateOnly>(type: "date", nullable: false),
                    expected_delivery_date = table.Column<DateOnly>(type: "date", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_purchase_orders", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_purchase_orders_status", "status IN ('DRAFT','APPROVED','PARTIALLY_RECEIVED','CANCELLED','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_msg_purchase_orders_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_purchase_orders_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_orders_suppliers_tenant_id_org_id_bus_id_suppl",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.supplier_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_suppliers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_tax_rule",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    tax_id = table.Column<string>(type: "text", nullable: false),
                    rule_type = table.Column<string>(type: "text", nullable: false),
                    rule_target_id = table.Column<string>(type: "text", nullable: true),
                    priority = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
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
                    table.PrimaryKey("ak_tax_rules_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_tax_rule_rule_type", "rule_type IN ('PRODUCT','ALL_PRODUCTS','CATEGORY','TAG','BRAND','LABEL','LOCATION','SKU')");
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_tax_rule_msg_taxes_tenant_id_org_id_bus_id_tax_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.tax_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_taxes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_invoice_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    invoice_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: true),
                    product_name = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    base_selling_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    actual_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    price_after_pricing_rule = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    price_after_tax = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    final_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    quantity = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    line_total = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    tax_rate = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    is_inclusive = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    tax_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    taxes_applied = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_invoice_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_invoice_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoice_items_msg_invoices_tenant_id_org_id_bus_id_loc_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.invoice_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_invoices",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoice_items_products_tenant_id_org_id_bus_id_product_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_invoice_items_purchase_batches_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.batch_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_batches",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_invoice_payments",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    invoice_id = table.Column<string>(type: "text", nullable: false),
                    payment_method = table.Column<string>(type: "text", nullable: false),
                    payment_status = table.Column<string>(type: "text", nullable: false),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    gift_card_id = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_invoice_payments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_invoice_payments_payment_method", "payment_method IN ('CASH','CARD','BANK_TRANSFER','MOBILE_MONEY','CHEQUE','BITCOIN','GIFT_CARD','OTHERS')");
                    table.CheckConstraint("ck_msg_invoice_payments_payment_status", "payment_status IN ('SUCCESS','FAILED','PENDING','REFUNDED')");
                    table.ForeignKey(
                        name: "fk_msg_invoice_payments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoice_payments_msg_gift_cards_tenant_id_org_id_bus_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.gift_card_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_gift_cards",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_invoice_payments_msg_invoices_tenant_id_org_id_bus_id_l",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.invoice_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_invoices",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_affiliate_referrals",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    affiliate_id = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    sale_id = table.Column<string>(type: "text", nullable: true),
                    referral_date = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    conversion_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    conversion_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    sale_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: true),
                    commission_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    commission_paid = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    commission_paid_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    referral_source = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_affiliate_referrals_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_affiliate_referrals_conversion_status", "conversion_status IN ('PENDING','CONVERTED','FAILED','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_customers_tenant_id_org_id_bus_id_c",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_msg_affiliates_tenant_id_org_id_bus",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.affiliate_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_affiliates",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_referrals_sales_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_deliveries",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    delivery_number = table.Column<string>(type: "text", nullable: false),
                    delivery_status = table.Column<string>(type: "text", nullable: false),
                    delivery_type = table.Column<string>(type: "text", nullable: false),
                    scheduled_date = table.Column<DateOnly>(type: "date", nullable: true),
                    dispatched_at = table.Column<DateTime>(type: "timestamp", nullable: true),
                    delivered_at = table.Column<DateTime>(type: "timestamp", nullable: true),
                    delivery_fee = table.Column<decimal>(type: "numeric(12,2)", nullable: false, defaultValue: 0m),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    is_paid = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    recipient_name = table.Column<string>(type: "text", nullable: false),
                    recipient_phone = table.Column<string>(type: "text", nullable: true),
                    delivery_address = table.Column<string>(type: "text", nullable: false),
                    delivery_notes = table.Column<string>(type: "text", nullable: true),
                    driver_id = table.Column<string>(type: "text", nullable: true),
                    third_party_name = table.Column<string>(type: "text", nullable: true),
                    tracking_number = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: false),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true, defaultValueSql: "CURRENT_DATE::TEXT"),
                    ctime = table.Column<string>(type: "text", nullable: true, defaultValueSql: "CURRENT_TIME::TEXT"),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_deliveries", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_deliveries_delivery_status", "delivery_status IN ('PENDING','SCHEDULED','OUT_FOR_DELIVERY','DELIVERED','FAILED','CANCELLED')");
                    table.CheckConstraint("ck_msg_deliveries_delivery_type", "delivery_type IN ('INTERNAL','THIRD_PARTY','CUSTOMER_PICKUP')");
                    table.CheckConstraint("ck_msg_deliveries_type_consistency", "(delivery_type = 'INTERNAL' AND driver_id IS NOT NULL) OR (delivery_type = 'THIRD_PARTY' AND third_party_name IS NOT NULL) OR (delivery_type = 'CUSTOMER_PICKUP')");
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_users_driver_id_tenant_id",
                        columns: x => new { x.driver_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_deliveries_sales_tenant_id_org_id_bus_id_loc_id_sale_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_gift_card_transactions",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: true),
                    gift_card_id = table.Column<string>(type: "text", nullable: false),
                    transaction_type = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    balance_before = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    balance_after = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: true),
                    payment_id = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_gift_card_transactions", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_gift_card_transactions_transaction_type", "transaction_type IN ('PURCHASE','REDEMPTION','REFUND','ADJUSTMENT','EXPIRY')");
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_msg_gift_cards_tenant_id_org_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.gift_card_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_gift_cards",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_gift_card_transactions_sales_tenant_id_org_id_bus_id_lo",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_invoice_sales",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    invoice_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_invoice_sales", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_invoice_sales_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoice_sales_msg_invoices_tenant_id_org_id_bus_id_loc_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.invoice_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_invoices",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_invoice_sales_sales_tenant_id_org_id_bus_id_loc_id_sale",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_promo_code_usage",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    promo_code_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    discount_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    sale_total_before_discount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    sale_total_after_discount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_promo_code_usage", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_msg_customers_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_msg_promo_codes_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.promo_code_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_promo_codes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_promo_code_usage_sales_tenant_id_org_id_bus_id_loc_id_s",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_returns",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    return_number = table.Column<string>(type: "text", nullable: false),
                    return_date = table.Column<string>(type: "text", nullable: true),
                    return_type = table.Column<string>(type: "text", nullable: false, defaultValue: "REFUND"),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    reason = table.Column<string>(type: "text", nullable: false, defaultValue: "CUSTOMER_CHANGED_MIND"),
                    reason_notes = table.Column<string>(type: "text", nullable: true),
                    refund_method = table.Column<string>(type: "text", nullable: false, defaultValue: "ORIGINAL_PAYMENT"),
                    subtotal_refund_amount = table.Column<decimal>(type: "numeric(10,2)", nullable: false, defaultValue: 0m),
                    restocking_fee_percent = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    restocking_fee_amount = table.Column<decimal>(type: "numeric(10,2)", nullable: false, defaultValue: 0m),
                    total_refund_amount = table.Column<decimal>(type: "numeric(10,2)", nullable: false, defaultValue: 0m),
                    return_policy_id = table.Column<string>(type: "text", nullable: true),
                    approval_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    approved_by = table.Column<string>(type: "text", nullable: true),
                    approved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    rejected_by = table.Column<string>(type: "text", nullable: true),
                    rejected_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    rejection_reason = table.Column<string>(type: "text", nullable: true),
                    processed_by = table.Column<string>(type: "text", nullable: true),
                    processed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    processing_notes = table.Column<string>(type: "text", nullable: true),
                    customer_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_returns", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_returns_reason", "reason IN ('DEFECTIVE','WRONG_ITEM','CUSTOMER_CHANGED_MIND','EXPIRED','DAMAGED_IN_TRANSIT','OTHER')");
                    table.CheckConstraint("ck_msg_returns_refund_method", "refund_method IN ('ORIGINAL_PAYMENT','STORE_CREDIT','CASH','ANY')");
                    table.CheckConstraint("ck_msg_returns_return_type", "return_type IN ('REFUND','EXCHANGE','STORE_CREDIT')");
                    table.CheckConstraint("ck_msg_returns_status", "status IN ('PENDING','APPROVED','REJECTED','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_users_approved_by_tenant_id",
                        columns: x => new { x.approved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_users_processed_by_tenant_id",
                        columns: x => new { x.processed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_users_rejected_by_tenant_id",
                        columns: x => new { x.rejected_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_returns_sales_tenant_id_org_id_bus_id_loc_id_sale_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_sales_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: false),
                    product_name = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    base_selling_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    actual_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    price_after_pricing_rule = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    price_after_tax = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    final_price = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    quantity = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    line_total = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    tax_rate = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    is_inclusive = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    tax_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    taxes_applied = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_sale_items_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_sales_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_sales_items_msg_products_tenant_id_org_id_bus_id_produc",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_items_msg_purchase_batches_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.batch_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_batches",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sales_items_msg_sales_tenant_id_org_id_bus_id_loc_id_sa",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_sales_payments",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    payment_method = table.Column<string>(type: "text", nullable: false),
                    payment_status = table.Column<string>(type: "text", nullable: false),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    gift_card_id = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_sales_payments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_sales_payments_payment_method", "payment_method IN ('CASH','CARD','BANK_TRANSFER','MOBILE_MONEY','CHEQUE','BITCOIN','GIFT_CARD','OTHERS')");
                    table.CheckConstraint("ck_msg_sales_payments_payment_status", "payment_status IN ('SUCCESS','FAILED','PENDING','REFUNDED')");
                    table.ForeignKey(
                        name: "fk_msg_sales_payments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_sales_payments_msg_gift_cards_tenant_id_org_id_bus_id_g",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.gift_card_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_gift_cards",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_sales_payments_msg_sales_tenant_id_org_id_bus_id_loc_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_purchase_order_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    purchase_order_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    qty_ordered = table.Column<int>(type: "integer", nullable: false),
                    qty_received = table.Column<int>(type: "integer", nullable: false),
                    qty_remaining = table.Column<int>(type: "integer", nullable: false),
                    currency_id = table.Column<string>(type: "text", nullable: false),
                    cost_price = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    base_selling_price = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    product_size = table.Column<string>(type: "text", nullable: true),
                    unit_of_measure_id = table.Column<string>(type: "text", nullable: true),
                    product_expiry_date = table.Column<DateOnly>(type: "date", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_purchase_order_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_purchase_order_items_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_order_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_purchase_order_items_cp_unit_of_measures_unit_of_measur",
                        columns: x => new { x.unit_of_measure_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_unit_of_measures",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_order_items_msg_products_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_order_items_msg_purchase_orders_tenant_id_org_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.purchase_order_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_orders",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_purchase_receipts",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    purchase_order_id = table.Column<string>(type: "text", nullable: false),
                    receipt_number = table.Column<string>(type: "text", nullable: false),
                    received_date = table.Column<DateOnly>(type: "date", nullable: false, defaultValueSql: "CURRENT_DATE"),
                    description = table.Column<string>(type: "text", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_purchase_receipts", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_purchase_receipts_status", "status IN ('DRAFT','APPROVED','PARTIALLY_RECEIVED','CANCELLED','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_msg_purchase_receipts_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_purchase_receipts_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_receipts_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_receipts_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_purchase_receipts_msg_purchase_orders_tenant_id_org_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.purchase_order_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_purchase_orders",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "tax_rule_conditions",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    tax_id = table.Column<string>(type: "text", nullable: false),
                    tax_rule_id = table.Column<string>(type: "text", nullable: false),
                    priority = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    condition_type = table.Column<string>(type: "text", nullable: false),
                    condition = table.Column<string>(type: "text", nullable: false),
                    comparison_operator = table.Column<string>(type: "text", nullable: false),
                    comparison_value = table.Column<decimal>(type: "numeric(10,2)", nullable: false),
                    adjustment_value = table.Column<decimal>(type: "numeric(10,2)", nullable: true),
                    adjustment_percentage = table.Column<decimal>(type: "numeric(5,2)", nullable: true),
                    logical_operator = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_tax_rule_conditions", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_tax_rule_conditions_comparison_operator", "comparison_operator IN ('EQUALS','NOT_EQUALS','GREATER_THAN','LESS_THAN','GREATER_THAN_OR_EQUALS','LESS_THAN_OR_EQUALS')");
                    table.CheckConstraint("ck_tax_rule_conditions_condition", "condition IN ('IF_ITEM_PRICE','IF_TOTAL_PRICE','IF_ITEM_QTY')");
                    table.CheckConstraint("ck_tax_rule_conditions_condition_type", "condition_type IN ('TAX_EXEMPTION','TAX_REDUCTION')");
                    table.CheckConstraint("ck_tax_rule_conditions_logical_operator", "logical_operator IN ('AND','OR')");
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_msg_taxes_tenant_id_org_id_bus_id_tax_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.tax_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_taxes",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_tax_rule_conditions_tax_rules_tenant_id_org_id_bus_id_tax_r",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.tax_rule_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tax_rule",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_affiliate_commissions",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: true),
                    affiliate_id = table.Column<string>(type: "text", nullable: false),
                    referral_id = table.Column<string>(type: "text", nullable: true),
                    sale_id = table.Column<string>(type: "text", nullable: true),
                    commission_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    payment_status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    paid_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    payment_method = table.Column<string>(type: "text", nullable: true),
                    payment_reference = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_affiliate_commissions", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_affiliate_commissions_payment_status", "payment_status IN ('PENDING','PAID','CANCELLED')");
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_affiliate_referrals_tenant_id_org",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.referral_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_affiliate_referrals",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_affiliates_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.affiliate_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_affiliates",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_affiliate_commissions_sales_tenant_id_org_id_bus_id_loc",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_delivery_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    delivery_id = table.Column<string>(type: "text", nullable: false),
                    sale_item_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    ordered_qty = table.Column<decimal>(type: "numeric(12,3)", nullable: false),
                    delivered_qty = table.Column<decimal>(type: "numeric(12,3)", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: false),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true, defaultValueSql: "CURRENT_DATE::TEXT"),
                    ctime = table.Column<string>(type: "text", nullable: true, defaultValueSql: "CURRENT_TIME::TEXT"),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_delivery_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_msg_deliveries_tenant_id_org_id_bus_id_l",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.delivery_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_deliveries",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_products_tenant_id_org_id_bus_id_product",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_delivery_items_sale_items_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_item_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales_items",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_return_items",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    return_id = table.Column<string>(type: "text", nullable: false),
                    sale_item_id = table.Column<string>(type: "text", nullable: false),
                    product_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: true),
                    quantity_returned = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    condition = table.Column<string>(type: "text", nullable: false, defaultValue: "RESALABLE"),
                    restock = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    unit_refund_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    line_refund_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    reason = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_return_items", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_return_items_condition", "condition IN ('RESALABLE','DAMAGED','EXPIRED','OPENED','WRITE_OFF')");
                    table.ForeignKey(
                        name: "fk_msg_return_items_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_return_items_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_items_msg_products_tenant_id_org_id_bus_id_produ",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.product_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_products",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_return_items_msg_returns_tenant_id_org_id_bus_id_loc_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.return_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_returns",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_return_items_sale_items_tenant_id_org_id_bus_id_loc_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_item_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales_items",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_activity_logs_resource_type",
                schema: "mystoreguard",
                table: "msg_activity_logs",
                column: "resource_type");

            migrationBuilder.CreateIndex(
                name: "ix_msg_activity_logs_tenant_id",
                schema: "mystoreguard",
                table: "msg_activity_logs",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_tenant_id_org_id_bus_id_affiliate",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_tenant_id_org_id_bus_id_loc_id_re",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "referral_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_tenant_id_org_id_bus_id_loc_id_sa",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_commissions_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_tenant_id_org_id_bus_id_affiliate_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_tenant_id_org_id_bus_id_loc_id_sale",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliate_referrals_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_tenant_id_org_id_bus_id_affiliate_code",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_affiliates_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliates",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_assigned_to_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "assigned_to", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_appointments_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_appointments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_assign_metadata_to_products_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_assign_metadata_to_products_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_assign_metadata_to_products_tenant_id_org_id_bus_id_pro",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_assign_metadata_to_products_tenant_id_org_id_bus_id_pro1",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_metadata_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_assign_metadata_to_products_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_batch_locations_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_batch_locations",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_batch_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_batch_locations",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_batch_locations_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_batch_locations",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_batch_locations_tenant_id_org_id_bus_id_purchase_batche",
                schema: "mystoreguard",
                table: "msg_batch_locations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchase_batche_id", "location_type", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_tenant_id_org_id_bus_id_contact",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "contact" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_tenant_id_org_id_bus_id_email",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "email" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_customers_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_customers",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_currency_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_driver_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "driver_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_tenant_id_org_id_bus_id_loc_id_delivery_numb",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "delivery_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_deliveries_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_deliveries",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_tenant_id_org_id_bus_id_loc_id_delivery_",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "delivery_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_tenant_id_org_id_bus_id_loc_id_sale_item",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_item_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_delivery_items_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_delivery_items",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_document_paths_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_tenant_id_org_id_bus_id_gift_car",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_card_transactions_tenant_id_org_id_bus_id_loc_id_s",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_currency_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_purchased_by_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "purchased_by_user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_tenant_id_org_id_bus_id_gift_card_code",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_tenant_id_org_id_bus_id_purchased_by_custome",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchased_by_customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_gift_cards_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_items_tenant_id_org_id_bus_id_batch_id",
                schema: "mystoreguard",
                table: "msg_invoice_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "batch_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_items_tenant_id_org_id_bus_id_loc_id_invoice_id",
                schema: "mystoreguard",
                table: "msg_invoice_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "invoice_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_invoice_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_payments_tenant_id_org_id_bus_id_gift_card_id",
                schema: "mystoreguard",
                table: "msg_invoice_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_payments_tenant_id_org_id_bus_id_loc_id_invoice",
                schema: "mystoreguard",
                table: "msg_invoice_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "invoice_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_sales_tenant_id_org_id_bus_id_loc_id_invoice_id",
                schema: "mystoreguard",
                table: "msg_invoice_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "invoice_id", "sale_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoice_sales_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_invoice_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_tenant_id_org_id_bus_id_affiliate_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_tenant_id_org_id_bus_id_loc_id_invoice_number",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "invoice_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_tenant_id_org_id_bus_id_promo_code_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_invoices_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meeting_participants_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_meeting_participants",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meeting_participants_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_meeting_participants",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meeting_participants_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_meeting_participants",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meeting_participants_tenant_id_org_id_bus_id_meeting_id",
                schema: "mystoreguard",
                table: "msg_meeting_participants",
                columns: new[] { "tenant_id", "org_id", "bus_id", "meeting_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meetings_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_meetings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meetings_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_meetings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meetings_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_meetings",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meetings_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_meetings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_meetings_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_meetings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_message_recipients_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_message_recipients",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_message_recipients_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_message_recipients",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_message_recipients_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_message_recipients",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_message_recipients_tenant_id_org_id_bus_id_message_id",
                schema: "mystoreguard",
                table: "msg_message_recipients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "message_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_messages_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_messages",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_messages_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_messages",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_messages_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_messages",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_messages_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_messages",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_messages_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_messages",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_tenant_id_org_id_bus_id_loc_id_p",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "product_id", "period_date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_tenant_id_org_id_bus_id_product_",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_open_and_closing_stock_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_open_and_closing_stock",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_pricing_rule_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_pricing_rule_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_pricing_rule_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_pricing_rule_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_pricing_rule_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_tenant_id_org_id_bus_id_document_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "tenant_id", "org_id", "bus_id", "document_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_document_ids_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_document_ids",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_tenant_id_org_id_bus_id_name_of_type",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "tenant_id", "org_id", "bus_id", "name", "of_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_metadata_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_tenant_id_org_id_bus_id_batch_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "tenant_id", "org_id", "bus_id", "batch_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_movements_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_movements",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_currency_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "currency", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_prices_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_prices",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_destination_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "destination_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_person_to_approve_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "person_to_approve_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_source_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "source_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_product_transfers_tenant_id_org_id_bus_id_transfer_numb",
                schema: "mystoreguard",
                table: "msg_product_transfers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "transfer_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_products_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_code_usage_tenant_id_org_id_bus_id_promo_code_id",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_currency_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_tenant_id_org_id_bus_id_promo_code",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_promo_codes_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_promo_codes",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_batches_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_batches",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_batches_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_batches",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_batches_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_batches",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_batches_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_batches",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_batches_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_batches",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_order_items_currency_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_order_items",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_order_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_purchase_order_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_order_items_tenant_id_org_id_bus_id_purchase_o",
                schema: "mystoreguard",
                table: "msg_purchase_order_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchase_order_id", "product_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_order_items_unit_of_measure_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_order_items",
                columns: new[] { "unit_of_measure_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_orders_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_orders",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_orders_tenant_id_org_id_bus_id_po_number",
                schema: "mystoreguard",
                table: "msg_purchase_orders",
                columns: new[] { "tenant_id", "org_id", "bus_id", "po_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_orders_tenant_id_org_id_bus_id_supplier_id",
                schema: "mystoreguard",
                table: "msg_purchase_orders",
                columns: new[] { "tenant_id", "org_id", "bus_id", "supplier_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_receipts_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_receipts",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_receipts_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_receipts",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_receipts_tenant_id_org_id_bus_id_purchase_orde",
                schema: "mystoreguard",
                table: "msg_purchase_receipts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "purchase_order_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_receipts_tenant_id_org_id_bus_id_receipt_number",
                schema: "mystoreguard",
                table: "msg_purchase_receipts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "receipt_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_purchase_receipts_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_purchase_receipts",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_items_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_items",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_items_tenant_id_org_id_bus_id_loc_id_return_id",
                schema: "mystoreguard",
                table: "msg_return_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "return_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_items_tenant_id_org_id_bus_id_loc_id_sale_item_id",
                schema: "mystoreguard",
                table: "msg_return_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_item_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_return_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_policies_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_policies",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_policies_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_policies",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_policies_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_policies",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_policies_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_policies",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_return_policies_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_return_policies",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_approved_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "approved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_processed_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "processed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_rejected_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "rejected_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_tenant_id_org_id_bus_id_affiliate_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_tenant_id_org_id_bus_id_loc_id_sale_number",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_tenant_id_org_id_bus_id_promo_code_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_items_tenant_id_org_id_bus_id_batch_id",
                schema: "mystoreguard",
                table: "msg_sales_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "batch_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_items_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_sales_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_items_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_sales_items",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_payments_tenant_id_org_id_bus_id_gift_card_id",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sales_payments_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_stock_taking_audit_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_stock_taking_audit",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "manager_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_configs_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_store_products_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_tenant_id_org_id_bus_id_contact",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "contact" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_tenant_id_org_id_bus_id_email",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "email" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_suppliers_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_suppliers",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_tenant_id_org_id_bus_id_tax_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "tenant_id", "org_id", "bus_id", "tax_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_tax_rule_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_tenant_id_org_id_bus_id_name",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "tenant_id", "org_id", "bus_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_taxes_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_taxes",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "manager_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_configs_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_tenant_id_org_id_bus_id_product_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "tenant_id", "org_id", "bus_id", "product_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_warehouse_products_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_created_by_tenant_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_org_id_tenant_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_tenant_id_org_id_bus_id_tax_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "tax_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_tenant_id_org_id_bus_id_tax_rule_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "tax_rule_id" });

            migrationBuilder.CreateIndex(
                name: "ix_tax_rule_conditions_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "tax_rule_conditions",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_activity_logs",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_affiliate_commissions",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_appointments",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_assign_metadata_to_products",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_batch_locations",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_delivery_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_gift_card_transactions",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_invoice_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_invoice_payments",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_invoice_sales",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_meeting_participants",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_message_recipients",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_open_and_closing_stock",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_pricing_rule",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_document_ids",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_movements",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_prices",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_transfers",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_promo_code_usage",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_purchase_order_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_purchase_receipts",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_return_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_return_policies",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_sales_payments",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_stock_taking_audit",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_store_configs",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_store_products",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_warehouse_configs",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_warehouse_products",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "tax_rule_conditions",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_affiliate_referrals",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_product_metadata",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_deliveries",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_invoices",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_meetings",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_messages",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_document_paths",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_purchase_orders",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_returns",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_sales_items",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_gift_cards",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_tax_rule",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_suppliers",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_products",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_purchase_batches",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_sales",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_taxes",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_affiliates",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_customers",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_promo_codes",
                schema: "mystoreguard");
        }
    }
}
