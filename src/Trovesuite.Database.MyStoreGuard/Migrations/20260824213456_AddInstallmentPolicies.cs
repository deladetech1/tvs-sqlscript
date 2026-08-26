using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentPolicies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_installment_policies",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "varchar(255)", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    policy_mode = table.Column<string>(type: "text", nullable: false, defaultValue: "ALLOW"),
                    policy_target_type = table.Column<string>(type: "text", nullable: false),
                    policy_target_id = table.Column<string>(type: "text", nullable: true),
                    min_sale_amount = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    max_sale_amount = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    initial_payment_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    initial_payment_formula = table.Column<string>(type: "text", nullable: true),
                    initial_payment_min = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    initial_payment_max = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    installment_formula = table.Column<string>(type: "text", nullable: false),
                    first_due_offset_days = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    allow_custom_start_date = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    early_settlement_formula = table.Column<string>(type: "text", nullable: true),
                    approval_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    approval_mode = table.Column<string>(type: "text", nullable: false, defaultValue: "ANY"),
                    approval_threshold_amount = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    approval_min_term_count = table.Column<int>(type: "integer", nullable: true),
                    approval_on_missing_guarantor = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    approval_on_customer_arrears = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    reminder_enabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    reminder_interval_minutes = table.Column<int>(type: "integer", nullable: false, defaultValue: 1440),
                    reminder_max_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 5),
                    penalty_enabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    penalty_kind = table.Column<string>(type: "text", nullable: true),
                    penalty_value = table.Column<decimal>(type: "numeric(14,4)", nullable: true),
                    penalty_basis = table.Column<string>(type: "text", nullable: true),
                    penalty_grace_days = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    penalty_recurrence = table.Column<string>(type: "text", nullable: false, defaultValue: "ONCE_PER_PERIOD"),
                    penalty_max_cap = table.Column<decimal>(type: "numeric(14,2)", nullable: true),
                    guarantors_required_min = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    guarantor_id_document_required = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    release_goods_on = table.Column<string>(type: "text", nullable: false, defaultValue: "FULL_PAYMENT"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    start_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    end_datetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_installment_policies_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_installment_policies_amount_band", "min_sale_amount IS NULL OR max_sale_amount IS NULL OR max_sale_amount >= min_sale_amount");
                    table.CheckConstraint("ck_msg_installment_policies_approval_mode", "approval_mode IN ('ANY','ALL')");
                    table.CheckConstraint("ck_msg_installment_policies_date_window", "start_datetime IS NULL OR end_datetime IS NULL OR end_datetime >= start_datetime");
                    table.CheckConstraint("ck_msg_installment_policies_initial_formula", "initial_payment_required = false OR initial_payment_formula IS NOT NULL");
                    table.CheckConstraint("ck_msg_installment_policies_penalty_basis", "penalty_basis IN ('INSTALLMENT_AMOUNT','OUTSTANDING_BALANCE','SALE_TOTAL')");
                    table.CheckConstraint("ck_msg_installment_policies_penalty_cap", "penalty_recurrence <> 'DAILY_WHILE_LATE' OR penalty_enabled = false OR penalty_max_cap IS NOT NULL");
                    table.CheckConstraint("ck_msg_installment_policies_penalty_kind", "penalty_kind IN ('FIXED','PERCENTAGE')");
                    table.CheckConstraint("ck_msg_installment_policies_penalty_recurrence", "penalty_recurrence IN ('ONCE_PER_PERIOD','DAILY_WHILE_LATE')");
                    table.CheckConstraint("ck_msg_installment_policies_penalty_shape", "penalty_enabled = false OR (  (penalty_kind = 'FIXED' AND penalty_value IS NOT NULL) OR   (penalty_kind = 'PERCENTAGE' AND penalty_value IS NOT NULL      AND penalty_basis IS NOT NULL))");
                    table.CheckConstraint("ck_msg_installment_policies_policy_mode", "policy_mode IN ('ALLOW','DENY')");
                    table.CheckConstraint("ck_msg_installment_policies_policy_target_type", "policy_target_type IN ('ALL_PRODUCTS','PRODUCT','SKU','TAG','LABEL','CATEGORY','BRAND')");
                    table.CheckConstraint("ck_msg_installment_policies_release_goods_on", "release_goods_on IN ('FULL_PAYMENT','INITIAL_PAYMENT','APPROVAL')");
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policies_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_plan_options",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    frequency = table.Column<string>(type: "text", nullable: false),
                    allowed_terms = table.Column<int[]>(type: "integer[]", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_plan_options", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_installment_plan_options_frequency", "frequency IN ('DAILY','WEEKLY','BI_WEEKLY','MONTHLY','QUARTERLY','YEARLY')");
                    table.CheckConstraint("ck_msg_installment_plan_options_terms", "array_length(allowed_terms, 1) >= 1");
                    table.ForeignKey(
                        name: "fk_msg_installment_plan_options_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plan_options_cp_organizations_org_id_tenant",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plan_options_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_plan_options_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plan_options_installment_policies_tenant_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_policy_approvers",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    user_id = table.Column<string>(type: "text", nullable: false),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_policy_approvers", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_cp_businesses_bus_id_tenan",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_cp_organizations_org_id_te",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_cp_users_created_by_tenant",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_cp_users_user_id_tenant_id",
                        columns: x => new { x.user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_approvers_installment_policies_tenan",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_policy_locations",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_policy_locations", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_cp_businesses_bus_id_tenan",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_cp_locations_loc_id_tenant",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_cp_organizations_org_id_te",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_cp_users_created_by_tenant",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_locations_msg_installment_policies_t",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_policy_variables",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    var_name = table.Column<string>(type: "varchar(100)", nullable: false),
                    var_value = table.Column<decimal>(type: "numeric(18,6)", nullable: false),
                    label = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_policy_variables", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_variables_cp_businesses_bus_id_tenan",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_variables_cp_organizations_org_id_te",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_variables_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_variables_cp_users_created_by_tenant",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_policy_variables_msg_installment_policies_t",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plan_options_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plan_options",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plan_options_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plan_options",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plan_options_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plan_options",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plan_options_tenant_id_org_id_bus_id_policy",
                schema: "mystoreguard",
                table: "msg_installment_plan_options",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "frequency" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_tenant_id_org_id_bus_id_is_active_",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "tenant_id", "org_id", "bus_id", "is_active", "policy_target_type" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_tenant_id_org_id_bus_id_policy_tar",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_target_type", "policy_target_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policies_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_approvers_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_approvers",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_approvers_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_approvers",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_approvers_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_approvers",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_approvers_tenant_id_org_id_bus_id_po",
                schema: "mystoreguard",
                table: "msg_installment_policy_approvers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_approvers_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_approvers",
                columns: new[] { "user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_locations_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_locations",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_locations_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_locations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_locations",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_locations_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_locations",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_locations_tenant_id_org_id_bus_id_po",
                schema: "mystoreguard",
                table: "msg_installment_policy_locations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_variables_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_variables",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_variables_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_variables",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_variables_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_policy_variables",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_policy_variables_tenant_id_org_id_bus_id_po",
                schema: "mystoreguard",
                table: "msg_installment_policy_variables",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id", "var_name" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_installment_plan_options",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_policy_approvers",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_policy_locations",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_policy_variables",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_policies",
                schema: "mystoreguard");
        }
    }
}
