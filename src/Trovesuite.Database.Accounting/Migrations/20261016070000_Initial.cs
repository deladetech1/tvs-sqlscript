using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations;

public partial class Initial : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.EnsureSchema(name: "accounting");

        migrationBuilder.CreateTable(
            name: "acc_org_settings",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                legal_name = table.Column<string>(type: "text", nullable: false),
                trading_name = table.Column<string>(type: "text", nullable: false),
                country = table.Column<string>(type: "text", nullable: false),
                base_currency = table.Column<string>(type: "text", nullable: false),
                fiscal_year_start_month = table.Column<int>(type: "integer", nullable: false),
                journal_prefix = table.Column<string>(type: "text", nullable: false),
                invoice_prefix = table.Column<string>(type: "text", nullable: false),
                bill_prefix = table.Column<string>(type: "text", nullable: false),
                fx_realised_account_id = table.Column<string>(type: "text", nullable: true),
                fx_unrealised_account_id = table.Column<string>(type: "text", nullable: true),
                fx_rate_tolerance_pct = table.Column<decimal>(type: "numeric(8,4)", nullable: false),
                default_sales_account_id = table.Column<string>(type: "text", nullable: true),
                default_purchase_account_id = table.Column<string>(type: "text", nullable: true),
                default_sales_tax_code_id = table.Column<string>(type: "text", nullable: true),
                default_purchase_tax_code_id = table.Column<string>(type: "text", nullable: true),
                opening_balance_journal_id = table.Column<string>(type: "text", nullable: true),
                setup_complete = table.Column<bool>(type: "boolean", nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by_id = table.Column<string>(type: "text", nullable: true),
                updated_by_id = table.Column<string>(type: "text", nullable: true)
            },
            constraints: table => table.PrimaryKey("pk_acc_org_settings", x => x.id));

        migrationBuilder.CreateTable(
            name: "acc_accounts",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                code = table.Column<string>(type: "text", nullable: false),
                name = table.Column<string>(type: "text", nullable: false),
                type = table.Column<string>(type: "text", nullable: false),
                subtype = table.Column<string>(type: "text", nullable: false),
                parent_id = table.Column<string>(type: "text", nullable: true),
                is_group = table.Column<bool>(type: "boolean", nullable: false),
                is_active = table.Column<bool>(type: "boolean", nullable: false),
                is_control = table.Column<bool>(type: "boolean", nullable: false),
                is_bank = table.Column<bool>(type: "boolean", nullable: false),
                description = table.Column<string>(type: "text", nullable: true),
                custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by_id = table.Column<string>(type: "text", nullable: true),
                updated_by_id = table.Column<string>(type: "text", nullable: true)
            },
            constraints: table => table.PrimaryKey("pk_acc_accounts", x => x.id));

        migrationBuilder.CreateTable(
            name: "acc_fiscal_periods",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                name = table.Column<string>(type: "text", nullable: false),
                start_date = table.Column<DateOnly>(type: "date", nullable: false),
                end_date = table.Column<DateOnly>(type: "date", nullable: false),
                status = table.Column<string>(type: "text", nullable: false),
                fiscal_year = table.Column<int>(type: "integer", nullable: false),
                locked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                locked_by_id = table.Column<string>(type: "text", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by_id = table.Column<string>(type: "text", nullable: true),
                updated_by_id = table.Column<string>(type: "text", nullable: true)
            },
            constraints: table => table.PrimaryKey("pk_acc_fiscal_periods", x => x.id));

        migrationBuilder.CreateTable(
            name: "acc_journal_entries",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                number = table.Column<string>(type: "text", nullable: false),
                date = table.Column<DateOnly>(type: "date", nullable: false),
                memo = table.Column<string>(type: "text", nullable: false),
                reference = table.Column<string>(type: "text", nullable: true),
                status = table.Column<string>(type: "text", nullable: false),
                source_type = table.Column<string>(type: "text", nullable: false),
                source_reference = table.Column<string>(type: "text", nullable: true),
                source_document_id = table.Column<string>(type: "text", nullable: true),
                branch_id = table.Column<string>(type: "text", nullable: true),
                posted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                posted_by_id = table.Column<string>(type: "text", nullable: true),
                approved_by_id = table.Column<string>(type: "text", nullable: true),
                reversal_of_id = table.Column<string>(type: "text", nullable: true),
                reversed_by_id = table.Column<string>(type: "text", nullable: true),
                reverse_reason = table.Column<string>(type: "text", nullable: true),
                custom_fields_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by_id = table.Column<string>(type: "text", nullable: true),
                updated_by_id = table.Column<string>(type: "text", nullable: true)
            },
            constraints: table => table.PrimaryKey("pk_acc_journal_entries", x => x.id));

        migrationBuilder.CreateTable(
            name: "acc_journal_lines",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                journal_id = table.Column<string>(type: "text", nullable: false),
                line_no = table.Column<int>(type: "integer", nullable: false),
                account_id = table.Column<string>(type: "text", nullable: false),
                description = table.Column<string>(type: "text", nullable: true),
                debit = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                credit = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                branch_id = table.Column<string>(type: "text", nullable: true),
                cost_centre_id = table.Column<string>(type: "text", nullable: true),
                currency = table.Column<string>(type: "text", nullable: true),
                amount_fc = table.Column<decimal>(type: "numeric(18,2)", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_acc_journal_lines", x => x.id);
                table.ForeignKey(
                    name: "fk_acc_journal_lines_acc_journal_entries_journal_id",
                    column: x => x.journal_id,
                    principalSchema: "accounting",
                    principalTable: "acc_journal_entries",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "acc_audit_events",
            schema: "accounting",
            columns: table => new
            {
                id = table.Column<string>(type: "text", nullable: false),
                tenant_id = table.Column<string>(type: "text", nullable: false),
                org_id = table.Column<string>(type: "text", nullable: false),
                occurred_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                action = table.Column<string>(type: "text", nullable: false),
                entity_type = table.Column<string>(type: "text", nullable: false),
                entity_id = table.Column<string>(type: "text", nullable: false),
                entity_label = table.Column<string>(type: "text", nullable: true),
                summary = table.Column<string>(type: "text", nullable: false),
                actor_id = table.Column<string>(type: "text", nullable: true),
                actor_name = table.Column<string>(type: "text", nullable: true),
                changes_json = table.Column<string>(type: "jsonb", nullable: true)
            },
            constraints: table => table.PrimaryKey("pk_acc_audit_events", x => x.id));

        migrationBuilder.CreateIndex(name: "ix_acc_org_settings_tenant_id_org_id", schema: "accounting", table: "acc_org_settings", columns: new[] { "tenant_id", "org_id" }, unique: true);
        migrationBuilder.CreateIndex(name: "ix_acc_accounts_tenant_id_org_id_code", schema: "accounting", table: "acc_accounts", columns: new[] { "tenant_id", "org_id", "code" }, unique: true);
        migrationBuilder.CreateIndex(name: "ix_acc_accounts_tenant_id_org_id_parent_id", schema: "accounting", table: "acc_accounts", columns: new[] { "tenant_id", "org_id", "parent_id" });
        migrationBuilder.CreateIndex(name: "ix_acc_accounts_tenant_id_org_id_type", schema: "accounting", table: "acc_accounts", columns: new[] { "tenant_id", "org_id", "type" });
        migrationBuilder.CreateIndex(name: "ix_acc_fiscal_periods_tenant_id_org_id_start_date_end_date", schema: "accounting", table: "acc_fiscal_periods", columns: new[] { "tenant_id", "org_id", "start_date", "end_date" }, unique: true);
        migrationBuilder.CreateIndex(name: "ix_acc_fiscal_periods_tenant_id_org_id_status", schema: "accounting", table: "acc_fiscal_periods", columns: new[] { "tenant_id", "org_id", "status" });
        migrationBuilder.CreateIndex(name: "ix_acc_journal_entries_tenant_id_org_id_number", schema: "accounting", table: "acc_journal_entries", columns: new[] { "tenant_id", "org_id", "number" }, unique: true);
        migrationBuilder.CreateIndex(name: "ix_acc_journal_entries_tenant_id_org_id_date", schema: "accounting", table: "acc_journal_entries", columns: new[] { "tenant_id", "org_id", "date" });
        migrationBuilder.CreateIndex(name: "ix_acc_journal_entries_tenant_id_org_id_status", schema: "accounting", table: "acc_journal_entries", columns: new[] { "tenant_id", "org_id", "status" });
        migrationBuilder.CreateIndex(name: "ix_acc_journal_entries_tenant_id_org_id_source_type", schema: "accounting", table: "acc_journal_entries", columns: new[] { "tenant_id", "org_id", "source_type" });
        migrationBuilder.CreateIndex(name: "ix_acc_journal_lines_tenant_id_org_id_journal_id", schema: "accounting", table: "acc_journal_lines", columns: new[] { "tenant_id", "org_id", "journal_id" });
        migrationBuilder.CreateIndex(name: "ix_acc_journal_lines_tenant_id_org_id_account_id", schema: "accounting", table: "acc_journal_lines", columns: new[] { "tenant_id", "org_id", "account_id" });
        migrationBuilder.CreateIndex(name: "ix_acc_audit_events_tenant_id_org_id_occurred_at", schema: "accounting", table: "acc_audit_events", columns: new[] { "tenant_id", "org_id", "occurred_at" });
        migrationBuilder.CreateIndex(name: "ix_acc_audit_events_tenant_id_org_id_entity_type_entity_id", schema: "accounting", table: "acc_audit_events", columns: new[] { "tenant_id", "org_id", "entity_type", "entity_id" });
        migrationBuilder.CreateIndex(name: "ix_acc_audit_events_tenant_id_org_id_action", schema: "accounting", table: "acc_audit_events", columns: new[] { "tenant_id", "org_id", "action" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "acc_journal_lines", schema: "accounting");
        migrationBuilder.DropTable(name: "acc_audit_events", schema: "accounting");
        migrationBuilder.DropTable(name: "acc_journal_entries", schema: "accounting");
        migrationBuilder.DropTable(name: "acc_fiscal_periods", schema: "accounting");
        migrationBuilder.DropTable(name: "acc_accounts", schema: "accounting");
        migrationBuilder.DropTable(name: "acc_org_settings", schema: "accounting");
    }
}
