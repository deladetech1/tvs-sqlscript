using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddCreditScoringAndCollections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_collections",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    external_reference = table.Column<string>(type: "text", nullable: false),
                    channel = table.Column<string>(type: "text", nullable: false, defaultValue: "MOBILE_MONEY"),
                    amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: true),
                    payer_name = table.Column<string>(type: "text", nullable: true),
                    payer_contact = table.Column<string>(type: "text", nullable: true),
                    narration = table.Column<string>(type: "text", nullable: true),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "UNMATCHED"),
                    match_method = table.Column<string>(type: "text", nullable: true),
                    match_confidence = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    plan_id = table.Column<string>(type: "text", nullable: true),
                    payment_id = table.Column<string>(type: "text", nullable: true),
                    resolved_by = table.Column<string>(type: "text", nullable: true),
                    resolved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    resolution_note = table.Column<string>(type: "text", nullable: true),
                    import_batch = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_collections", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_collections_amount", "amount > 0");
                    table.CheckConstraint("ck_msg_collections_channel", "channel IN ('MOBILE_MONEY','BANK_TRANSFER','CASH_DEPOSIT')");
                    table.CheckConstraint("ck_msg_collections_confidence", "match_confidence >= 0 AND match_confidence <= 100");
                    table.CheckConstraint("ck_msg_collections_ignored_has_reason", "status <> 'IGNORED' OR (resolved_by IS NOT NULL AND resolution_note IS NOT NULL)");
                    table.CheckConstraint("ck_msg_collections_match_method", "match_method IN ('REFERENCE','CONTACT','AMOUNT_AND_DATE','MANUAL')");
                    table.CheckConstraint("ck_msg_collections_matched_has_plan", "status NOT IN ('MATCHED','POSTED') OR plan_id IS NOT NULL");
                    table.CheckConstraint("ck_msg_collections_posted_has_payment", "status <> 'POSTED' OR payment_id IS NOT NULL");
                    table.CheckConstraint("ck_msg_collections_status", "status IN ('UNMATCHED','MATCHED','POSTED','IGNORED')");
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_users_resolved_by_tenant_id",
                        columns: x => new { x.resolved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_collections_installment_plans_tenant_id_org_id_bus_id_l",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.plan_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_plans",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "msg_credit_score_settings",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    weight_repayment_history = table.Column<int>(type: "integer", nullable: false, defaultValue: 45),
                    weight_plan_history = table.Column<int>(type: "integer", nullable: false, defaultValue: 25),
                    weight_outstanding_load = table.Column<int>(type: "integer", nullable: false, defaultValue: 20),
                    weight_relationship = table.Column<int>(type: "integer", nullable: false, defaultValue: 10),
                    band_excellent_min = table.Column<int>(type: "integer", nullable: false, defaultValue: 800),
                    band_good_min = table.Column<int>(type: "integer", nullable: false, defaultValue: 650),
                    band_fair_min = table.Column<int>(type: "integer", nullable: false, defaultValue: 500),
                    band_poor_min = table.Column<int>(type: "integer", nullable: false, defaultValue: 350),
                    approval_min_score = table.Column<int>(type: "integer", nullable: true),
                    block_min_score = table.Column<int>(type: "integer", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_credit_score_settings", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_credit_score_settings_bands", "band_poor_min < band_fair_min AND band_fair_min < band_good_min AND band_good_min < band_excellent_min");
                    table.CheckConstraint("ck_msg_credit_score_settings_gates", "block_min_score IS NULL OR approval_min_score IS NULL OR block_min_score <= approval_min_score");
                    table.CheckConstraint("ck_msg_credit_score_settings_weights", "weight_repayment_history + weight_plan_history + weight_outstanding_load + weight_relationship = 100");
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_credit_score_settings_history",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    old_settings = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    new_settings = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    summary = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_credit_score_settings_history", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_history_cp_businesses_bus_id_tena",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_history_cp_locations_loc_id_tenan",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_history_cp_organizations_org_id_t",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_history_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_credit_score_settings_history_cp_users_created_by_tenan",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_credit_scores",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: false),
                    plan_id = table.Column<string>(type: "text", nullable: true),
                    score = table.Column<int>(type: "integer", nullable: false),
                    band = table.Column<string>(type: "text", nullable: false),
                    breakdown = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    settings_snapshot = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    is_manual_adjustment = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    previous_score = table.Column<int>(type: "integer", nullable: true),
                    adjustment_reason = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_credit_scores", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_credit_scores_adjustment", "is_manual_adjustment = false OR (previous_score IS NOT NULL AND adjustment_reason IS NOT NULL)");
                    table.CheckConstraint("ck_msg_credit_scores_band", "band IN ('VERY_POOR','POOR','FAIR','GOOD','EXCELLENT')");
                    table.CheckConstraint("ck_msg_credit_scores_range", "score >= 0 AND score <= 1000");
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_customers_tenant_id_org_id_bus_id_custome",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_msg_credit_scores_installment_plans_tenant_id_org_id_bus_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.plan_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_plans",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_resolved_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "resolved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_tenant_id_org_id_bus_id_external_reference",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "tenant_id", "org_id", "bus_id", "external_reference" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_tenant_id_org_id_bus_id_loc_id_plan_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_tenant_id_org_id_bus_id_status_paid_at",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "tenant_id", "org_id", "bus_id", "status", "paid_at" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_collections_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_tenant_id_org_id_bus_id_loc_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_history_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings_history",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_history_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings_history",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_history_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings_history",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_history_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_score_settings_history",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_score_settings_history_tenant_id_org_id_bus_id_c",
                schema: "mystoreguard",
                table: "msg_credit_score_settings_history",
                columns: new[] { "tenant_id", "org_id", "bus_id", "cdatetime" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_tenant_id_org_id_bus_id_band",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "band" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_tenant_id_org_id_bus_id_customer_id_cdate",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id", "cdatetime" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_credit_scores_tenant_id_org_id_bus_id_loc_id_plan_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_collections",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_credit_score_settings",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_credit_score_settings_history",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_credit_scores",
                schema: "mystoreguard");
        }
    }
}
