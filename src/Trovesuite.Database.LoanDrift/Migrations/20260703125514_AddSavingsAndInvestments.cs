using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddSavingsAndInvestments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ld_investment_products",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    product_name = table.Column<string>(type: "text", nullable: false),
                    product_type = table.Column<string>(type: "text", nullable: false, defaultValue: "FIXED_DEPOSIT"),
                    default_interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    default_interest_period = table.Column<string>(type: "text", nullable: true),
                    default_term_months = table.Column<int>(type: "integer", nullable: true),
                    early_termination_penalty_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
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
                    table.PrimaryKey("pk_ld_investment_products", x => x.id);
                    table.CheckConstraint("ck_ld_investment_products_default_interest_period", "default_interest_period IN ('MONTHLY','QUARTERLY','ANNUALLY','AT_MATURITY',NULL)");
                    table.CheckConstraint("ck_ld_investment_products_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_investment_products_product_type", "product_type IN ('FIXED_DEPOSIT','TREASURY_BILL','MONEY_MARKET','BOND','SUSU_INVESTMENT')");
                    table.ForeignKey(
                        name: "fk_ld_investment_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_investment_products_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_products_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_products_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_savings_products",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: true),
                    bus_id = table.Column<string>(type: "text", nullable: true),
                    product_name = table.Column<string>(type: "text", nullable: false),
                    product_type = table.Column<string>(type: "text", nullable: false, defaultValue: "REGULAR_SAVINGS"),
                    default_interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    default_interest_period = table.Column<string>(type: "text", nullable: true),
                    minimum_balance = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    dormancy_days = table.Column<int>(type: "integer", nullable: false, defaultValue: 180),
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
                    table.PrimaryKey("pk_ld_savings_products", x => x.id);
                    table.CheckConstraint("ck_ld_savings_products_default_interest_period", "default_interest_period IN ('DAILY','MONTHLY','QUARTERLY','ANNUALLY',NULL)");
                    table.CheckConstraint("ck_ld_savings_products_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_savings_products_product_type", "product_type IN ('REGULAR_SAVINGS','FIXED_SAVINGS','TARGET_SAVINGS','DAILY_SAVINGS','GROUP_SAVINGS')");
                    table.ForeignKey(
                        name: "fk_ld_savings_products_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_savings_products_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_products_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_products_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_investments",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    investment_product_id = table.Column<string>(type: "text", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    account_number = table.Column<string>(type: "text", nullable: true),
                    principal_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    interest_period = table.Column<string>(type: "text", nullable: true),
                    term_months = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    start_date = table.Column<string>(type: "text", nullable: true),
                    maturity_date = table.Column<string>(type: "text", nullable: true),
                    expected_interest = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    expected_total_payable = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    periodic_return = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    early_termination_penalty_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    rollover_on_maturity = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "REGISTERED"),
                    funded_date = table.Column<string>(type: "text", nullable: true),
                    activated_date = table.Column<string>(type: "text", nullable: true),
                    matured_date = table.Column<string>(type: "text", nullable: true),
                    completed_date = table.Column<string>(type: "text", nullable: true),
                    actual_return = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    penalty_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
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
                    table.PrimaryKey("pk_ld_investments", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_investments_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_investments_interest_period", "interest_period IN ('MONTHLY','QUARTERLY','ANNUALLY','AT_MATURITY',NULL)");
                    table.CheckConstraint("ck_ld_investments_status", "status IN ('REGISTERED','FUNDED','ACTIVE','MATURED','COMPLETED','TERMINATED')");
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investments_investment_products_investment_product_id",
                        column: x => x.investment_product_id,
                        principalSchema: "loandrift",
                        principalTable: "ld_investment_products",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_investments_ld_clients_tenant_id_org_id_bus_id_loc_id_cl",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_savings_accounts",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    savings_product_id = table.Column<string>(type: "text", nullable: true),
                    currency_id = table.Column<string>(type: "text", nullable: true),
                    account_number = table.Column<string>(type: "text", nullable: true),
                    account_name = table.Column<string>(type: "text", nullable: false),
                    current_balance = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    total_deposits = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    total_withdrawals = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    total_interest_earned = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    interest_rate = table.Column<decimal>(type: "numeric(5,2)", nullable: false, defaultValue: 0m),
                    interest_period = table.Column<string>(type: "text", nullable: true),
                    minimum_balance = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    target_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: true),
                    maturity_date = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    opened_date = table.Column<string>(type: "text", nullable: true),
                    closed_date = table.Column<string>(type: "text", nullable: true),
                    last_transaction_date = table.Column<string>(type: "text", nullable: true),
                    closure_reason = table.Column<string>(type: "text", nullable: true),
                    payout_method = table.Column<string>(type: "text", nullable: true),
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
                    table.PrimaryKey("pk_ld_savings_accounts", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_savings_accounts_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_savings_accounts_interest_period", "interest_period IN ('DAILY','MONTHLY','QUARTERLY','ANNUALLY',NULL)");
                    table.CheckConstraint("ck_ld_savings_accounts_status", "status IN ('PENDING','ACTIVE','DORMANT','FROZEN','CLOSED')");
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_currencies_currency_id_tenant_id",
                        columns: x => new { x.currency_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_currencies",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_ld_clients_tenant_id_org_id_bus_id_loc_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_savings_accounts_savings_products_savings_product_id",
                        column: x => x.savings_product_id,
                        principalSchema: "loandrift",
                        principalTable: "ld_savings_products",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "ld_investment_transactions",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    investment_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    transaction_type = table.Column<string>(type: "text", nullable: false, defaultValue: "FUNDING"),
                    amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    penalty_amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    payment_method = table.Column<string>(type: "text", nullable: true),
                    reference = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    occurred_at = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_investment_transactions", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_investment_transactions_payment_method", "payment_method IN ('CASH','MOMO','CHEQUE','BANK_TRANSFER','OTHERS',NULL)");
                    table.CheckConstraint("ck_ld_investment_transactions_transaction_type", "transaction_type IN ('FUNDING','PAYOUT_PERIOD','COMPLETION','TERMINATION')");
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_ld_clients_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_investment_transactions_ld_investments_tenant_id_org_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.investment_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_investments",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_savings_transactions",
                schema: "loandrift",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    savings_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    transaction_type = table.Column<string>(type: "text", nullable: false, defaultValue: "DEPOSIT"),
                    amount = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    balance_before = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    balance_after = table.Column<decimal>(type: "numeric(20,6)", nullable: false, defaultValue: 0m),
                    payment_method = table.Column<string>(type: "text", nullable: true),
                    reference = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    next_contribution_date = table.Column<string>(type: "text", nullable: true),
                    period_from = table.Column<string>(type: "text", nullable: true),
                    period_to = table.Column<string>(type: "text", nullable: true),
                    is_early_withdrawal = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    occurred_at = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_savings_transactions", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_savings_transactions_payment_method", "payment_method IN ('CASH','MOMO','CHEQUE','BANK_TRANSFER','OTHERS',NULL)");
                    table.CheckConstraint("ck_ld_savings_transactions_transaction_type", "transaction_type IN ('DEPOSIT','WITHDRAWAL','INTEREST')");
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_ld_clients_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_savings_transactions_ld_savings_accounts_tenant_id_org_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.savings_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_savings_accounts",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_products_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_investment_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_products_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_investment_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_products_tenant_id",
                schema: "loandrift",
                table: "ld_investment_products",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_products_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_investment_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_loc_id_c",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_loc_id_i",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "investment_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_investment_product_id",
                schema: "loandrift",
                table: "ld_investments",
                column: "investment_product_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_loc_id_account_number",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "account_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_currency_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "currency_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_savings_product_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                column: "savings_product_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_loc_id_account_",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "account_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_products_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_products",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_products_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_products",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_products_tenant_id",
                schema: "loandrift",
                table: "ld_savings_products",
                column: "tenant_id");

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_products_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_products",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_loc_id_clie",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_loc_id_savi",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "savings_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ld_investment_transactions",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_savings_transactions",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_investments",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_savings_accounts",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_investment_products",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_savings_products",
                schema: "loandrift");
        }
    }
}
