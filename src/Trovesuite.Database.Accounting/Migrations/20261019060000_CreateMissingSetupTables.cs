using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <summary>
    /// Creates the five setup tables (currencies, dimensions, tax codes, accounting rules and their lines) on every
    /// database that never got them, already per business.
    /// </summary>
    /// <remarks>
    /// AddSetupCatalogTables was scaffolded against an empty snapshot, so it re-creates acc_accounts and the other
    /// Initial tables; on every real database that hit "already exists" and the runner's reconcile recorded it as
    /// applied WITHOUT creating anything (saas-dev has none of these tables, and neither does a fresh install).
    /// Model-neutral: the snapshot already describes them. Idempotent, so a database that does have them is unchanged.
    /// </remarks>
    public partial class CreateMissingSetupTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
CREATE TABLE IF NOT EXISTS accounting.acc_accounting_rules (
    id text NOT NULL,
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    name text NOT NULL,
    event text NOT NULL,
    source_id text NOT NULL,
    description text,
    is_active boolean NOT NULL,
    postings_count integer NOT NULL,
    sample_json jsonb NOT NULL DEFAULT ('{}'::jsonb),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id text,
    updated_by_id text,
    CONSTRAINT pk_acc_accounting_rules PRIMARY KEY (id),
    CONSTRAINT ck_acc_accounting_rules_bus_id CHECK (btrim(bus_id) <> '')
);

CREATE TABLE IF NOT EXISTS accounting.acc_accounting_rule_lines (
    id text NOT NULL,
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    rule_id text NOT NULL,
    line_no integer NOT NULL,
    account_id text NOT NULL,
    side text NOT NULL,
    amount_basis text NOT NULL,
    description text,
    CONSTRAINT pk_acc_accounting_rule_lines PRIMARY KEY (id),
    CONSTRAINT ck_acc_accounting_rule_lines_bus_id CHECK (btrim(bus_id) <> ''),
    CONSTRAINT fk_acc_accounting_rule_lines_acc_accounting_rules_rule_id FOREIGN KEY (rule_id) REFERENCES accounting.acc_accounting_rules (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS accounting.acc_currencies (
    id text NOT NULL,
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    symbol text NOT NULL,
    is_active boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id text,
    updated_by_id text,
    CONSTRAINT pk_acc_currencies PRIMARY KEY (id),
    CONSTRAINT ck_acc_currencies_bus_id CHECK (btrim(bus_id) <> '')
);

CREATE TABLE IF NOT EXISTS accounting.acc_dimensions (
    id text NOT NULL,
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    kind text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    is_active boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id text,
    updated_by_id text,
    CONSTRAINT pk_acc_dimensions PRIMARY KEY (id),
    CONSTRAINT ck_acc_dimensions_bus_id CHECK (btrim(bus_id) <> '')
);

CREATE TABLE IF NOT EXISTS accounting.acc_tax_codes (
    id text NOT NULL,
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    rate numeric(8,6) NOT NULL,
    kind text NOT NULL,
    output_account_id text,
    input_account_id text,
    description text,
    is_active boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id text,
    updated_by_id text,
    CONSTRAINT pk_acc_tax_codes PRIMARY KEY (id),
    CONSTRAINT ck_acc_tax_codes_bus_id CHECK (btrim(bus_id) <> '')
);

CREATE INDEX IF NOT EXISTS ix_acc_accounting_rule_lines_rule_id ON accounting.acc_accounting_rule_lines (rule_id);

CREATE INDEX IF NOT EXISTS ix_acc_accounting_rule_lines_tenant_id_org_id_bus_id_rule_id ON accounting.acc_accounting_rule_lines (tenant_id, org_id, bus_id, rule_id);

CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_accounting_rules_tenant_id_org_id_bus_id_source_id_event ON accounting.acc_accounting_rules (tenant_id, org_id, bus_id, source_id, event);

CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_currencies_tenant_id_org_id_bus_id_code ON accounting.acc_currencies (tenant_id, org_id, bus_id, code);

CREATE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_bus_id_kind ON accounting.acc_dimensions (tenant_id, org_id, bus_id, kind);

CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_dimensions_tenant_id_org_id_bus_id_kind_code ON accounting.acc_dimensions (tenant_id, org_id, bus_id, kind, code);

CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_bus_id_code ON accounting.acc_tax_codes (tenant_id, org_id, bus_id, code);

CREATE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_bus_id_kind ON accounting.acc_tax_codes (tenant_id, org_id, bus_id, kind);

DO $triggers$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['acc_accounting_rules', 'acc_accounting_rule_lines', 'acc_currencies', 'acc_dimensions', 'acc_tax_codes'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_fill_bus_id ON accounting.%I', t, t);
        EXECUTE format('CREATE TRIGGER trg_%s_fill_bus_id BEFORE INSERT ON accounting.%I FOR EACH ROW EXECUTE FUNCTION accounting.acc_fill_bus_id()', t, t);
    END LOOP;
END $triggers$;
""");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Kept: these tables are part of the model, and they may hold a business's setup by now.
        }
    }
}
