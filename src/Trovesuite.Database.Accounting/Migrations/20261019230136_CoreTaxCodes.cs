using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <summary>
    /// Tax codes follow Core Platform's taxes. Core Platform is the only place a tax is defined
    /// (core_platform.cp_tax_rates, its value dated in cp_tax_rate_versions, per business; migrations/shared
    /// 20261019-24); an Accounting tax code is a Core tax plus Accounting's settings for it (its code on document lines,
    /// the accounts it posts to, whether it is offered).
    /// </summary>
    /// <remarks>
    /// <list type="number">
    /// <item><c>acc_tax_codes.core_tax_rate_id</c>: the Core tax a code is, one code per Core tax per business.</item>
    /// <item><c>tax_rate</c> on invoice, bill, credit note and supplier credit lines: the rate (a fraction) the line
    /// was taxed at, the tax's rate on the document's date, so a later rate change in Core never changes a document
    /// already written. Existing lines are filled with their code's rate, which is what they were figured at.</item>
    /// <item>Existing codes are linked to a Core tax of the same business where exactly one matches and that tax
    /// matches no other code: a live percentage tax of the same kind (withholding → WITHHOLDING, exempt → EXEMPT,
    /// otherwise OUTPUT_INPUT), named as the code's name or code (or with that short name), charging the code's rate
    /// today. The rest stay unlinked, keep their own rate and are flagged in Accounting ("Link to a Trovesuite tax").</item>
    /// <item>A linked code's output account is where its tax's posting role (TAX:&lt;core id&gt;, other apps'
    /// postings) posts, so a separate mapping of that role in acc_posting_accounts is removed: one account per tax.</item>
    /// </list>
    /// Every statement is safe to run again, and the linking step does nothing where Core's taxes are absent.
    /// </remarks>
    public partial class CoreTaxCodes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
ALTER TABLE accounting.acc_tax_codes ADD COLUMN IF NOT EXISTS core_tax_rate_id text;
ALTER TABLE accounting.acc_sales_invoice_lines ADD COLUMN IF NOT EXISTS tax_rate numeric(8,6);
ALTER TABLE accounting.acc_purchase_bill_lines ADD COLUMN IF NOT EXISTS tax_rate numeric(8,6);
ALTER TABLE accounting.acc_credit_note_lines ADD COLUMN IF NOT EXISTS tax_rate numeric(8,6);
ALTER TABLE accounting.acc_supplier_credit_lines ADD COLUMN IF NOT EXISTS tax_rate numeric(8,6);
CREATE UNIQUE INDEX IF NOT EXISTS ix_acc_tax_codes_tenant_id_org_id_bus_id_core_tax_rate_id
    ON accounting.acc_tax_codes (tenant_id, org_id, bus_id, core_tax_rate_id) WHERE core_tax_rate_id IS NOT NULL;

-- What existing lines were figured at: their code's rate (exempt and withholding codes charge nothing on a line).
UPDATE accounting.acc_sales_invoice_lines l SET tax_rate = CASE WHEN t.kind = 'OUTPUT_INPUT' THEN t.rate ELSE 0 END
  FROM accounting.acc_tax_codes t WHERE l.tax_rate IS NULL AND t.id = l.tax_code_id;
UPDATE accounting.acc_purchase_bill_lines l SET tax_rate = CASE WHEN t.kind = 'OUTPUT_INPUT' THEN t.rate ELSE 0 END
  FROM accounting.acc_tax_codes t WHERE l.tax_rate IS NULL AND t.id = l.tax_code_id;
UPDATE accounting.acc_credit_note_lines l SET tax_rate = CASE WHEN t.kind = 'OUTPUT_INPUT' THEN t.rate ELSE 0 END
  FROM accounting.acc_tax_codes t WHERE l.tax_rate IS NULL AND t.id = l.tax_code_id;
UPDATE accounting.acc_supplier_credit_lines l SET tax_rate = CASE WHEN t.kind = 'OUTPUT_INPUT' THEN t.rate ELSE 0 END
  FROM accounting.acc_tax_codes t WHERE l.tax_rate IS NULL AND t.id = l.tax_code_id;

DO $link$
BEGIN
    IF to_regclass('core_platform.cp_tax_rates') IS NULL OR to_regclass('core_platform.cp_tax_rate_versions') IS NULL THEN
        RETURN;
    END IF;
    WITH candidates AS (
        SELECT t.id AS code_id, r.id AS rate_id
          FROM accounting.acc_tax_codes t
          JOIN core_platform.cp_tax_rates r
            ON r.tenant_id = t.tenant_id AND r.bus_id = t.bus_id
           AND r.archived_at IS NULL AND r.kind = 'percent'
           AND (CASE r.treatment WHEN 'withholding' THEN 'WITHHOLDING' WHEN 'exempt' THEN 'EXEMPT' ELSE 'OUTPUT_INPUT' END) = t.kind
           AND (lower(btrim(r.name)) IN (lower(btrim(t.name)), lower(btrim(t.code)))
                OR (btrim(r.short_name) <> '' AND lower(btrim(r.short_name)) IN (lower(btrim(t.name)), lower(btrim(t.code)))))
           AND round(coalesce((SELECT v.value FROM core_platform.cp_tax_rate_versions v
                                WHERE v.rate_id = r.id AND v.valid_from <= CURRENT_DATE
                                ORDER BY v.valid_from DESC LIMIT 1), 0) / 100, 6)
               = CASE WHEN t.kind = 'EXEMPT' THEN 0 ELSE t.rate END
         WHERE t.core_tax_rate_id IS NULL
           AND NOT EXISTS (SELECT 1 FROM accounting.acc_tax_codes x
                            WHERE x.tenant_id = t.tenant_id AND x.org_id = t.org_id AND x.bus_id = t.bus_id AND x.core_tax_rate_id = r.id)
    ), unique_pairs AS (
        SELECT c.code_id, c.rate_id FROM candidates c
         WHERE (SELECT count(*) FROM candidates o WHERE o.code_id = c.code_id) = 1
           AND (SELECT count(*) FROM candidates o WHERE o.rate_id = c.rate_id) = 1
    )
    UPDATE accounting.acc_tax_codes t SET core_tax_rate_id = p.rate_id, updated_at = now()
      FROM unique_pairs p WHERE t.id = p.code_id;
END
$link$;

-- One account per tax: a linked code's output account is its posting role's account.
DELETE FROM accounting.acc_posting_accounts p
 USING accounting.acc_tax_codes t
 WHERE t.core_tax_rate_id IS NOT NULL AND t.output_account_id IS NOT NULL
   AND p.tenant_id = t.tenant_id AND p.org_id = t.org_id AND p.bus_id = t.bus_id
   AND p.role = 'TAX:' || t.core_tax_rate_id;
""");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
DROP INDEX IF EXISTS accounting.ix_acc_tax_codes_tenant_id_org_id_bus_id_core_tax_rate_id;
ALTER TABLE accounting.acc_tax_codes DROP COLUMN IF EXISTS core_tax_rate_id;
ALTER TABLE accounting.acc_supplier_credit_lines DROP COLUMN IF EXISTS tax_rate;
ALTER TABLE accounting.acc_sales_invoice_lines DROP COLUMN IF EXISTS tax_rate;
ALTER TABLE accounting.acc_purchase_bill_lines DROP COLUMN IF EXISTS tax_rate;
ALTER TABLE accounting.acc_credit_note_lines DROP COLUMN IF EXISTS tax_rate;
""");
        }
    }
}
