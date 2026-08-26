using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddPolicyProductRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_policy_target_type",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.AddColumn<string>(
                name: "role",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                type: "text",
                nullable: false,
                defaultValue: "TARGET");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policy_products_role",
                schema: "mystoreguard",
                table: "msg_installment_policy_products",
                sql: "role IN ('TARGET','EXCEPT')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_policy_target_type",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "policy_target_type IN ('ALL_PRODUCTS','PRODUCT','PRODUCTS','SKU','TAG','LABEL','CATEGORY','BRAND')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policy_products_role",
                schema: "mystoreguard",
                table: "msg_installment_policy_products");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_installment_policies_policy_target_type",
                schema: "mystoreguard",
                table: "msg_installment_policies");

            migrationBuilder.DropColumn(
                name: "role",
                schema: "mystoreguard",
                table: "msg_installment_policy_products");

            migrationBuilder.AddColumn<string>(
                name: "product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                type: "text",
                nullable: false,
                defaultValue: "ALL");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_policy_target_type",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "policy_target_type IN ('ALL_PRODUCTS','PRODUCT','SKU','TAG','LABEL','CATEGORY','BRAND')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_installment_policies_product_scope",
                schema: "mystoreguard",
                table: "msg_installment_policies",
                sql: "product_scope IN ('ALL','INCLUDE','EXCLUDE')");
        }
    }
}
