using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AssetRevaluationOpeningCustomFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "custom_fields_json",
                schema: "accounting",
                table: "acc_recurring_templates",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'{}'::jsonb");

            migrationBuilder.AddColumn<decimal>(
                name: "basis_amount",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "basis_month",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "basis_months",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "opening_accumulated_depreciation",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateOnly>(
                name: "opening_date",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "opening_journal_id",
                schema: "accounting",
                table: "acc_fixed_assets",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "acc_asset_revaluations",
                schema: "accounting",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    asset_id = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    cost_before = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    accumulated_eliminated = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    carrying_before = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    fair_value = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    surplus_change = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    pnl_change = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    surplus_account_id = table.Column<string>(type: "text", nullable: true),
                    pnl_account_id = table.Column<string>(type: "text", nullable: true),
                    remaining_months = table.Column<int>(type: "integer", nullable: false),
                    journal_id = table.Column<string>(type: "text", nullable: false),
                    notes = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_acc_asset_revaluations", x => x.id);
                    table.CheckConstraint("ck_acc_asset_revaluations_bus_id", "btrim(bus_id) <> ''");
                    table.CheckConstraint("ck_acc_asset_revaluations_kind", "kind IN ('REVALUATION','SURPLUS_TRANSFER')");
                });

            migrationBuilder.CreateIndex(
                name: "ix_acc_asset_revaluations_tenant_id_org_id_bus_id_asset_id_date",
                schema: "accounting",
                table: "acc_asset_revaluations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "asset_id", "date" });

            migrationBuilder.CreateIndex(
                name: "ix_acc_asset_revaluations_tenant_id_org_id_bus_id_journal_id",
                schema: "accounting",
                table: "acc_asset_revaluations",
                columns: new[] { "tenant_id", "org_id", "bus_id", "journal_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "acc_asset_revaluations",
                schema: "accounting");

            migrationBuilder.DropColumn(
                name: "custom_fields_json",
                schema: "accounting",
                table: "acc_recurring_templates");

            migrationBuilder.DropColumn(
                name: "basis_amount",
                schema: "accounting",
                table: "acc_fixed_assets");

            migrationBuilder.DropColumn(
                name: "basis_month",
                schema: "accounting",
                table: "acc_fixed_assets");

            migrationBuilder.DropColumn(
                name: "basis_months",
                schema: "accounting",
                table: "acc_fixed_assets");

            migrationBuilder.DropColumn(
                name: "opening_accumulated_depreciation",
                schema: "accounting",
                table: "acc_fixed_assets");

            migrationBuilder.DropColumn(
                name: "opening_date",
                schema: "accounting",
                table: "acc_fixed_assets");

            migrationBuilder.DropColumn(
                name: "opening_journal_id",
                schema: "accounting",
                table: "acc_fixed_assets");
        }
    }
}
