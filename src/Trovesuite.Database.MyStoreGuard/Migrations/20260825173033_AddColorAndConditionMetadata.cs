using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddColorAndConditionMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_prices_of_type",
                schema: "mystoreguard",
                table: "msg_product_prices");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_metadata_of_type",
                schema: "mystoreguard",
                table: "msg_product_metadata");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_prices_of_type",
                schema: "mystoreguard",
                table: "msg_product_prices",
                sql: "of_type IN ('SKU','GLOBAL','LOCATION','TAG','CATEGORY','BRAND','LABEL','COLOR','CONDITION')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_metadata_of_type",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                sql: "of_type IN ('TAG','CATEGORY','BRAND','LABEL','COLOR','CONDITION')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                sql: "rule_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL','COLOR','CONDITION')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_prices_of_type",
                schema: "mystoreguard",
                table: "msg_product_prices");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_product_metadata_of_type",
                schema: "mystoreguard",
                table: "msg_product_metadata");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_prices_of_type",
                schema: "mystoreguard",
                table: "msg_product_prices",
                sql: "of_type IN ('SKU','GLOBAL','LOCATION','TAG','CATEGORY','BRAND','LABEL')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_product_metadata_of_type",
                schema: "mystoreguard",
                table: "msg_product_metadata",
                sql: "of_type IN ('TAG','CATEGORY','BRAND','LABEL')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_pricing_rule_rule_target_type",
                schema: "mystoreguard",
                table: "msg_pricing_rule",
                sql: "rule_target_type IN ('PRODUCT','ALL_PRODUCTS','SKU','LOCATION','TAG','CATEGORY','BRAND','LABEL')");
        }
    }
}
