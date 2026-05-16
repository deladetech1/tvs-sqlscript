using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "loandrift");

            migrationBuilder.CreateTable(
                name: "ld_activity_logs",
                schema: "loandrift",
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
                    table.PrimaryKey("pk_ld_activity_logs", x => new { x.id, x.tenant_id });
                    table.ForeignKey(
                        name: "fk_ld_activity_logs_cp_resource_types_resource_type",
                        column: x => x.resource_type,
                        principalSchema: "core_platform",
                        principalTable: "cp_resource_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_activity_logs_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_clients",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: true),
                    contact = table.Column<string>(type: "text", nullable: false),
                    residential_address = table.Column<string>(type: "text", nullable: true),
                    registration_datetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    dob = table.Column<string>(type: "text", nullable: true),
                    marital_status = table.Column<string>(type: "text", nullable: true),
                    occupation = table.Column<string>(type: "text", nullable: true),
                    gender = table.Column<string>(type: "text", nullable: true),
                    id_type = table.Column<string>(type: "text", nullable: true),
                    id_number = table.Column<string>(type: "text", nullable: true),
                    id_issue_date = table.Column<string>(type: "text", nullable: true),
                    id_expiry_date = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("ak_clients_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_clients_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_clients_gender", "gender IN ('MALE','FEMALE','OTHER',NULL)");
                    table.CheckConstraint("ck_ld_clients_id_type", "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT',NULL)");
                    table.CheckConstraint("ck_ld_clients_marital_status", "marital_status IN ('SINGLE','MARRIED','DIVORCED','WIDOWED',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_interest_types",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    interest_type_name = table.Column<string>(type: "text", nullable: false),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
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
                    table.PrimaryKey("pk_ld_interest_types", x => x.id);
                    table.CheckConstraint("ck_ld_interest_types_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_interest_types_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_interest_types_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_interest_types_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_interest_types_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_types",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    type_name = table.Column<string>(type: "text", nullable: false),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
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
                    table.PrimaryKey("pk_ld_loan_types", x => x.id);
                    table.CheckConstraint("ck_ld_loan_types_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_loan_types_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_types_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_types_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_types_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_resource_deletion_chat_histories",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    resource_id = table.Column<string>(type: "text", nullable: true),
                    message = table.Column<string>(type: "text", nullable: true),
                    sent_by = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_resource_deletion_chat_histories", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_ld_resource_deletion_chat_histories_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_resource_deletion_chat_histories_cp_users_sent_by_tenant",
                        columns: x => new { x.sent_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_sectors",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    sector_name = table.Column<string>(type: "text", nullable: false),
                    is_system = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
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
                    table.PrimaryKey("pk_ld_sectors", x => x.id);
                    table.CheckConstraint("ck_ld_sectors_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_sectors_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_sectors_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_sectors_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_sectors_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_client_businesses",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    bus_name = table.Column<string>(type: "text", nullable: false),
                    address = table.Column<string>(type: "text", nullable: false),
                    google_map_location_capture = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_ld_client_businesses", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_client_businesses_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_clients_tenant_id_org_id_bus_id_loc_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_businesses_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_details",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    loan_type = table.Column<string>(type: "text", nullable: true),
                    sector_id = table.Column<string>(type: "text", nullable: true),
                    interest_type_id = table.Column<string>(type: "text", nullable: true),
                    payment_type = table.Column<string>(type: "text", nullable: true),
                    grace_period = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    registration_id = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "REGISTERED"),
                    is_ready_for_approval = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    requested_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    registration_datetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
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
                    table.PrimaryKey("ak_loan_details_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_loan_details_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_loan_details_payment_type", "payment_type IN ('DAILY','WEEKLY','BI_WEEKLY','MONTHLY','QUARTERLY','YEARLY',NULL)");
                    table.CheckConstraint("ck_ld_loan_details_status", "status IN ('REGISTERED','CAPTURED','APPROVED','REJECTED','DISBURSED','CLOSED','DEFAULTED','WRITTEN_OFF','ACTIVE','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_ld_clients_tenant_id_org_id_bus_id_loc_id_c",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_ld_interest_types_interest_type_id",
                        column: x => x.interest_type_id,
                        principalSchema: "loandrift",
                        principalTable: "ld_interest_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_loan_types_loan_type",
                        column: x => x.loan_type,
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_types",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_loan_details_sectors_sector_id",
                        column: x => x.sector_id,
                        principalSchema: "loandrift",
                        principalTable: "ld_sectors",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "ld_client_documents_paths",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    document_path = table.Column<string>(type: "text", nullable: false),
                    document_name = table.Column<string>(type: "text", nullable: false),
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
                    table.PrimaryKey("pk_ld_client_documents_paths", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_client_documents_paths_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_ld_clients_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_documents_paths_loan_details_tenant_id_org_id_bus",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_client_financial_info",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    currently_working_with = table.Column<string>(type: "text", nullable: true),
                    saving_bank_with = table.Column<string>(type: "text", nullable: true),
                    saving_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    provident_fund_with = table.Column<string>(type: "text", nullable: true),
                    provident_fund_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    life_insurance_provider = table.Column<string>(type: "text", nullable: true),
                    life_insurance_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    salary_in_bank_with = table.Column<string>(type: "text", nullable: true),
                    salary_account_number = table.Column<string>(type: "text", nullable: true),
                    salary_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    asset_name = table.Column<string>(type: "text", nullable: true),
                    asset_value = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    property_name = table.Column<string>(type: "text", nullable: true),
                    property_value = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    borrower_monthly_salary = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    borrower_other_income = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    borrower_monthly_expenses = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    previous_loan_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    previous_loan_amount_2 = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    purpose_installment_payment = table.Column<string>(type: "text", nullable: true),
                    interest_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    principal_loan_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_client_financial_info", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.ForeignKey(
                        name: "fk_ld_client_financial_info_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_client_financial_info_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_financial_info_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_financial_info_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_financial_info_loan_details_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_clients_comments",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    comment = table.Column<string>(type: "text", nullable: true),
                    has_taken_loan_before = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    loan_processed_by = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_ld_clients_comments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_clients_comments_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_clients_tenant_id_org_id_bus_id_loc_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_clients_comments_loan_details_tenant_id_org_id_bus_id_lo",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_guarantors",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    title = table.Column<string>(type: "text", nullable: true),
                    fullname = table.Column<string>(type: "text", nullable: true),
                    contact = table.Column<string>(type: "text", nullable: true),
                    dob = table.Column<string>(type: "text", nullable: true),
                    gender = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    marital_status = table.Column<string>(type: "text", nullable: true),
                    relationship_to_borrower = table.Column<string>(type: "text", nullable: true),
                    occupation = table.Column<string>(type: "text", nullable: true),
                    residential_address = table.Column<string>(type: "text", nullable: true),
                    religion = table.Column<string>(type: "text", nullable: true),
                    business_address = table.Column<string>(type: "text", nullable: true),
                    digital_address = table.Column<string>(type: "text", nullable: true),
                    google_map_location_capture = table.Column<string>(type: "text", nullable: true),
                    collateral_details = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    id_type = table.Column<string>(type: "text", nullable: true),
                    id_number = table.Column<string>(type: "text", nullable: true),
                    religion_extra_info = table.Column<string>(type: "text", nullable: true),
                    id_issue_date = table.Column<string>(type: "text", nullable: true),
                    id_expiry_date = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_ld_guarantors", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_guarantors_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_guarantors_gender", "gender IN ('MALE','FEMALE','OTHER',NULL)");
                    table.CheckConstraint("ck_ld_guarantors_id_type", "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT',NULL)");
                    table.CheckConstraint("ck_ld_guarantors_marital_status", "marital_status IN ('SINGLE','MARRIED','DIVORCED','WIDOWED',NULL)");
                    table.CheckConstraint("ck_ld_guarantors_relationship_to_borrower", "relationship_to_borrower IN ('FAMILY','FRIEND','COLLEAGUE','OTHER',NULL)");
                    table.CheckConstraint("ck_ld_guarantors_title", "title IN ('MR','MRS','MISS','MS','DR','MADAM',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantors_loan_details_tenant_id_org_id_bus_id_loc_id_l",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_approvals",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    approved_by = table.Column<string>(type: "text", nullable: true),
                    approved_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: true),
                    approval_date = table.Column<string>(type: "text", nullable: true),
                    approval_time = table.Column<string>(type: "text", nullable: true),
                    approved_message = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_loan_approvals", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.ForeignKey(
                        name: "fk_ld_loan_approvals_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_approvals_cp_users_approved_by_tenant_id",
                        columns: x => new { x.approved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_approvals_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_approvals_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_approvals_loan_details_tenant_id_org_id_bus_id_loc_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_calculations",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    loan_periods = table.Column<string>(type: "text", nullable: true),
                    interest_period = table.Column<string>(type: "text", nullable: true),
                    repayment_weeks = table.Column<int>(type: "integer", nullable: true),
                    first_payment_date = table.Column<string>(type: "text", nullable: true),
                    expected_interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    loan_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    loan_repayment_amount = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_loan_calculations", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.CheckConstraint("ck_ld_loan_calculations_loan_periods", "loan_periods IN ('DAYS','WEEKS','MONTHS','YEARS',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_loan_calculations_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_loan_calculations_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_calculations_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_calculations_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_calculations_loan_details_tenant_id_org_id_bus_id_l",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_charges",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    processing_fees = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    processing_fees_percentage = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    insurance = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    insurance_percentage = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    other_charges = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    other_charges_percentage = table.Column<decimal>(type: "numeric(15,2)", nullable: false, defaultValue: 0m),
                    bank_cheque_reference = table.Column<string>(type: "text", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_loan_charges", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.ForeignKey(
                        name: "fk_ld_loan_charges_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_loan_charges_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_charges_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_charges_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_charges_loan_details_tenant_id_org_id_bus_id_loc_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_disbursements",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    mode = table.Column<string>(type: "text", nullable: true),
                    reference = table.Column<string>(type: "text", nullable: true),
                    disbursed_by = table.Column<string>(type: "text", nullable: true),
                    disbursement_date = table.Column<string>(type: "text", nullable: true),
                    disbursement_time = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_loan_disbursements", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.CheckConstraint("ck_ld_loan_disbursements_mode", "mode IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','OTHERS',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_loan_disbursements_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_disbursements_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_disbursements_cp_users_disbursed_by_tenant_id",
                        columns: x => new { x.disbursed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_disbursements_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_disbursements_ld_loan_details_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_messages",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    message = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "REGISTERED"),
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
                    table.PrimaryKey("pk_ld_loan_messages", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_loan_messages_status", "status IN ('REGISTERED','CAPTURED','APPROVED','REJECTED','DISBURSED','DEFAULTED','WRITTEN_OFF','ACTIVE','COMPLETED')");
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_messages_ld_loan_details_tenant_id_org_id_bus_id_lo",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_loan_purpose",
                schema: "loandrift",
                columns: table => new
                {
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    loan_purpose = table.Column<string>(type: "text", nullable: true),
                    number_of_months = table.Column<int>(type: "integer", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_loan_purpose", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id });
                    table.ForeignKey(
                        name: "fk_ld_loan_purpose_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_loan_purpose_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_purpose_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_loan_purpose_ld_loan_details_tenant_id_org_id_bus_id_loc",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_repayments",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    payment_method = table.Column<string>(type: "text", nullable: true),
                    next_payment_date = table.Column<string>(type: "text", nullable: true),
                    is_completed = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    amount_given = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    paid_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    balance = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_repayments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_repayments_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_repayments_payment_method", "payment_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','OTHERS',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_repayments_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_repayments_ld_loan_details_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_ld_activity_logs_resource_type",
                schema: "loandrift",
                table: "ld_activity_logs",
                column: "resource_type");

            migrationBuilder.CreateIndex(
                name: "ix_ld_activity_logs_tenant_id",
                schema: "loandrift",
                table: "ld_activity_logs",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_tenant_id_org_id_bus_id_loc_id_client_",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_loc_id_lo",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_financial_info_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_financial_info",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_financial_info_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_financial_info",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_financial_info_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_financial_info",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_contact",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "contact" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_email",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "email" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_interest_types_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_interest_types",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_interest_types_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_interest_types",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_interest_types_tenant_id",
                schema: "loandrift",
                table: "ld_interest_types",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_interest_types_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_interest_types",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_approvals_approved_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_approvals",
                columns: new[] { "approved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_approvals_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_approvals",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_approvals_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_approvals",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_calculations_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_calculations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_calculations_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_calculations",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_calculations_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_calculations",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_charges_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_charges",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_charges_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_charges",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_charges_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_charges",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_interest_type_id",
                schema: "loandrift",
                table: "ld_loan_details",
                column: "interest_type_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_loan_type",
                schema: "loandrift",
                table: "ld_loan_details",
                column: "loan_type");

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_sector_id",
                schema: "loandrift",
                table: "ld_loan_details",
                column: "sector_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_disbursements_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_disbursements",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_disbursements_disbursed_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_disbursements",
                columns: new[] { "disbursed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_disbursements_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_disbursements",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_messages_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_messages",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_purpose_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_purpose",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_purpose_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_purpose",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_types_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_types",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_types_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_types",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_types_tenant_id",
                schema: "loandrift",
                table: "ld_loan_types",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_types_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_loan_types",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_resource_deletion_chat_histories_sent_by_tenant_id",
                schema: "loandrift",
                table: "ld_resource_deletion_chat_histories",
                columns: new[] { "sent_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_sectors_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_sectors",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_sectors_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_sectors",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_sectors_tenant_id",
                schema: "loandrift",
                table: "ld_sectors",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_sectors_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_sectors",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ld_activity_logs",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_client_businesses",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_client_documents_paths",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_client_financial_info",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_clients_comments",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_guarantors",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_approvals",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_calculations",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_charges",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_disbursements",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_messages",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_purpose",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_repayments",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_resource_deletion_chat_histories",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_details",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_clients",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_interest_types",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_loan_types",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_sectors",
                schema: "loandrift");
        }
    }
}
