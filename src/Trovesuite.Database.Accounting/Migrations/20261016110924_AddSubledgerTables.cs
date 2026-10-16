using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AddSubledgerTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "acc_bank_accounts",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    bank = table.Column<string>(type: "text", nullable: false),
                    account_number = table.Column<string>(type: "text", nullable: false),
                    gl_account_id = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    statement_balance = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    statement_date = table.Column<DateOnly>(type: "date", nullable: false),
                    last_reconciled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_bank_accounts", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_bank_statement_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bank_account_id = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    matched_journal_id = table.Column<string>(type: "text", nullable: true),
                    suggested_journal_id = table.Column<string>(type: "text", nullable: true),
                    reference = table.Column<string>(type: "text", nullable: true),
                    import_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_bank_statement_lines", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_credit_notes",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    party_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    state = table.Column<string>(type: "text", nullable: false),
                    reason = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    base_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_credit_notes", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_custom_fields",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    entity = table.Column<string>(type: "text", nullable: false),
                    key = table.Column<string>(type: "text", nullable: false),
                    label = table.Column<string>(type: "text", nullable: false),
                    type = table.Column<string>(type: "text", nullable: false),
                    scope = table.Column<string>(type: "text", nullable: false),
                    options_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'[]'::jsonb"),
                    required = table.Column<bool>(type: "boolean", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    default_value = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    position = table.Column<int>(type: "integer", nullable: false),
                    show_in_list = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_custom_fields", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_customers",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    code = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    phone = table.Column<string>(type: "text", nullable: false),
                    city = table.Column<string>(type: "text", nullable: false),
                    tin = table.Column<string>(type: "text", nullable: true),
                    payment_terms_days = table.Column<int>(type: "integer", nullable: false),
                    credit_limit = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    external_reference = table.Column<string>(type: "text", nullable: true),
                    source = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_customers", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_data_sources",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    provider = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    sync_direction = table.Column<string>(type: "text", nullable: false),
                    schedule = table.Column<string>(type: "text", nullable: false),
                    entities_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'[]'::jsonb"),
                    last_run_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_run_status = table.Column<string>(type: "text", nullable: true),
                    records_synced = table.Column<int>(type: "integer", nullable: false),
                    error_count = table.Column<int>(type: "integer", nullable: false),
                    connection_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    status_message = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_data_sources", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_exchange_rates",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    currency_code = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    source = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_exchange_rates", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_field_mappings",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    source_id = table.Column<string>(type: "text", nullable: false),
                    entity = table.Column<string>(type: "text", nullable: false),
                    source_field = table.Column<string>(type: "text", nullable: false),
                    target_field = table.Column<string>(type: "text", nullable: false),
                    transform = table.Column<string>(type: "text", nullable: false),
                    required = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_field_mappings", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_fx_revaluations",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    period_id = table.Column<string>(type: "text", nullable: false),
                    as_at = table.Column<DateOnly>(type: "date", nullable: false),
                    rates_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    net_difference = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: false),
                    reversal_journal_id = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_fx_revaluations", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_import_batches",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    source_id = table.Column<string>(type: "text", nullable: true),
                    name = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    rows_received = table.Column<int>(type: "integer", nullable: false),
                    rows_posted = table.Column<int>(type: "integer", nullable: false),
                    rows_held = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_import_batches", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_payments",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    direction = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    party_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    base_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    fx_gain_loss = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    method = table.Column<string>(type: "text", nullable: false),
                    bank_account_id = table.Column<string>(type: "text", nullable: false),
                    reference = table.Column<string>(type: "text", nullable: true),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    state = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_payments", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_purchase_bills",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    supplier_id = table.Column<string>(type: "text", nullable: false),
                    supplier_reference = table.Column<string>(type: "text", nullable: false),
                    issue_date = table.Column<DateOnly>(type: "date", nullable: false),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false),
                    state = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    amount_paid = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    amount_paid_base = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    source_type = table.Column<string>(type: "text", nullable: false),
                    source_reference = table.Column<string>(type: "text", nullable: true),
                    source_document_id = table.Column<string>(type: "text", nullable: true),
                    custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_purchase_bills", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_sales_invoices",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: false),
                    issue_date = table.Column<DateOnly>(type: "date", nullable: false),
                    due_date = table.Column<DateOnly>(type: "date", nullable: false),
                    state = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    amount_paid = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    amount_paid_base = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    source_type = table.Column<string>(type: "text", nullable: false),
                    source_reference = table.Column<string>(type: "text", nullable: true),
                    source_document_id = table.Column<string>(type: "text", nullable: true),
                    custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_sales_invoices", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_supplier_credits",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    number = table.Column<string>(type: "text", nullable: false),
                    party_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    state = table.Column<string>(type: "text", nullable: false),
                    reason = table.Column<string>(type: "text", nullable: false),
                    supplier_reference = table.Column<string>(type: "text", nullable: true),
                    currency = table.Column<string>(type: "text", nullable: false),
                    exchange_rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    base_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    branch_id = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_supplier_credits", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_suppliers",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    code = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    phone = table.Column<string>(type: "text", nullable: false),
                    city = table.Column<string>(type: "text", nullable: false),
                    tin = table.Column<string>(type: "text", nullable: true),
                    payment_terms_days = table.Column<int>(type: "integer", nullable: false),
                    credit_limit = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    external_reference = table.Column<string>(type: "text", nullable: true),
                    source = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_suppliers", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "acc_credit_note_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    credit_note_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(18,3)", precision: 18, scale: 3, nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    tax_code_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_credit_note_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_credit_note_lines_acc_credit_notes_credit_note_id",
                        column: x => x.credit_note_id,
                        principalSchema: "accounting",
                        principalTable: "acc_credit_notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_fx_revaluation_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    revaluation_id = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    label = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false),
                    amount_fc = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    carrying_base = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    rate = table.Column<decimal>(type: "numeric(18,6)", precision: 18, scale: 6, nullable: false),
                    revalued_base = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    difference = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_fx_revaluation_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_fx_revaluation_lines_acc_fx_revaluations_revaluation_id",
                        column: x => x.revaluation_id,
                        principalSchema: "accounting",
                        principalTable: "acc_fx_revaluations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_import_records",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    batch_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    reference = table.Column<string>(type: "text", nullable: false),
                    summary = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    error = table.Column<string>(type: "text", nullable: true),
                    payload_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_import_records", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_import_records_acc_import_batches_batch_id",
                        column: x => x.batch_id,
                        principalSchema: "accounting",
                        principalTable: "acc_import_batches",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_purchase_bill_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bill_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(18,3)", precision: 18, scale: 3, nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    tax_code_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_purchase_bill_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_purchase_bill_lines_acc_purchase_bills_bill_id",
                        column: x => x.bill_id,
                        principalSchema: "accounting",
                        principalTable: "acc_purchase_bills",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_sales_invoice_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    invoice_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(18,3)", precision: 18, scale: 3, nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    tax_code_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_sales_invoice_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_sales_invoice_lines_acc_sales_invoices_invoice_id",
                        column: x => x.invoice_id,
                        principalSchema: "accounting",
                        principalTable: "acc_sales_invoices",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "acc_supplier_credit_lines",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    supplier_credit_id = table.Column<string>(type: "text", nullable: false),
                    line_no = table.Column<int>(type: "integer", nullable: false),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(18,3)", precision: 18, scale: 3, nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    tax_code_id = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_supplier_credit_lines", x => x.id);
                    table.ForeignKey(
                        name: "fk_acc_supplier_credit_lines_acc_supplier_credits_supplier_cre",
                        column: x => x.supplier_credit_id,
                        principalSchema: "accounting",
                        principalTable: "acc_supplier_credits",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_accounts_tenant_id_org_id_gl_account_id",
                schema: "accounting",
                table: "acc_bank_accounts",
                columns: new[] { "tenant_id", "org_id", "gl_account_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_d",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                columns: new[] { "tenant_id", "org_id", "bank_account_id", "date" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                columns: new[] { "tenant_id", "org_id", "matched_journal_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_credit_note_lines_credit_note_id",
                schema: "accounting",
                table: "acc_credit_note_lines",
                column: "credit_note_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_credit_note_lines_tenant_id_org_id_credit_note_id",
                schema: "accounting",
                table: "acc_credit_note_lines",
                columns: new[] { "tenant_id", "org_id", "credit_note_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_credit_notes_tenant_id_org_id_document_id",
                schema: "accounting",
                table: "acc_credit_notes",
                columns: new[] { "tenant_id", "org_id", "document_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_credit_notes_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_credit_notes",
                columns: new[] { "tenant_id", "org_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_custom_fields_tenant_id_org_id_entity_key",
                schema: "accounting",
                table: "acc_custom_fields",
                columns: new[] { "tenant_id", "org_id", "entity", "key" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_customers_tenant_id_org_id_code",
                schema: "accounting",
                table: "acc_customers",
                columns: new[] { "tenant_id", "org_id", "code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_customers_tenant_id_org_id_name",
                schema: "accounting",
                table: "acc_customers",
                columns: new[] { "tenant_id", "org_id", "name" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_data_sources_tenant_id_org_id_name",
                schema: "accounting",
                table: "acc_data_sources",
                columns: new[] { "tenant_id", "org_id", "name" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_exchange_rates_tenant_id_org_id_currency_code_date_sour",
                schema: "accounting",
                table: "acc_exchange_rates",
                columns: new[] { "tenant_id", "org_id", "currency_code", "date", "source" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_field_mappings_tenant_id_org_id_source_id_entity_target",
                schema: "accounting",
                table: "acc_field_mappings",
                columns: new[] { "tenant_id", "org_id", "source_id", "entity", "target_field" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_fx_revaluation_lines_revaluation_id",
                schema: "accounting",
                table: "acc_fx_revaluation_lines",
                column: "revaluation_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_fx_revaluation_lines_tenant_id_org_id_revaluation_id",
                schema: "accounting",
                table: "acc_fx_revaluation_lines",
                columns: new[] { "tenant_id", "org_id", "revaluation_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_fx_revaluations_tenant_id_org_id_period_id",
                schema: "accounting",
                table: "acc_fx_revaluations",
                columns: new[] { "tenant_id", "org_id", "period_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_import_batches_tenant_id_org_id_status",
                schema: "accounting",
                table: "acc_import_batches",
                columns: new[] { "tenant_id", "org_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_import_records_batch_id",
                schema: "accounting",
                table: "acc_import_records",
                column: "batch_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_import_records_tenant_id_org_id_batch_id",
                schema: "accounting",
                table: "acc_import_records",
                columns: new[] { "tenant_id", "org_id", "batch_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_payments_tenant_id_org_id_direction_number",
                schema: "accounting",
                table: "acc_payments",
                columns: new[] { "tenant_id", "org_id", "direction", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_payments_tenant_id_org_id_document_id",
                schema: "accounting",
                table: "acc_payments",
                columns: new[] { "tenant_id", "org_id", "document_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_payments_tenant_id_org_id_party_id",
                schema: "accounting",
                table: "acc_payments",
                columns: new[] { "tenant_id", "org_id", "party_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bill_lines_bill_id",
                schema: "accounting",
                table: "acc_purchase_bill_lines",
                column: "bill_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bill_lines_tenant_id_org_id_bill_id",
                schema: "accounting",
                table: "acc_purchase_bill_lines",
                columns: new[] { "tenant_id", "org_id", "bill_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bills_tenant_id_org_id_issue_date",
                schema: "accounting",
                table: "acc_purchase_bills",
                columns: new[] { "tenant_id", "org_id", "issue_date" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bills_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_purchase_bills",
                columns: new[] { "tenant_id", "org_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bills_tenant_id_org_id_state",
                schema: "accounting",
                table: "acc_purchase_bills",
                columns: new[] { "tenant_id", "org_id", "state" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_purchase_bills_tenant_id_org_id_supplier_id",
                schema: "accounting",
                table: "acc_purchase_bills",
                columns: new[] { "tenant_id", "org_id", "supplier_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoice_lines_invoice_id",
                schema: "accounting",
                table: "acc_sales_invoice_lines",
                column: "invoice_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoice_lines_tenant_id_org_id_invoice_id",
                schema: "accounting",
                table: "acc_sales_invoice_lines",
                columns: new[] { "tenant_id", "org_id", "invoice_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoices_tenant_id_org_id_customer_id",
                schema: "accounting",
                table: "acc_sales_invoices",
                columns: new[] { "tenant_id", "org_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoices_tenant_id_org_id_issue_date",
                schema: "accounting",
                table: "acc_sales_invoices",
                columns: new[] { "tenant_id", "org_id", "issue_date" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoices_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_sales_invoices",
                columns: new[] { "tenant_id", "org_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_sales_invoices_tenant_id_org_id_state",
                schema: "accounting",
                table: "acc_sales_invoices",
                columns: new[] { "tenant_id", "org_id", "state" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_supplier_credit_lines_supplier_credit_id",
                schema: "accounting",
                table: "acc_supplier_credit_lines",
                column: "supplier_credit_id");

            migrationBuilder.CreateIndex(
                name: "ix_acc_supplier_credit_lines_tenant_id_org_id_supplier_credit_",
                schema: "accounting",
                table: "acc_supplier_credit_lines",
                columns: new[] { "tenant_id", "org_id", "supplier_credit_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_supplier_credits_tenant_id_org_id_document_id",
                schema: "accounting",
                table: "acc_supplier_credits",
                columns: new[] { "tenant_id", "org_id", "document_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_supplier_credits_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_supplier_credits",
                columns: new[] { "tenant_id", "org_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_suppliers_tenant_id_org_id_code",
                schema: "accounting",
                table: "acc_suppliers",
                columns: new[] { "tenant_id", "org_id", "code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_suppliers_tenant_id_org_id_name",
                schema: "accounting",
                table: "acc_suppliers",
                columns: new[] { "tenant_id", "org_id", "name" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "acc_bank_accounts",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_bank_statement_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_credit_note_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_custom_fields",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_customers",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_data_sources",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_exchange_rates",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_field_mappings",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_fx_revaluation_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_import_records",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_payments",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_purchase_bill_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_sales_invoice_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_supplier_credit_lines",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_suppliers",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_credit_notes",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_fx_revaluations",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_import_batches",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_purchase_bills",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_sales_invoices",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_supplier_credits",
                schema: "accounting");
        }
    }
}
