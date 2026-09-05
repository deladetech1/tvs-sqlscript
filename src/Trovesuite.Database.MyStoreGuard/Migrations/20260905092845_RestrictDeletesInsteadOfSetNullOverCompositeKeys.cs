using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class RestrictDeletesInsteadOfSetNullOverCompositeKeys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_affiliate_referrals_tenant_id_org",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_sales_tenant_id_org_id_bus_id_loc",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_created_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_deleted_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_updated_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_collections_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_collections");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_credit_scores_installment_plans_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_card_transactions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_card_transactions_sales_tenant_id_org_id_bus_id_lo",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_cards_cp_users_purchased_by_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoice_payments_msg_gift_cards_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_invoice_payments");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_payments_msg_gift_cards_tenant_id_org_id_bus_id_g",
                schema: "mystoreguard",
                table: "msg_sales_payments");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_store_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_warehouse_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_affiliate_referrals_tenant_id_org",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "referral_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliate_referrals",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "loc_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_locations",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_sales_tenant_id_org_id_bus_id_loc",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_created_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "created_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_deleted_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "deleted_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_updated_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "updated_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_collections_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_installment_plans",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_credit_scores_installment_plans_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_installment_plans",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "created_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "deleted_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "updated_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_card_transactions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "loc_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_locations",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_card_transactions_sales_tenant_id_org_id_bus_id_lo",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_cards_cp_users_purchased_by_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "purchased_by_user_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoice_payments_msg_gift_cards_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_invoice_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_gift_cards",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_payments_msg_gift_cards_tenant_id_org_id_bus_id_g",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_gift_cards",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_store_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "manager_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_warehouse_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "manager_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_affiliate_referrals_tenant_id_org",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_affiliate_commissions_sales_tenant_id_org_id_bus_id_loc",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_created_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_deleted_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_updated_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_collections_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_collections");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_credit_scores_installment_plans_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_document_paths_cp_users_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_card_transactions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_card_transactions_sales_tenant_id_org_id_bus_id_lo",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_gift_cards_cp_users_purchased_by_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_invoice_payments_msg_gift_cards_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_invoice_payments");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_sales_payments_msg_gift_cards_tenant_id_org_id_bus_id_g",
                schema: "mystoreguard",
                table: "msg_sales_payments");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_store_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_warehouse_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_affiliate_referrals_tenant_id_org",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "referral_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_affiliate_referrals",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "loc_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_locations",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_affiliate_commissions_sales_tenant_id_org_id_bus_id_loc",
                schema: "mystoreguard",
                table: "msg_affiliate_commissions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_created_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "created_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_deleted_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "deleted_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_assign_metadata_to_products_cp_users_updated_by_tenant_",
                schema: "mystoreguard",
                table: "msg_assign_metadata_to_products",
                columns: new[] { "updated_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_collections_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_collections",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_installment_plans",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_credit_scores_installment_plans_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_installment_plans",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "created_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "deleted_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_document_paths_cp_users_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_document_paths",
                columns: new[] { "updated_by", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_card_transactions_cp_locations_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "loc_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_locations",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_card_transactions_sales_tenant_id_org_id_bus_id_lo",
                schema: "mystoreguard",
                table: "msg_gift_card_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_sales",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_gift_cards_cp_users_purchased_by_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_gift_cards",
                columns: new[] { "purchased_by_user_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_invoice_payments_msg_gift_cards_tenant_id_org_id_bus_id",
                schema: "mystoreguard",
                table: "msg_invoice_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_gift_cards",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_sales_payments_msg_gift_cards_tenant_id_org_id_bus_id_g",
                schema: "mystoreguard",
                table: "msg_sales_payments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "gift_card_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_gift_cards",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_store_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_store_configs",
                columns: new[] { "manager_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_warehouse_configs_cp_users_manager_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_warehouse_configs",
                columns: new[] { "manager_id", "tenant_id" },
                principalSchema: "core_platform",
                principalTable: "cp_users",
                principalColumns: new[] { "id", "tenant_id" },
                onDelete: ReferentialAction.SetNull);
        }
    }
}
