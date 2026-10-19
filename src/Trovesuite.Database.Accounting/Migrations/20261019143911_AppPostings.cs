using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AppPostings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "acc_posting_accounts",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    role = table.Column<string>(type: "text", nullable: false),
                    account_id = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_posting_accounts", x => x.id);
                    table.CheckConstraint("ck_acc_posting_accounts_bus_id", "btrim(bus_id) <> ''");
                });

            migrationBuilder.CreateTable(
                name: "acc_posting_inbox",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    event_id = table.Column<long>(type: "bigint", nullable: false),
                    source_app = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    subject_id = table.Column<string>(type: "text", nullable: false),
                    document_number = table.Column<string>(type: "text", nullable: false),
                    document_date = table.Column<DateOnly>(type: "date", nullable: true),
                    amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    currency = table.Column<string>(type: "text", nullable: false),
                    payload_json = table.Column<string>(type: "jsonb", nullable: false, defaultValueSql: "'{}'::jsonb"),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "PENDING"),
                    reason = table.Column<string>(type: "text", nullable: true),
                    journal_id = table.Column<string>(type: "text", nullable: true),
                    attempts = table.Column<int>(type: "integer", nullable: false),
                    event_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    last_attempt_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    posted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by_id = table.Column<string>(type: "text", nullable: true),
                    updated_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_posting_inbox", x => x.id);
                    table.CheckConstraint("ck_acc_posting_inbox_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_posting_inbox_status", "status IN ('PENDING','POSTED','FAILED','SKIPPED')");
                });

            migrationBuilder.CreateIndex(
                name: "ux_acc_journal_entries_event",
                schema: "accounting",
                table: "acc_journal_entries",
                columns: new[] { "tenant_id", "org_id", "bus_id", "source_document_id" },
                unique: true,
                filter: "source_document_id LIKE 'evt:%'");

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_accounts_tenant_id_org_id_bus_id_role",
                schema: "accounting",
                table: "acc_posting_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "role" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_inbox_event_id",
                schema: "accounting",
                table: "acc_posting_inbox",
                column: "event_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_inbox_journal_id",
                schema: "accounting",
                table: "acc_posting_inbox",
                column: "journal_id",
                unique: true,
                filter: "journal_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_inbox_status_tenant_id_bus_id",
                schema: "accounting",
                table: "acc_posting_inbox",
                columns: new[] { "status", "tenant_id", "bus_id" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_inbox_tenant_id_org_id_bus_id_event_at",
                schema: "accounting",
                table: "acc_posting_inbox",
                columns: new[] { "tenant_id", "org_id", "bus_id", "event_at" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_posting_inbox_tenant_id_org_id_bus_id_status",
                schema: "accounting",
                table: "acc_posting_inbox",
                columns: new[] { "tenant_id", "org_id", "bus_id", "status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "acc_posting_accounts",
                schema: "accounting");

            migrationBuilder.DropTable(
                name: "acc_posting_inbox",
                schema: "accounting");

            migrationBuilder.DropIndex(
                name: "ux_acc_journal_entries_event",
                schema: "accounting",
                table: "acc_journal_entries");
        }
    }
}
