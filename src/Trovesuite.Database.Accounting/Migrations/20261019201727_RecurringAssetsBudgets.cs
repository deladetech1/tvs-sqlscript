using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class RecurringAssetsBudgets : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "auto_depreciation",
                schema: "accounting",
                table: "acc_org_settings",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "acc_asset_categories",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    code = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    method = table.Column<string>(type: "text", nullable: false),
                    useful_life_months = table.Column<int>(type: "integer", nullable: false),
                    reducing_rate = table.Column<decimal>(type: "numeric(9,4)", precision: 9, scale: 4, nullable: true),
                    asset_account_id = table.Column<string>(type: "text", nullable: false),
                    accumulated_account_id = table.Column<string>(type: "text", nullable: false),
                    expense_account_id = table.Column<string>(type: "text", nullable: false),
                    disposal_account_id = table.Column<string>(type: "text", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_asset_categories", x => x.id);
                    table.CheckConstraint("ck_acc_asset_categories_bus_id", "btrim(bus_id) <> ''");
                });

            migrationBuilder.CreateTable(
                name: "acc_asset_depreciation",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    asset_id = table.Column<string>(type: "text", nullable: false),
                    period_month = table.Column<DateOnly>(type: "date", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: false),
                    run_id = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_asset_depreciation", x => x.id);
                    table.CheckConstraint("ck_acc_asset_depreciation_bus_id", "btrim(bus_id) <> ''");
                });

            migrationBuilder.CreateTable(
                name: "acc_budgets",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    fiscal_year_id = table.Column<string>(type: "text", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: false),
                    version = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    notes = table.Column<string>(type: "text", nullable: true),
                    approved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    approved_by_id = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_budgets", x => x.id);
                    table.CheckConstraint("ck_acc_budgets_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_budgets_status", "status IN ('DRAFT','APPROVED','SUPERSEDED')");
                });

            migrationBuilder.CreateTable(
                name: "acc_depreciation_runs",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    period_month = table.Column<DateOnly>(type: "date", nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: false),
                    total = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    asset_count = table.Column<int>(type: "integer", nullable: false),
                    trigger = table.Column<string>(type: "text", nullable: false),
                    caught_up = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_depreciation_runs", x => x.id);
                    table.CheckConstraint("ck_acc_depreciation_runs_bus_id", "btrim(bus_id) <> ''");
                });

            migrationBuilder.CreateTable(
                name: "acc_fixed_assets",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    category_id = table.Column<string>(type: "text", nullable: false),
                    cost = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    residual_value = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    acquisition_date = table.Column<DateOnly>(type: "date", nullable: false),
                    in_service_date = table.Column<DateOnly>(type: "date", nullable: false),
                    method = table.Column<string>(type: "text", nullable: false),
                    useful_life_months = table.Column<int>(type: "integer", nullable: false),
                    reducing_rate = table.Column<decimal>(type: "numeric(9,4)", precision: 9, scale: 4, nullable: true),
                    supplier_id = table.Column<string>(type: "text", nullable: true),
                    bill_id = table.Column<string>(type: "text", nullable: true),
                    location = table.Column<string>(type: "text", nullable: true),
                    serial_number = table.Column<string>(type: "text", nullable: true),
                    acquisition_journal_id = table.Column<string>(type: "text", nullable: true),
                    funding_account_id = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    disposal_date = table.Column<DateOnly>(type: "date", nullable: true),
                    disposal_proceeds = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: true),
                    disposal_account_id = table.Column<string>(type: "text", nullable: true),
                    disposal_gain_loss = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: true),
                    disposal_journal_id = table.Column<string>(type: "text", nullable: true),
                    disposal_reason = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_fixed_assets", x => x.id);
                    table.CheckConstraint("ck_acc_fixed_assets_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_fixed_assets_method", "method IN ('STRAIGHT_LINE','REDUCING_BALANCE')");
                    table.CheckConstraint("ck_acc_fixed_assets_status", "status IN ('ACTIVE','DISPOSED','WRITTEN_OFF')");
                });

            migrationBuilder.CreateTable(
                name: "acc_recurring_runs",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    template_id = table.Column<string>(type: "text", nullable: false),
                    occurrence_date = table.Column<DateOnly>(type: "date", nullable: false),
                    occurrence_no = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: true),
                    document_number = table.Column<string>(type: "text", nullable: true),
                    note = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_recurring_runs", x => x.id);
                    table.CheckConstraint("ck_acc_recurring_runs_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_recurring_runs_status", "status IN ('GENERATED','SKIPPED')");
                });

            migrationBuilder.CreateTable(
                name: "acc_recurring_templates",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    party_id = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    supplier_reference = table.Column<string>(type: "text", nullable: true),
                    payment_terms_days = table.Column<int>(type: "integer", nullable: false),
                    frequency = table.Column<string>(type: "text", nullable: false),
                    interval_count = table.Column<int>(type: "integer", nullable: false),
                    interval_unit = table.Column<string>(type: "text", nullable: false),
                    day_rule = table.Column<string>(type: "text", nullable: false),
                    day_of_month = table.Column<int>(type: "integer", nullable: true),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    occurrences = table.Column<int>(type: "integer", nullable: true),
                    auto_approve = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    held_reason = table.Column<string>(type: "text", nullable: true),
                    held_date = table.Column<DateOnly>(type: "date", nullable: true),
                    next_run_date = table.Column<DateOnly>(type: "date", nullable: true),
                    last_run_date = table.Column<DateOnly>(type: "date", nullable: true),
                    generated_count = table.Column<int>(type: "integer", nullable: false),
                    source_document_id = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_recurring_templates", x => x.id);
                    table.CheckConstraint("ck_acc_recurring_templates_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_recurring_templates_kind", "kind IN ('INVOICE','BILL')");
                    table.CheckConstraint("ck_acc_recurring_templates_status", "status IN ('ACTIVE','PAUSED','ENDED','COMPLETED')");
                });

            migrationBuilder.CreateTable(
                name: "acc_budget_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    budget_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false),
                    dimension_id = table.Column<string>(type: "text", nullable: true),
                    m01 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m02 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m03 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m04 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m05 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m06 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m07 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m08 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m09 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m10 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m11 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    m12 = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_budget_lines", x => x.id);
                    table.CheckConstraint("ck_acc_budget_lines_bus_id", "btrim(bus_id) <> ''");
                    table.ForeignKey(
                        name: "fk_acc_budget_lines_acc_budgets_budget_id",
                        column: x => x.budget_id,
                        principalSchema: "accounting",
                        principalTable: "acc_budgets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_recurring_template_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    template_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(18,4)", precision: 18, scale: 4, nullable: false),
                    tax_code_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_recurring_template_lines", x => x.id);
                    table.CheckConstraint("ck_acc_recurring_template_lines_bus_id", "btrim(bus_id) <> ''");
                    table.ForeignKey(
                        name: "fk_acc_recurring_template_lines_acc_recurring_templates_templa",
                        column: x => x.template_id,
                        principalSchema: "accounting",
                        principalTable: "acc_recurring_templates",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_acc_asset_categories_tenant_id_org_id_bus_id_code",
                schema: "accounting",
                table: "acc_asset_categories",
                columns: new[] { "tenant_id", "org_id", "bus_id", "code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_asset_depreciation_asset_id_period_month",
                schema: "accounting",
                table: "acc_asset_depreciation",
                columns: new[] { "asset_id", "period_month" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_asset_depreciation_tenant_id_org_id_bus_id_period_month",
                schema: "accounting",
                table: "acc_asset_depreciation",
                columns: new[] { "tenant_id", "org_id", "bus_id", "period_month" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_budget_lines_budget_id_account_id_dimension_id",
                schema: "accounting",
                table: "acc_budget_lines",
                columns: new[] { "budget_id", "account_id", "dimension_id" },
                unique: true)
                .Annotation("Npgsql:NullsDistinct", false);

            migrationBuilder.CreateIndex(
                name: "ix_acc_budget_lines_tenant_id_org_id_bus_id_budget_id",
                schema: "accounting",
                table: "acc_budget_lines",
                columns: new[] { "tenant_id", "org_id", "bus_id", "budget_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_budgets_tenant_id_org_id_bus_id_fiscal_year_id_version",
                schema: "accounting",
                table: "acc_budgets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "fiscal_year_id", "version" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_acc_budgets_approved",
                schema: "accounting",
                table: "acc_budgets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "fiscal_year_id" },
                unique: true,
                filter: "status = 'APPROVED'");

            migrationBuilder.CreateIndex(
                name: "ix_acc_depreciation_runs_tenant_id_org_id_bus_id_period_month",
                schema: "accounting",
                table: "acc_depreciation_runs",
                columns: new[] { "tenant_id", "org_id", "bus_id", "period_month" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_fixed_assets_tenant_id_org_id_bus_id_category_id",
                schema: "accounting",
                table: "acc_fixed_assets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "category_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_fixed_assets_tenant_id_org_id_bus_id_number",
                schema: "accounting",
                table: "acc_fixed_assets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_fixed_assets_tenant_id_org_id_bus_id_status",
                schema: "accounting",
                table: "acc_fixed_assets",
                columns: new[] { "tenant_id", "org_id", "bus_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_runs_template_id_occurrence_date",
                schema: "accounting",
                table: "acc_recurring_runs",
                columns: new[] { "template_id", "occurrence_date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_runs_tenant_id_org_id_bus_id_template_id",
                schema: "accounting",
                table: "acc_recurring_runs",
                columns: new[] { "tenant_id", "org_id", "bus_id", "template_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_template_lines_template_id",
                schema: "accounting",
                table: "acc_recurring_template_lines",
                column: "template_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_template_lines_tenant_id_org_id_bus_id_templa",
                schema: "accounting",
                table: "acc_recurring_template_lines",
                columns: new[] { "tenant_id", "org_id", "bus_id", "template_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_templates_tenant_id_org_id_bus_id_number",
                schema: "accounting",
                table: "acc_recurring_templates",
                columns: new[] { "tenant_id", "org_id", "bus_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_recurring_templates_tenant_id_org_id_bus_id_status_next",
                schema: "accounting",
                table: "acc_recurring_templates",
                columns: new[] { "tenant_id", "org_id", "bus_id", "status", "next_run_date" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "acc_asset_categories",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_asset_depreciation",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_budget_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_depreciation_runs",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_fixed_assets",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_recurring_runs",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_recurring_template_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_budgets",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_recurring_templates",
                schema: "accounting");

            migrationBuilder.DropColumn(
                name: "auto_depreciation",
                schema: "accounting",
                table: "acc_org_settings");
        }
    }
}
