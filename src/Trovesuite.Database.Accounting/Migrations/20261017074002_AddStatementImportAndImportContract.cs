using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AddStatementImportAndImportContract : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "posted",
                schema: "accounting",
                table: "acc_import_records",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "entity",
                schema: "accounting",
                table: "acc_import_batches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "file_name",
                schema: "accounting",
                table: "acc_import_batches",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "journal_id",
                schema: "accounting",
                table: "acc_import_batches",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "number",
                schema: "accounting",
                table: "acc_import_batches",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<string>(
                name: "created_by_id",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "exclude_reason",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "reconciled_at",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "source",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "text",
                nullable: false,
                defaultValue: "FEED");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "now()");

            migrationBuilder.AddColumn<string>(
                name: "updated_by_id",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "last_import",
                schema: "accounting",
                table: "acc_bank_accounts",
                type: "jsonb",
                nullable: true);

            // Contract vocabulary (PROCESSING_RULES 14.4): number IMP-0001 per org by created_at,
            // rows POSTED -> VALID + posted, HELD -> ERROR; batches DRAFT -> NEEDS_REVIEW and
            // POSTED with held rows -> PARTIALLY_POSTED. Lines with an import_id came from a file.
            migrationBuilder.Sql("""
                UPDATE accounting.acc_import_batches b
                SET number = n.num, entity = 'Journals'
                FROM (
                    SELECT id, 'IMP-' || lpad(row_number() OVER (
                        PARTITION BY tenant_id, org_id ORDER BY created_at, id)::text, 4, '0') AS num
                    FROM accounting.acc_import_batches
                ) n
                WHERE n.id = b.id;

                UPDATE accounting.acc_import_records SET posted = true, status = 'VALID' WHERE status = 'POSTED';
                UPDATE accounting.acc_import_records SET status = 'ERROR' WHERE status = 'HELD';

                UPDATE accounting.acc_import_batches SET status = 'NEEDS_REVIEW' WHERE status = 'DRAFT';
                UPDATE accounting.acc_import_batches b SET status = 'PARTIALLY_POSTED'
                WHERE b.status = 'POSTED'
                  AND EXISTS (SELECT 1 FROM accounting.acc_import_records r WHERE r.batch_id = b.id AND r.status = 'ERROR');

                UPDATE accounting.acc_bank_statement_lines SET source = 'FILE' WHERE import_id IS NOT NULL;
                """);

            migrationBuilder.CreateIndex(
                name: "ix_acc_import_batches_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_import_batches",
                columns: new[] { "tenant_id", "org_id", "number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_i",
                schema: "accounting",
                table: "acc_bank_statement_lines",
                columns: new[] { "tenant_id", "org_id", "bank_account_id", "import_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_acc_import_batches_tenant_id_org_id_number",
                schema: "accounting",
                table: "acc_import_batches");

            migrationBuilder.DropIndex(
                name: "ix_acc_bank_statement_lines_tenant_id_org_id_bank_account_id_i",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "posted",
                schema: "accounting",
                table: "acc_import_records");

            migrationBuilder.DropColumn(
                name: "entity",
                schema: "accounting",
                table: "acc_import_batches");

            migrationBuilder.DropColumn(
                name: "file_name",
                schema: "accounting",
                table: "acc_import_batches");

            migrationBuilder.DropColumn(
                name: "journal_id",
                schema: "accounting",
                table: "acc_import_batches");

            migrationBuilder.DropColumn(
                name: "number",
                schema: "accounting",
                table: "acc_import_batches");

            migrationBuilder.DropColumn(
                name: "created_at",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "created_by_id",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "exclude_reason",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "reconciled_at",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "source",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "updated_at",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "updated_by_id",
                schema: "accounting",
                table: "acc_bank_statement_lines");

            migrationBuilder.DropColumn(
                name: "last_import",
                schema: "accounting",
                table: "acc_bank_accounts");
        }
    }
}
