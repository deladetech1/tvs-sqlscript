using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations;

public partial class AddOrgSettingsWireFields : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(name: "tin", schema: "accounting", table: "acc_org_settings", type: "text", nullable: false, defaultValue: "");
        migrationBuilder.AddColumn<string>(name: "address", schema: "accounting", table: "acc_org_settings", type: "text", nullable: false, defaultValue: "");
        migrationBuilder.AddColumn<string>(name: "email", schema: "accounting", table: "acc_org_settings", type: "text", nullable: false, defaultValue: "");
        migrationBuilder.AddColumn<string>(name: "phone", schema: "accounting", table: "acc_org_settings", type: "text", nullable: false, defaultValue: "");
        migrationBuilder.AddColumn<string>(name: "fiscal_year_start", schema: "accounting", table: "acc_org_settings", type: "text", nullable: false, defaultValue: "01-01");
        migrationBuilder.AddColumn<decimal>(name: "approval_threshold", schema: "accounting", table: "acc_org_settings", type: "numeric(18,2)", nullable: false, defaultValue: 50000m);
        migrationBuilder.AddColumn<bool>(name: "require_approval_for_manual_journals", schema: "accounting", table: "acc_org_settings", type: "boolean", nullable: false, defaultValue: true);
        migrationBuilder.AddColumn<bool>(name: "block_posting_to_locked_periods", schema: "accounting", table: "acc_org_settings", type: "boolean", nullable: false, defaultValue: true);
        migrationBuilder.AddColumn<DateOnly>(name: "conversion_date", schema: "accounting", table: "acc_org_settings", type: "date", nullable: true);

        migrationBuilder.Sql("""
            UPDATE accounting.acc_org_settings
            SET fiscal_year_start = lpad(fiscal_year_start_month::text, 2, '0') || '-01';
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "tin", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "address", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "email", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "phone", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "fiscal_year_start", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "approval_threshold", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "require_approval_for_manual_journals", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "block_posting_to_locked_periods", schema: "accounting", table: "acc_org_settings");
        migrationBuilder.DropColumn(name: "conversion_date", schema: "accounting", table: "acc_org_settings");
    }
}
