using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddCreditScoring : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ld_credit_score_settings",
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
                    table.PrimaryKey("pk_ld_credit_score_settings", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_credit_score_settings_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_credit_score_settings_history",
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
                    table.PrimaryKey("pk_ld_credit_score_settings_history", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_history_cp_businesses_bus_id_tenan",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_history_cp_locations_loc_id_tenant",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_history_cp_organizations_org_id_te",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_history_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_credit_score_settings_history_cp_users_changed_by_tenant",
                        columns: x => new { x.changed_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_credit_scores",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    loan_id = table.Column<string>(type: "text", nullable: false),
                    total_score = table.Column<int>(type: "integer", nullable: false),
                    band = table.Column<string>(type: "text", nullable: false, defaultValue: "VERY_POOR"),
                    recommendation = table.Column<string>(type: "text", nullable: true),
                    repayment_history_score = table.Column<int>(type: "integer", nullable: false),
                    debt_to_income_score = table.Column<int>(type: "integer", nullable: false),
                    credit_utilization_score = table.Column<int>(type: "integer", nullable: false),
                    loan_history_score = table.Column<int>(type: "integer", nullable: false),
                    financial_capacity_score = table.Column<int>(type: "integer", nullable: false),
                    collateral_score = table.Column<int>(type: "integer", nullable: false),
                    dti_ratio = table.Column<decimal>(type: "numeric(8,4)", nullable: false, defaultValue: 0m),
                    utilization_rate = table.Column<decimal>(type: "numeric(8,4)", nullable: false, defaultValue: 0m),
                    net_worth = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    collateral_coverage_ratio = table.Column<decimal>(type: "numeric(8,4)", nullable: false, defaultValue: 0m),
                    on_time_payment_rate = table.Column<decimal>(type: "numeric(8,4)", nullable: false, defaultValue: 0m),
                    total_arrears = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    total_loans = table.Column<int>(type: "integer", nullable: false),
                    completed_loans = table.Column<int>(type: "integer", nullable: false),
                    max_days_in_default = table.Column<int>(type: "integer", nullable: false),
                    default_count = table.Column<int>(type: "integer", nullable: false),
                    account_age_months = table.Column<int>(type: "integer", nullable: false),
                    manual_override = table.Column<bool>(type: "boolean", nullable: false),
                    manual_adjustment = table.Column<int>(type: "integer", nullable: false),
                    manual_adjustment_reason = table.Column<string>(type: "text", nullable: true),
                    trigger = table.Column<string>(type: "text", nullable: false, defaultValue: "CAPTURE"),
                    settings_version_id = table.Column<string>(type: "text", nullable: true),
                    breakdown = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_credit_scores", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_credit_scores_band", "band IN ('EXCELLENT','GOOD','FAIR','POOR','VERY_POOR')");
                    table.CheckConstraint("ck_ld_credit_scores_trigger", "trigger IN ('CAPTURE','REPAYMENT','DEFAULT','COMPLETION','MANUAL','SCHEDULED')");
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_ld_clients_tenant_id_org_id_bus_id_loc_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_credit_scores_loan_details_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.loan_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_loan_details",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_history_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings_history",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_history_changed_by_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings_history",
                columns: new[] { "changed_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_history_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings_history",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_score_settings_history_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_score_settings_history",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_tenant_id_org_id_bus_id_loc_id_loan_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "loan_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ld_credit_score_settings",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_credit_score_settings_history",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_credit_scores",
                schema: "loandrift");
        }
    }
}
