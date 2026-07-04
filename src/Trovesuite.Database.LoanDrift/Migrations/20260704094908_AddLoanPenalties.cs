using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddLoanPenalties : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "interest_paid",
                schema: "loandrift",
                table: "ld_repayments",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<bool>(
                name: "is_reversed",
                schema: "loandrift",
                table: "ld_repayments",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "penalties_after",
                schema: "loandrift",
                table: "ld_repayments",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "penalties_before",
                schema: "loandrift",
                table: "ld_repayments",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "penalty_paid",
                schema: "loandrift",
                table: "ld_repayments",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "principal_paid",
                schema: "loandrift",
                table: "ld_repayments",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "penalty_mode",
                schema: "loandrift",
                table: "ld_loan_types",
                type: "text",
                nullable: false,
                defaultValue: "OPTIONAL");

            migrationBuilder.AddColumn<decimal>(
                name: "penalties_outstanding",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<bool>(
                name: "penalty_enabled",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "penalty_mode",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "text",
                nullable: false,
                defaultValue: "OPTIONAL");

            migrationBuilder.AddColumn<decimal>(
                name: "total_penalties_applied",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "total_penalties_waived",
                schema: "loandrift",
                table: "ld_loan_details",
                type: "numeric(20,6)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "ld_penalties",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    penalty_type = table.Column<string>(type: "text", nullable: false, defaultValue: "LATE_PAYMENT"),
                    penalty_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    waived_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    paid_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    outstanding_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "OUTSTANDING"),
                    due_date = table.Column<string>(type: "text", nullable: true),
                    days_overdue = table.Column<int>(type: "integer", nullable: false),
                    applied_rate = table.Column<decimal>(type: "numeric(10,4)", nullable: false, defaultValue: 0m),
                    applied_settings_version = table.Column<string>(type: "text", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    waiver_reason = table.Column<string>(type: "text", nullable: true),
                    waived_by = table.Column<string>(type: "text", nullable: true),
                    trigger = table.Column<string>(type: "text", nullable: false, defaultValue: "BATCH_JOB"),
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
                    table.PrimaryKey("pk_ld_penalties", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_penalties_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_penalties_penalty_type", "penalty_type IN ('LATE_PAYMENT','MISSED_PAYMENT','DEFAULT','EARLY_REPAYMENT','BOUNCED_PAYMENT')");
                    table.CheckConstraint("ck_ld_penalties_status", "status IN ('OUTSTANDING','PARTIALLY_PAID','CLEARED','WAIVED')");
                    table.CheckConstraint("ck_ld_penalties_trigger", "trigger IN ('BATCH_JOB','MANUAL','STATUS_CHANGE')");
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalties_ld_clients_tenant_id_org_id_bus_id_loc_id_clie",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalties_ld_loan_details_tenant_id_org_id_bus_id_loc_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_penalty_settings",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    version_id = table.Column<string>(type: "text", nullable: false),
                    config = table.Column<JsonDocument>(type: "jsonb", nullable: true),
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
                    table.PrimaryKey("pk_ld_penalty_settings", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_penalty_settings_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_penalty_settings_history",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    settings_version_id = table.Column<string>(type: "text", nullable: true),
                    changed_by = table.Column<string>(type: "text", nullable: true),
                    changed_at = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    previous_settings = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    new_settings = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    change_summary = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_penalty_settings_history", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_history_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_history_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_history_cp_organizations_org_id_tenant_",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_history_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalty_settings_history_cp_users_changed_by_tenant_id",
                        columns: x => new { x.changed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_penalty_waivers",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    penalty_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    waiver_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    approved_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    waiver_reason = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    requested_by = table.Column<string>(type: "text", nullable: true),
                    approved_by = table.Column<string>(type: "text", nullable: true),
                    decision_reason = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_ld_penalty_waivers", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_penalty_waivers_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_penalty_waivers_status", "status IN ('PENDING','APPROVED','REJECTED')");
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_users_approved_by_tenant_id",
                        columns: x => new { x.approved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_users_requested_by_tenant_id",
                        columns: x => new { x.requested_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_ld_clients_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_ld_loan_details_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_penalty_waivers_ld_penalties_tenant_id_org_id_bus_id_loc",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.penalty_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_penalties",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_loan_types_penalty_mode",
                schema: "loandrift",
                table: "ld_loan_types",
                sql: "penalty_mode IN ('NONE','OPTIONAL','COMPULSORY')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_loan_details_penalty_mode",
                schema: "loandrift",
                table: "ld_loan_details",
                sql: "penalty_mode IN ('NONE','OPTIONAL','COMPULSORY')");

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_history_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings_history",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_history_changed_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings_history",
                columns: new[] { "changed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_history_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings_history",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_settings_history_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_settings_history",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_approved_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "approved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_requested_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "requested_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_loc_id_penalty_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "penalty_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ld_penalty_settings",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_penalty_settings_history",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_penalty_waivers",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_penalties",
                schema: "loandrift");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_loan_types_penalty_mode",
                schema: "loandrift",
                table: "ld_loan_types");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_loan_details_penalty_mode",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "interest_paid",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "is_reversed",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "penalties_after",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "penalties_before",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "penalty_paid",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "principal_paid",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropColumn(
                name: "penalty_mode",
                schema: "loandrift",
                table: "ld_loan_types");

            migrationBuilder.DropColumn(
                name: "penalties_outstanding",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "penalty_enabled",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "penalty_mode",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "total_penalties_applied",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropColumn(
                name: "total_penalties_waived",
                schema: "loandrift",
                table: "ld_loan_details");
        }
    }
}
