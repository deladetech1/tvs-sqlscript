using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <summary>
    /// The books are per business, not per organisation: <c>bus_id</c> on every Accounting table,
    /// and every key that identified a record within the books (account codes, document numbers,
    /// the settings row) now includes it. Adds <c>acc_org_settings.time_zone</c> for the business's day.
    /// </summary>
    /// <remarks>
    /// Written as guarded SQL rather than the scaffolded operations: a database deployed without one
    /// of the setup tables (saas-dev has no acc_currencies, acc_dimensions, acc_tax_codes or
    /// acc_accounting_rules[_lines]) skips that table instead of failing the whole deploy. The model
    /// snapshot is the scaffolded one, so the next migration diffs against the real model.
    /// </remarks>
    public partial class BooksPerBusiness : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
-- Which business's books an existing row belongs to: the business Accounting is placed at in
-- its organisation (cp_business_app_locations, app-accounting, live). Several placements: the
-- earliest. None: the organisation never had Accounting at a business, and its rows go.
DO $books$
DECLARE
    t text;
    removed bigint;
BEGIN
    FOREACH t IN ARRAY ARRAY['acc_accounting_rule_lines', 'acc_accounting_rules', 'acc_accounts', 'acc_audit_events', 'acc_bank_accounts', 'acc_bank_statement_lines', 'acc_credit_note_lines', 'acc_credit_notes', 'acc_currencies', 'acc_custom_fields', 'acc_customers', 'acc_data_sources', 'acc_dimensions', 'acc_exchange_rates', 'acc_field_mappings', 'acc_fiscal_periods', 'acc_fx_revaluation_lines', 'acc_fx_revaluations', 'acc_import_batches', 'acc_import_records', 'acc_journal_entries', 'acc_journal_lines', 'acc_org_settings', 'acc_payments', 'acc_purchase_bill_lines', 'acc_purchase_bills', 'acc_sales_invoice_lines', 'acc_sales_invoices', 'acc_supplier_credit_lines', 'acc_supplier_credits', 'acc_suppliers', 'acc_tax_codes'] LOOP
        IF to_regclass('accounting.' || t) IS NULL THEN
            RAISE NOTICE 'accounting.% does not exist in this database; nothing to scope', t;
            CONTINUE;
        END IF;

        EXECUTE format('ALTER TABLE accounting.%I ADD COLUMN IF NOT EXISTS bus_id text', t);
        EXECUTE format($q$
            UPDATE accounting.%I x
               SET bus_id = (SELECT bal.bus_id
                  FROM core_platform.cp_business_app_locations bal
                 WHERE bal.tenant_id = x.tenant_id
                   AND bal.org_id = x.org_id
                   AND bal.app_id = 'app-accounting'
                   AND bal.is_active
                   AND bal.delete_status = 'NOT_DELETED'
                   AND btrim(coalesce(bal.bus_id, '')) <> ''
                 ORDER BY bal.cdatetime ASC NULLS LAST, bal.id
                 LIMIT 1)
             WHERE x.bus_id IS NULL$q$, t);
        EXECUTE format('DELETE FROM accounting.%I WHERE bus_id IS NULL', t);
        GET DIAGNOSTICS removed = ROW_COUNT;
        IF removed > 0 THEN
            RAISE NOTICE 'accounting.%: % row(s) of organisations with no Accounting business removed', t, removed;
        END IF;

        EXECUTE format('ALTER TABLE accounting.%I ALTER COLUMN bus_id SET NOT NULL', t);
        EXECUTE format('ALTER TABLE accounting.%I DROP CONSTRAINT IF EXISTS %I', t, 'ck_' || t || '_bus_id');
        EXECUTE format($q$ALTER TABLE accounting.%I ADD CONSTRAINT %I CHECK (btrim(bus_id) <> '')$q$, t, 'ck_' || t || '_bus_id');
    END LOOP;

    -- Every key that identified a record in an organisation's books now identifies it in a
    -- business's: account codes, document numbers, one settings row, one revaluation per period.
    IF to_regclass('accounting.acc_accounting_rule_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounting_rule_lines_tenant_id_org_id_rule_id;';
    END IF;
    IF to_regclass('accounting.acc_accounting_rules') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounting_rules_tenant_id_org_id_source_id_event;';
    END IF;
    IF to_regclass('accounting.acc_accounts') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_parent_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_type;';
    END IF;
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_action;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_entity_type_entity_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_occurred_at;';
    END IF;
    IF to_regclass('accounting.acc_bank_accounts') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_accounts_tenant_id_org_id_gl_account_id;';
    END IF;
    IF to_regclass('accounting.acc_bank_statement_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_d;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_i;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id;';
    END IF;
    IF to_regclass('accounting.acc_credit_note_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_note_lines_tenant_id_org_id_credit_note_id;';
    END IF;
    IF to_regclass('accounting.acc_credit_notes') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_notes_tenant_id_org_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_notes_tenant_id_org_id_number;';
    END IF;
    IF to_regclass('accounting.acc_currencies') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_currencies_tenant_id_org_id_code;';
    END IF;
    IF to_regclass('accounting.acc_custom_fields') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_custom_fields_tenant_id_org_id_entity_key;';
    END IF;
    IF to_regclass('accounting.acc_customers') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_customers_tenant_id_org_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_customers_tenant_id_org_id_name;';
    END IF;
    IF to_regclass('accounting.acc_data_sources') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_data_sources_tenant_id_org_id_name;';
    END IF;
    IF to_regclass('accounting.acc_dimensions') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_dimensions_tenant_id_org_id_kind;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_dimensions_tenant_id_org_id_kind_code;';
    END IF;
    IF to_regclass('accounting.acc_exchange_rates') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_exchange_rates_tenant_id_org_id_currency_code_date_sour;';
    END IF;
    IF to_regclass('accounting.acc_field_mappings') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_field_mappings_tenant_id_org_id_source_id_entity_target;';
    END IF;
    IF to_regclass('accounting.acc_fiscal_periods') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fiscal_periods_tenant_id_org_id_start_date_end_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fiscal_periods_tenant_id_org_id_status;';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluation_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fx_revaluation_lines_tenant_id_org_id_revaluation_id;';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluations') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fx_revaluations_tenant_id_org_id_period_id;';
    END IF;
    IF to_regclass('accounting.acc_import_batches') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_batches_tenant_id_org_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_batches_tenant_id_org_id_status;';
    END IF;
    IF to_regclass('accounting.acc_import_records') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_records_tenant_id_org_id_batch_id;';
    END IF;
    IF to_regclass('accounting.acc_journal_entries') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_source_type;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_status;';
    END IF;
    IF to_regclass('accounting.acc_journal_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_lines_tenant_id_org_id_account_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_lines_tenant_id_org_id_journal_id;';
    END IF;
    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_org_settings_tenant_id_org_id;';
    END IF;
    IF to_regclass('accounting.acc_payments') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_direction_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_party_id;';
    END IF;
    IF to_regclass('accounting.acc_purchase_bill_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bill_lines_tenant_id_org_id_bill_id;';
    END IF;
    IF to_regclass('accounting.acc_purchase_bills') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_issue_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_state;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_supplier_id;';
    END IF;
    IF to_regclass('accounting.acc_sales_invoice_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoice_lines_tenant_id_org_id_invoice_id;';
    END IF;
    IF to_regclass('accounting.acc_sales_invoices') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_customer_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_issue_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_state;';
    END IF;
    IF to_regclass('accounting.acc_supplier_credit_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credit_lines_tenant_id_org_id_supplier_credit_;';
    END IF;
    IF to_regclass('accounting.acc_supplier_credits') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credits_tenant_id_org_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credits_tenant_id_org_id_number;';
    END IF;
    IF to_regclass('accounting.acc_suppliers') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_suppliers_tenant_id_org_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_suppliers_tenant_id_org_id_name;';
    END IF;
    IF to_regclass('accounting.acc_tax_codes') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_tax_codes_tenant_id_org_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_tax_codes_tenant_id_org_id_kind;';
    END IF;

    IF to_regclass('accounting.acc_accounting_rule_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounting_rule_lines_tenant_id_org_id_bus_id_rule_id ON accounting.acc_accounting_rule_lines (tenant_id, org_id, bus_id, rule_id);';
    END IF;
    IF to_regclass('accounting.acc_accounting_rules') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_accounting_rules_tenant_id_org_id_bus_id_source_id_event ON accounting.acc_accounting_rules (tenant_id, org_id, bus_id, source_id, event);';
    END IF;
    IF to_regclass('accounting.acc_accounts') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_bus_id_code ON accounting.acc_accounts (tenant_id, org_id, bus_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_bus_id_parent_id ON accounting.acc_accounts (tenant_id, org_id, bus_id, parent_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_bus_id_type ON accounting.acc_accounts (tenant_id, org_id, bus_id, type);';
    END IF;
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_bus_id_action ON accounting.acc_audit_events (tenant_id, org_id, bus_id, action);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_bus_id_entity_type_entity ON accounting.acc_audit_events (tenant_id, org_id, bus_id, entity_type, entity_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_bus_id_occurred_at ON accounting.acc_audit_events (tenant_id, org_id, bus_id, occurred_at);';
    END IF;
    IF to_regclass('accounting.acc_bank_accounts') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_bank_accounts_tenant_id_org_id_bus_id_gl_account_id ON accounting.acc_bank_accounts (tenant_id, org_id, bus_id, gl_account_id);';
    END IF;
    IF to_regclass('accounting.acc_bank_statement_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_bank_statement_lines_tenant_id_org_id_bus_id_bank_accou ON accounting.acc_bank_statement_lines (tenant_id, org_id, bus_id, bank_account_id, date);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_bank_statement_lines_tenant_id_org_id_bus_id_bank_accou1 ON accounting.acc_bank_statement_lines (tenant_id, org_id, bus_id, bank_account_id, import_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ux_acc_bank_statement_lines_matched_journal_id ON accounting.acc_bank_statement_lines (tenant_id, org_id, bus_id, matched_journal_id) WHERE matched_journal_id IS NOT NULL;';
    END IF;
    IF to_regclass('accounting.acc_credit_note_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_credit_note_lines_tenant_id_org_id_bus_id_credit_note_id ON accounting.acc_credit_note_lines (tenant_id, org_id, bus_id, credit_note_id);';
    END IF;
    IF to_regclass('accounting.acc_credit_notes') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_credit_notes_tenant_id_org_id_bus_id_document_id ON accounting.acc_credit_notes (tenant_id, org_id, bus_id, document_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_credit_notes_tenant_id_org_id_bus_id_number ON accounting.acc_credit_notes (tenant_id, org_id, bus_id, number);';
    END IF;
    IF to_regclass('accounting.acc_currencies') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_currencies_tenant_id_org_id_bus_id_code ON accounting.acc_currencies (tenant_id, org_id, bus_id, code);';
    END IF;
    IF to_regclass('accounting.acc_custom_fields') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_custom_fields_tenant_id_org_id_bus_id_entity_key ON accounting.acc_custom_fields (tenant_id, org_id, bus_id, entity, key);';
    END IF;
    IF to_regclass('accounting.acc_customers') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_customers_tenant_id_org_id_bus_id_code ON accounting.acc_customers (tenant_id, org_id, bus_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_customers_tenant_id_org_id_bus_id_name ON accounting.acc_customers (tenant_id, org_id, bus_id, name);';
    END IF;
    IF to_regclass('accounting.acc_data_sources') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_data_sources_tenant_id_org_id_bus_id_name ON accounting.acc_data_sources (tenant_id, org_id, bus_id, name);';
    END IF;
    IF to_regclass('accounting.acc_dimensions') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_bus_id_kind ON accounting.acc_dimensions (tenant_id, org_id, bus_id, kind);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_bus_id_kind_code ON accounting.acc_dimensions (tenant_id, org_id, bus_id, kind, code);';
    END IF;
    IF to_regclass('accounting.acc_exchange_rates') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_exchange_rates_tenant_id_org_id_bus_id_currency_code_da ON accounting.acc_exchange_rates (tenant_id, org_id, bus_id, currency_code, date, source);';
    END IF;
    IF to_regclass('accounting.acc_field_mappings') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_field_mappings_tenant_id_org_id_bus_id_source_id_entity ON accounting.acc_field_mappings (tenant_id, org_id, bus_id, source_id, entity, target_field);';
    END IF;
    IF to_regclass('accounting.acc_fiscal_periods') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_fiscal_periods_tenant_id_org_id_bus_id_start_date_end_d ON accounting.acc_fiscal_periods (tenant_id, org_id, bus_id, start_date, end_date);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_fiscal_periods_tenant_id_org_id_bus_id_status ON accounting.acc_fiscal_periods (tenant_id, org_id, bus_id, status);';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluation_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_fx_revaluation_lines_tenant_id_org_id_bus_id_revaluatio ON accounting.acc_fx_revaluation_lines (tenant_id, org_id, bus_id, revaluation_id);';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluations') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_fx_revaluations_tenant_id_org_id_bus_id_period_id ON accounting.acc_fx_revaluations (tenant_id, org_id, bus_id, period_id);';
    END IF;
    IF to_regclass('accounting.acc_import_batches') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_import_batches_tenant_id_org_id_bus_id_number ON accounting.acc_import_batches (tenant_id, org_id, bus_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_import_batches_tenant_id_org_id_bus_id_status ON accounting.acc_import_batches (tenant_id, org_id, bus_id, status);';
    END IF;
    IF to_regclass('accounting.acc_import_records') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_import_records_tenant_id_org_id_bus_id_batch_id ON accounting.acc_import_records (tenant_id, org_id, bus_id, batch_id);';
    END IF;
    IF to_regclass('accounting.acc_journal_entries') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_bus_id_date ON accounting.acc_journal_entries (tenant_id, org_id, bus_id, date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_bus_id_number ON accounting.acc_journal_entries (tenant_id, org_id, bus_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_bus_id_source_type ON accounting.acc_journal_entries (tenant_id, org_id, bus_id, source_type);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_bus_id_status ON accounting.acc_journal_entries (tenant_id, org_id, bus_id, status);';
    END IF;
    IF to_regclass('accounting.acc_journal_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_lines_tenant_id_org_id_bus_id_account_id ON accounting.acc_journal_lines (tenant_id, org_id, bus_id, account_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_lines_tenant_id_org_id_bus_id_journal_id ON accounting.acc_journal_lines (tenant_id, org_id, bus_id, journal_id);';
    END IF;
    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_org_settings_tenant_id_org_id_bus_id ON accounting.acc_org_settings (tenant_id, org_id, bus_id);';
    END IF;
    IF to_regclass('accounting.acc_payments') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_bus_id_direction_number ON accounting.acc_payments (tenant_id, org_id, bus_id, direction, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_bus_id_document_id ON accounting.acc_payments (tenant_id, org_id, bus_id, document_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_bus_id_party_id ON accounting.acc_payments (tenant_id, org_id, bus_id, party_id);';
    END IF;
    IF to_regclass('accounting.acc_purchase_bill_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bill_lines_tenant_id_org_id_bus_id_bill_id ON accounting.acc_purchase_bill_lines (tenant_id, org_id, bus_id, bill_id);';
    END IF;
    IF to_regclass('accounting.acc_purchase_bills') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_bus_id_issue_date ON accounting.acc_purchase_bills (tenant_id, org_id, bus_id, issue_date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_bus_id_number ON accounting.acc_purchase_bills (tenant_id, org_id, bus_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_bus_id_state ON accounting.acc_purchase_bills (tenant_id, org_id, bus_id, state);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_bus_id_supplier_id ON accounting.acc_purchase_bills (tenant_id, org_id, bus_id, supplier_id);';
    END IF;
    IF to_regclass('accounting.acc_sales_invoice_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoice_lines_tenant_id_org_id_bus_id_invoice_id ON accounting.acc_sales_invoice_lines (tenant_id, org_id, bus_id, invoice_id);';
    END IF;
    IF to_regclass('accounting.acc_sales_invoices') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_bus_id_customer_id ON accounting.acc_sales_invoices (tenant_id, org_id, bus_id, customer_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_bus_id_issue_date ON accounting.acc_sales_invoices (tenant_id, org_id, bus_id, issue_date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_bus_id_number ON accounting.acc_sales_invoices (tenant_id, org_id, bus_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_bus_id_state ON accounting.acc_sales_invoices (tenant_id, org_id, bus_id, state);';
    END IF;
    IF to_regclass('accounting.acc_supplier_credit_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_supplier_credit_lines_tenant_id_org_id_bus_id_supplier_ ON accounting.acc_supplier_credit_lines (tenant_id, org_id, bus_id, supplier_credit_id);';
    END IF;
    IF to_regclass('accounting.acc_supplier_credits') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_supplier_credits_tenant_id_org_id_bus_id_document_id ON accounting.acc_supplier_credits (tenant_id, org_id, bus_id, document_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_supplier_credits_tenant_id_org_id_bus_id_number ON accounting.acc_supplier_credits (tenant_id, org_id, bus_id, number);';
    END IF;
    IF to_regclass('accounting.acc_suppliers') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_suppliers_tenant_id_org_id_bus_id_code ON accounting.acc_suppliers (tenant_id, org_id, bus_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_suppliers_tenant_id_org_id_bus_id_name ON accounting.acc_suppliers (tenant_id, org_id, bus_id, name);';
    END IF;
    IF to_regclass('accounting.acc_tax_codes') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_bus_id_code ON accounting.acc_tax_codes (tenant_id, org_id, bus_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_bus_id_kind ON accounting.acc_tax_codes (tenant_id, org_id, bus_id, kind);';
    END IF;

    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        ALTER TABLE accounting.acc_org_settings ADD COLUMN IF NOT EXISTS time_zone text NOT NULL DEFAULT '';
    END IF;
END $books$;

-- For the minutes between this migration and the API that writes bus_id: an insert that does not
-- name a business lands in the one the backfill above chose. The API itself refuses to save a row
-- without one, so this only ever serves the previous release. Drop it once that is gone.
CREATE OR REPLACE FUNCTION accounting.acc_fill_bus_id() RETURNS trigger
LANGUAGE plpgsql AS $fill$
BEGIN
    IF NEW.bus_id IS NULL THEN
        NEW.bus_id := (SELECT bal.bus_id
                  FROM core_platform.cp_business_app_locations bal
                 WHERE bal.tenant_id = NEW.tenant_id
                   AND bal.org_id = NEW.org_id
                   AND bal.app_id = 'app-accounting'
                   AND bal.is_active
                   AND bal.delete_status = 'NOT_DELETED'
                   AND btrim(coalesce(bal.bus_id, '')) <> ''
                 ORDER BY bal.cdatetime ASC NULLS LAST, bal.id
                 LIMIT 1);
    END IF;
    RETURN NEW;
END
$fill$;

DO $triggers$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['acc_accounting_rule_lines', 'acc_accounting_rules', 'acc_accounts', 'acc_audit_events', 'acc_bank_accounts', 'acc_bank_statement_lines', 'acc_credit_note_lines', 'acc_credit_notes', 'acc_currencies', 'acc_custom_fields', 'acc_customers', 'acc_data_sources', 'acc_dimensions', 'acc_exchange_rates', 'acc_field_mappings', 'acc_fiscal_periods', 'acc_fx_revaluation_lines', 'acc_fx_revaluations', 'acc_import_batches', 'acc_import_records', 'acc_journal_entries', 'acc_journal_lines', 'acc_org_settings', 'acc_payments', 'acc_purchase_bill_lines', 'acc_purchase_bills', 'acc_sales_invoice_lines', 'acc_sales_invoices', 'acc_supplier_credit_lines', 'acc_supplier_credits', 'acc_suppliers', 'acc_tax_codes'] LOOP
        CONTINUE WHEN to_regclass('accounting.' || t) IS NULL;
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_fill_bus_id ON accounting.%I', t, t);
        EXECUTE format('CREATE TRIGGER trg_%s_fill_bus_id BEFORE INSERT ON accounting.%I FOR EACH ROW EXECUTE FUNCTION accounting.acc_fill_bus_id()', t, t);
    END LOOP;
END $triggers$;

""");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
-- Back to one set of books per organisation. Fails on a database where two businesses of one
-- organisation reuse an account code or a document number, which is the point of per-business books.
DO $books$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['acc_accounting_rule_lines', 'acc_accounting_rules', 'acc_accounts', 'acc_audit_events', 'acc_bank_accounts', 'acc_bank_statement_lines', 'acc_credit_note_lines', 'acc_credit_notes', 'acc_currencies', 'acc_custom_fields', 'acc_customers', 'acc_data_sources', 'acc_dimensions', 'acc_exchange_rates', 'acc_field_mappings', 'acc_fiscal_periods', 'acc_fx_revaluation_lines', 'acc_fx_revaluations', 'acc_import_batches', 'acc_import_records', 'acc_journal_entries', 'acc_journal_lines', 'acc_org_settings', 'acc_payments', 'acc_purchase_bill_lines', 'acc_purchase_bills', 'acc_sales_invoice_lines', 'acc_sales_invoices', 'acc_supplier_credit_lines', 'acc_supplier_credits', 'acc_suppliers', 'acc_tax_codes'] LOOP
        CONTINUE WHEN to_regclass('accounting.' || t) IS NULL;
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_fill_bus_id ON accounting.%I', t, t);
    END LOOP;

    IF to_regclass('accounting.acc_accounting_rule_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounting_rule_lines_tenant_id_org_id_bus_id_rule_id;';
    END IF;
    IF to_regclass('accounting.acc_accounting_rules') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounting_rules_tenant_id_org_id_bus_id_source_id_event;';
    END IF;
    IF to_regclass('accounting.acc_accounts') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_bus_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_bus_id_parent_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_accounts_tenant_id_org_id_bus_id_type;';
    END IF;
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_bus_id_action;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_bus_id_entity_type_entity;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_audit_events_tenant_id_org_id_bus_id_occurred_at;';
    END IF;
    IF to_regclass('accounting.acc_bank_accounts') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_accounts_tenant_id_org_id_bus_id_gl_account_id;';
    END IF;
    IF to_regclass('accounting.acc_bank_statement_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_statement_lines_tenant_id_org_id_bus_id_bank_accou;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_bank_statement_lines_tenant_id_org_id_bus_id_bank_accou1;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ux_acc_bank_statement_lines_matched_journal_id;';
    END IF;
    IF to_regclass('accounting.acc_credit_note_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_note_lines_tenant_id_org_id_bus_id_credit_note_id;';
    END IF;
    IF to_regclass('accounting.acc_credit_notes') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_notes_tenant_id_org_id_bus_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_credit_notes_tenant_id_org_id_bus_id_number;';
    END IF;
    IF to_regclass('accounting.acc_currencies') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_currencies_tenant_id_org_id_bus_id_code;';
    END IF;
    IF to_regclass('accounting.acc_custom_fields') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_custom_fields_tenant_id_org_id_bus_id_entity_key;';
    END IF;
    IF to_regclass('accounting.acc_customers') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_customers_tenant_id_org_id_bus_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_customers_tenant_id_org_id_bus_id_name;';
    END IF;
    IF to_regclass('accounting.acc_data_sources') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_data_sources_tenant_id_org_id_bus_id_name;';
    END IF;
    IF to_regclass('accounting.acc_dimensions') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_dimensions_tenant_id_org_id_bus_id_kind;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_dimensions_tenant_id_org_id_bus_id_kind_code;';
    END IF;
    IF to_regclass('accounting.acc_exchange_rates') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_exchange_rates_tenant_id_org_id_bus_id_currency_code_da;';
    END IF;
    IF to_regclass('accounting.acc_field_mappings') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_field_mappings_tenant_id_org_id_bus_id_source_id_entity;';
    END IF;
    IF to_regclass('accounting.acc_fiscal_periods') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fiscal_periods_tenant_id_org_id_bus_id_start_date_end_d;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fiscal_periods_tenant_id_org_id_bus_id_status;';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluation_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fx_revaluation_lines_tenant_id_org_id_bus_id_revaluatio;';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluations') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_fx_revaluations_tenant_id_org_id_bus_id_period_id;';
    END IF;
    IF to_regclass('accounting.acc_import_batches') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_batches_tenant_id_org_id_bus_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_batches_tenant_id_org_id_bus_id_status;';
    END IF;
    IF to_regclass('accounting.acc_import_records') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_import_records_tenant_id_org_id_bus_id_batch_id;';
    END IF;
    IF to_regclass('accounting.acc_journal_entries') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_bus_id_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_bus_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_bus_id_source_type;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_entries_tenant_id_org_id_bus_id_status;';
    END IF;
    IF to_regclass('accounting.acc_journal_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_lines_tenant_id_org_id_bus_id_account_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_journal_lines_tenant_id_org_id_bus_id_journal_id;';
    END IF;
    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_org_settings_tenant_id_org_id_bus_id;';
    END IF;
    IF to_regclass('accounting.acc_payments') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_bus_id_direction_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_bus_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_payments_tenant_id_org_id_bus_id_party_id;';
    END IF;
    IF to_regclass('accounting.acc_purchase_bill_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bill_lines_tenant_id_org_id_bus_id_bill_id;';
    END IF;
    IF to_regclass('accounting.acc_purchase_bills') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_bus_id_issue_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_bus_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_bus_id_state;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_purchase_bills_tenant_id_org_id_bus_id_supplier_id;';
    END IF;
    IF to_regclass('accounting.acc_sales_invoice_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoice_lines_tenant_id_org_id_bus_id_invoice_id;';
    END IF;
    IF to_regclass('accounting.acc_sales_invoices') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_bus_id_customer_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_bus_id_issue_date;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_bus_id_number;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_sales_invoices_tenant_id_org_id_bus_id_state;';
    END IF;
    IF to_regclass('accounting.acc_supplier_credit_lines') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credit_lines_tenant_id_org_id_bus_id_supplier_;';
    END IF;
    IF to_regclass('accounting.acc_supplier_credits') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credits_tenant_id_org_id_bus_id_document_id;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_supplier_credits_tenant_id_org_id_bus_id_number;';
    END IF;
    IF to_regclass('accounting.acc_suppliers') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_suppliers_tenant_id_org_id_bus_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_suppliers_tenant_id_org_id_bus_id_name;';
    END IF;
    IF to_regclass('accounting.acc_tax_codes') IS NOT NULL THEN
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_tax_codes_tenant_id_org_id_bus_id_code;';
        EXECUTE 'DROP INDEX IF EXISTS accounting.ix_acc_tax_codes_tenant_id_org_id_bus_id_kind;';
    END IF;

    IF to_regclass('accounting.acc_accounting_rule_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounting_rule_lines_tenant_id_org_id_rule_id ON accounting.acc_accounting_rule_lines (tenant_id, org_id, rule_id);';
    END IF;
    IF to_regclass('accounting.acc_accounting_rules') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_accounting_rules_tenant_id_org_id_source_id_event ON accounting.acc_accounting_rules (tenant_id, org_id, source_id, event);';
    END IF;
    IF to_regclass('accounting.acc_accounts') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_code ON accounting.acc_accounts (tenant_id, org_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_parent_id ON accounting.acc_accounts (tenant_id, org_id, parent_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_accounts_tenant_id_org_id_type ON accounting.acc_accounts (tenant_id, org_id, type);';
    END IF;
    IF to_regclass('accounting.acc_audit_events') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_action ON accounting.acc_audit_events (tenant_id, org_id, action);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_entity_type_entity_id ON accounting.acc_audit_events (tenant_id, org_id, entity_type, entity_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_audit_events_tenant_id_org_id_occurred_at ON accounting.acc_audit_events (tenant_id, org_id, occurred_at);';
    END IF;
    IF to_regclass('accounting.acc_bank_accounts') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_bank_accounts_tenant_id_org_id_gl_account_id ON accounting.acc_bank_accounts (tenant_id, org_id, gl_account_id);';
    END IF;
    IF to_regclass('accounting.acc_bank_statement_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_d ON accounting.acc_bank_statement_lines (tenant_id, org_id, bank_account_id, date);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_i ON accounting.acc_bank_statement_lines (tenant_id, org_id, bank_account_id, import_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_bank_statement_lines_tenant_id_org_id_matched_journal_id ON accounting.acc_bank_statement_lines (tenant_id, org_id, matched_journal_id) WHERE matched_journal_id IS NOT NULL;';
    END IF;
    IF to_regclass('accounting.acc_credit_note_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_credit_note_lines_tenant_id_org_id_credit_note_id ON accounting.acc_credit_note_lines (tenant_id, org_id, credit_note_id);';
    END IF;
    IF to_regclass('accounting.acc_credit_notes') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_credit_notes_tenant_id_org_id_document_id ON accounting.acc_credit_notes (tenant_id, org_id, document_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_credit_notes_tenant_id_org_id_number ON accounting.acc_credit_notes (tenant_id, org_id, number);';
    END IF;
    IF to_regclass('accounting.acc_currencies') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_currencies_tenant_id_org_id_code ON accounting.acc_currencies (tenant_id, org_id, code);';
    END IF;
    IF to_regclass('accounting.acc_custom_fields') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_custom_fields_tenant_id_org_id_entity_key ON accounting.acc_custom_fields (tenant_id, org_id, entity, key);';
    END IF;
    IF to_regclass('accounting.acc_customers') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_customers_tenant_id_org_id_code ON accounting.acc_customers (tenant_id, org_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_customers_tenant_id_org_id_name ON accounting.acc_customers (tenant_id, org_id, name);';
    END IF;
    IF to_regclass('accounting.acc_data_sources') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_data_sources_tenant_id_org_id_name ON accounting.acc_data_sources (tenant_id, org_id, name);';
    END IF;
    IF to_regclass('accounting.acc_dimensions') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_kind ON accounting.acc_dimensions (tenant_id, org_id, kind);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_kind_code ON accounting.acc_dimensions (tenant_id, org_id, kind, code);';
    END IF;
    IF to_regclass('accounting.acc_exchange_rates') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_exchange_rates_tenant_id_org_id_currency_code_date_sour ON accounting.acc_exchange_rates (tenant_id, org_id, currency_code, date, source);';
    END IF;
    IF to_regclass('accounting.acc_field_mappings') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_field_mappings_tenant_id_org_id_source_id_entity_target ON accounting.acc_field_mappings (tenant_id, org_id, source_id, entity, target_field);';
    END IF;
    IF to_regclass('accounting.acc_fiscal_periods') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_fiscal_periods_tenant_id_org_id_start_date_end_date ON accounting.acc_fiscal_periods (tenant_id, org_id, start_date, end_date);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_fiscal_periods_tenant_id_org_id_status ON accounting.acc_fiscal_periods (tenant_id, org_id, status);';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluation_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_fx_revaluation_lines_tenant_id_org_id_revaluation_id ON accounting.acc_fx_revaluation_lines (tenant_id, org_id, revaluation_id);';
    END IF;
    IF to_regclass('accounting.acc_fx_revaluations') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_fx_revaluations_tenant_id_org_id_period_id ON accounting.acc_fx_revaluations (tenant_id, org_id, period_id);';
    END IF;
    IF to_regclass('accounting.acc_import_batches') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_import_batches_tenant_id_org_id_number ON accounting.acc_import_batches (tenant_id, org_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_import_batches_tenant_id_org_id_status ON accounting.acc_import_batches (tenant_id, org_id, status);';
    END IF;
    IF to_regclass('accounting.acc_import_records') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_import_records_tenant_id_org_id_batch_id ON accounting.acc_import_records (tenant_id, org_id, batch_id);';
    END IF;
    IF to_regclass('accounting.acc_journal_entries') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_date ON accounting.acc_journal_entries (tenant_id, org_id, date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_number ON accounting.acc_journal_entries (tenant_id, org_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_source_type ON accounting.acc_journal_entries (tenant_id, org_id, source_type);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_entries_tenant_id_org_id_status ON accounting.acc_journal_entries (tenant_id, org_id, status);';
    END IF;
    IF to_regclass('accounting.acc_journal_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_lines_tenant_id_org_id_account_id ON accounting.acc_journal_lines (tenant_id, org_id, account_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_journal_lines_tenant_id_org_id_journal_id ON accounting.acc_journal_lines (tenant_id, org_id, journal_id);';
    END IF;
    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_org_settings_tenant_id_org_id ON accounting.acc_org_settings (tenant_id, org_id);';
    END IF;
    IF to_regclass('accounting.acc_payments') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_direction_number ON accounting.acc_payments (tenant_id, org_id, direction, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_document_id ON accounting.acc_payments (tenant_id, org_id, document_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_payments_tenant_id_org_id_party_id ON accounting.acc_payments (tenant_id, org_id, party_id);';
    END IF;
    IF to_regclass('accounting.acc_purchase_bill_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bill_lines_tenant_id_org_id_bill_id ON accounting.acc_purchase_bill_lines (tenant_id, org_id, bill_id);';
    END IF;
    IF to_regclass('accounting.acc_purchase_bills') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_issue_date ON accounting.acc_purchase_bills (tenant_id, org_id, issue_date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_number ON accounting.acc_purchase_bills (tenant_id, org_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_state ON accounting.acc_purchase_bills (tenant_id, org_id, state);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_purchase_bills_tenant_id_org_id_supplier_id ON accounting.acc_purchase_bills (tenant_id, org_id, supplier_id);';
    END IF;
    IF to_regclass('accounting.acc_sales_invoice_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoice_lines_tenant_id_org_id_invoice_id ON accounting.acc_sales_invoice_lines (tenant_id, org_id, invoice_id);';
    END IF;
    IF to_regclass('accounting.acc_sales_invoices') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_customer_id ON accounting.acc_sales_invoices (tenant_id, org_id, customer_id);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_issue_date ON accounting.acc_sales_invoices (tenant_id, org_id, issue_date);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_number ON accounting.acc_sales_invoices (tenant_id, org_id, number);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_sales_invoices_tenant_id_org_id_state ON accounting.acc_sales_invoices (tenant_id, org_id, state);';
    END IF;
    IF to_regclass('accounting.acc_supplier_credit_lines') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_supplier_credit_lines_tenant_id_org_id_supplier_credit_ ON accounting.acc_supplier_credit_lines (tenant_id, org_id, supplier_credit_id);';
    END IF;
    IF to_regclass('accounting.acc_supplier_credits') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_supplier_credits_tenant_id_org_id_document_id ON accounting.acc_supplier_credits (tenant_id, org_id, document_id);';
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_supplier_credits_tenant_id_org_id_number ON accounting.acc_supplier_credits (tenant_id, org_id, number);';
    END IF;
    IF to_regclass('accounting.acc_suppliers') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_suppliers_tenant_id_org_id_code ON accounting.acc_suppliers (tenant_id, org_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_suppliers_tenant_id_org_id_name ON accounting.acc_suppliers (tenant_id, org_id, name);';
    END IF;
    IF to_regclass('accounting.acc_tax_codes') IS NOT NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_code ON accounting.acc_tax_codes (tenant_id, org_id, code);';
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_kind ON accounting.acc_tax_codes (tenant_id, org_id, kind);';
    END IF;

    FOREACH t IN ARRAY ARRAY['acc_accounting_rule_lines', 'acc_accounting_rules', 'acc_accounts', 'acc_audit_events', 'acc_bank_accounts', 'acc_bank_statement_lines', 'acc_credit_note_lines', 'acc_credit_notes', 'acc_currencies', 'acc_custom_fields', 'acc_customers', 'acc_data_sources', 'acc_dimensions', 'acc_exchange_rates', 'acc_field_mappings', 'acc_fiscal_periods', 'acc_fx_revaluation_lines', 'acc_fx_revaluations', 'acc_import_batches', 'acc_import_records', 'acc_journal_entries', 'acc_journal_lines', 'acc_org_settings', 'acc_payments', 'acc_purchase_bill_lines', 'acc_purchase_bills', 'acc_sales_invoice_lines', 'acc_sales_invoices', 'acc_supplier_credit_lines', 'acc_supplier_credits', 'acc_suppliers', 'acc_tax_codes'] LOOP
        CONTINUE WHEN to_regclass('accounting.' || t) IS NULL;
        EXECUTE format('ALTER TABLE accounting.%I DROP CONSTRAINT IF EXISTS %I', t, 'ck_' || t || '_bus_id');
        EXECUTE format('ALTER TABLE accounting.%I DROP COLUMN IF EXISTS bus_id', t);
    END LOOP;

    IF to_regclass('accounting.acc_org_settings') IS NOT NULL THEN
        ALTER TABLE accounting.acc_org_settings DROP COLUMN IF EXISTS time_zone;
    END IF;
END $books$;

DROP FUNCTION IF EXISTS accounting.acc_fill_bus_id();

""");
        }
    }
}
