using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentPlans : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "finance_charge_amount",
                schema: "mystoreguard",
                table: "msg_sales",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "payable_amount",
                schema: "mystoreguard",
                table: "msg_sales",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m);

            // Every sale that already exists owes exactly its goods total —
            // there was no such thing as a finance charge before this. Without
            // the backfill they all land on payable_amount = 0, and anything
            // measuring a balance against it reads back minus what was paid.
            //
            // New non-installment sales are set by the service; only history
            // needs fixing here.
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_sales SET payable_amount = total_amount WHERE payable_amount = 0;");

            migrationBuilder.CreateTable(
                name: "msg_installment_plans",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    policy_id = table.Column<string>(type: "text", nullable: false),
                    policy_snapshot = table.Column<JsonDocument>(type: "jsonb", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "DRAFT"),
                    frequency = table.Column<string>(type: "text", nullable: false),
                    term_count = table.Column<int>(type: "integer", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    goods_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    initial_payment = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    financed_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    installment_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    total_payable = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    finance_charge = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    amount_paid = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    penalties_accrued = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    penalties_paid = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    formula_trace = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    approved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    approved_by = table.Column<string>(type: "text", nullable: true),
                    rejected_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    rejected_by = table.Column<string>(type: "text", nullable: true),
                    rejection_reason = table.Column<string>(type: "text", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    defaulted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancelled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_installment_plans_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_installment_plans_charge", "finance_charge = total_payable - goods_amount");
                    table.CheckConstraint("ck_msg_installment_plans_financed", "financed_amount = goods_amount - initial_payment");
                    table.CheckConstraint("ck_msg_installment_plans_frequency", "frequency IN ('DAILY','WEEKLY','BI_WEEKLY','MONTHLY','QUARTERLY','YEARLY')");
                    table.CheckConstraint("ck_msg_installment_plans_status", "status IN ('DRAFT','PENDING_APPROVAL','REJECTED','ACTIVE','COMPLETED','DEFAULTED','CANCELLED')");
                    table.CheckConstraint("ck_msg_installment_plans_term", "term_count >= 1");
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_users_approved_by_tenant_id",
                        columns: x => new { x.approved_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_users_rejected_by_tenant_id",
                        columns: x => new { x.rejected_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_installment_policies_tenant_id_org_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.policy_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_policies",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_plans_sales_tenant_id_org_id_bus_id_loc_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_schedule",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    plan_id = table.Column<string>(type: "text", nullable: false),
                    period_no = table.Column<int>(type: "integer", nullable: false),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_installment_schedule_rows_tenant_id_org_id_bus_id_loc_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_installment_schedule_amount", "amount > 0");
                    table.CheckConstraint("ck_msg_installment_schedule_paid", "paid_amount >= 0 AND paid_amount <= amount");
                    table.CheckConstraint("ck_msg_installment_schedule_period", "period_no >= 1");
                    table.CheckConstraint("ck_msg_installment_schedule_status", "status IN ('PENDING','PARTIALLY_PAID','PAID','OVERDUE','WAIVED')");
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_schedule_msg_installment_plans_tenant_id_or",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.plan_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_plans",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_allocations",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    plan_id = table.Column<string>(type: "text", nullable: false),
                    payment_id = table.Column<string>(type: "text", nullable: false),
                    schedule_id = table.Column<string>(type: "text", nullable: true),
                    allocation_type = table.Column<string>(type: "text", nullable: false, defaultValue: "SCHEDULED"),
                    amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_allocations", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_installment_allocations_allocation_type", "allocation_type IN ('INITIAL','SCHEDULED','OVERPAYMENT')");
                    table.CheckConstraint("ck_msg_installment_allocations_amount", "amount > 0");
                    table.CheckConstraint("ck_msg_installment_allocations_shape", "(allocation_type = 'SCHEDULED' AND schedule_id IS NOT NULL) OR (allocation_type <> 'SCHEDULED' AND schedule_id IS NULL)");
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_cp_organizations_org_id_tenant_",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_installment_plans_tenant_id_org",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.plan_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_plans",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_installment_schedule_rows_tenan",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.schedule_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_schedule",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_allocations_msg_sales_payments_tenant_id_or",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.payment_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales_payments",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_tenant_id_org_id_bus_id_loc_id_",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "payment_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_tenant_id_org_id_bus_id_loc_id_1",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_allocations_tenant_id_org_id_bus_id_loc_id_2",
                schema: "mystoreguard",
                table: "msg_installment_allocations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "schedule_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_approved_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "approved_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_rejected_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "rejected_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_tenant_id_org_id_bus_id_loc_id_sale_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_tenant_id_org_id_bus_id_policy_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "tenant_id", "org_id", "bus_id", "policy_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_tenant_id_org_id_bus_id_status",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "tenant_id", "org_id", "bus_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_plans_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_plans",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_tenant_id_org_id_bus_id_due_date_s",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "tenant_id", "org_id", "bus_id", "due_date", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_tenant_id_org_id_bus_id_loc_id_pla",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id", "period_no" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_schedule_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_schedule",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_installment_allocations",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_schedule",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_plans",
                schema: "mystoreguard");

            migrationBuilder.DropColumn(
                name: "finance_charge_amount",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropColumn(
                name: "payable_amount",
                schema: "mystoreguard",
                table: "msg_sales");
        }
    }
}
