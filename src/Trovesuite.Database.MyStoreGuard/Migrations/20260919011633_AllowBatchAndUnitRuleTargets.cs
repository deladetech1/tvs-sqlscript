using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AllowBatchAndUnitRuleTargets : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_tax_rule_rule_type",
                schema: "mystoreguard",
                table: "msg_tax_rule");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_tax_rule_rule_type",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                sql: "rule_type IN ('PRODUCT','ALL_PRODUCTS','CATEGORY','TAG','BRAND','LABEL','LOCATION','SKU','BATCH','UNIT')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                sql: "rule_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL','COLOR','CONDITION','BATCH','UNIT')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_tax_rule_rule_type",
                schema: "mystoreguard",
                table: "msg_tax_rule");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_tax_rule_rule_type",
                schema: "mystoreguard",
                table: "msg_tax_rule",
                sql: "rule_type IN ('PRODUCT','ALL_PRODUCTS','CATEGORY','TAG','BRAND','LABEL','LOCATION','SKU')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                sql: "rule_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL','COLOR','CONDITION')");
        }
    }
}
