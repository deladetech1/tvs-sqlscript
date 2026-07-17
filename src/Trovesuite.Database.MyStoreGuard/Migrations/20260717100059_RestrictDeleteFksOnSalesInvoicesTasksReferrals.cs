using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class RestrictDeleteFksOnSalesInvoicesTasksReferrals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_referrals_customers_tenant_id_org_id_bus_id_c",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_referrals_sales_tenant_id_org_id_bus_id_loc_i",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoices_msg_affiliates_tenant_id_org_id_bus_id_affilia",
                schema: "mystoreguard",
                table: "msg_invoices");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoices_promo_codes_tenant_id_org_id_bus_id_promo_code",
                schema: "mystoreguard",
                table: "msg_invoices");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_promo_code_usage_msg_customers_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_promo_code_usage");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_msg_affiliates_tenant_id_org_id_bus_id_affiliate_",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_msg_promo_codes_tenant_id_org_id_bus_id_promo_cod",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_tasks_msg_customers_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_tasks");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_referrals_customers_tenant_id_org_id_bus_id_c",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_referrals_sales_tenant_id_org_id_bus_id_loc_i",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoices_msg_affiliates_tenant_id_org_id_bus_id_affilia",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliates",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoices_promo_codes_tenant_id_org_id_bus_id_promo_code",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_promo_codes",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_promo_code_usage_msg_customers_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_msg_affiliates_tenant_id_org_id_bus_id_affiliate_",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliates",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_msg_promo_codes_tenant_id_org_id_bus_id_promo_cod",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_promo_codes",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_tasks_msg_customers_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_referrals_customers_tenant_id_org_id_bus_id_c",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_referrals_sales_tenant_id_org_id_bus_id_loc_i",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoices_msg_affiliates_tenant_id_org_id_bus_id_affilia",
                schema: "mystoreguard",
                table: "msg_invoices");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoices_promo_codes_tenant_id_org_id_bus_id_promo_code",
                schema: "mystoreguard",
                table: "msg_invoices");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_promo_code_usage_msg_customers_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_promo_code_usage");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_msg_affiliates_tenant_id_org_id_bus_id_affiliate_",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_msg_promo_codes_tenant_id_org_id_bus_id_promo_cod",
                schema: "mystoreguard",
                table: "msg_sales");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_tasks_msg_customers_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_tasks");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_referrals_customers_tenant_id_org_id_bus_id_c",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_referrals_sales_tenant_id_org_id_bus_id_loc_i",
                schema: "mystoreguard",
                table: "msg_affiliate_referrals",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoices_msg_affiliates_tenant_id_org_id_bus_id_affilia",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliates",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoices_promo_codes_tenant_id_org_id_bus_id_promo_code",
                schema: "mystoreguard",
                table: "msg_invoices",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_promo_codes",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_promo_code_usage_msg_customers_tenant_id_org_id_bus_id_",
                schema: "mystoreguard",
                table: "msg_promo_code_usage",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_msg_affiliates_tenant_id_org_id_bus_id_affiliate_",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "affiliate_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliates",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_msg_promo_codes_tenant_id_org_id_bus_id_promo_cod",
                schema: "mystoreguard",
                table: "msg_sales",
                columns: new[] { "tenant_id", "org_id", "bus_id", "promo_code_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_promo_codes",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_tasks_msg_customers_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_tasks",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_customers",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);
        }
    }
}
