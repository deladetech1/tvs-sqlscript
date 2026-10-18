using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class ClientsBelongToTheBusiness : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // A client belongs to the business, not to a branch. Collateral's key to the client is
            // made by migrations/shared/20260927-01-loandrift-collateral-and-agreements.sql (not EF) and leans on the key being
            // rebuilt here, so it goes first; that file puts it back on (business, client).
            migrationBuilder.Sql("ALTER TABLE IF EXISTS loandrift.ld_collaterals DROP CONSTRAINT IF EXISTS fk_ld_collaterals_client;");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_businesses_clients_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_client_businesses");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_documents_paths_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_documents_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_identifications_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_identifications");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_clients_comments_clients_tenant_id_org_id_bus_id_loc_id_",
                schema: "loandrift",
                table: "ld_clients_comments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_credit_scores_ld_clients_tenant_id_org_id_bus_id_loc_id_",
                schema: "loandrift",
                table: "ld_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_guarantors_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_investment_transactions_ld_clients_tenant_id_org_id_bus_",
                schema: "loandrift",
                table: "ld_investment_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_investments_ld_clients_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_investments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_loan_details_ld_clients_tenant_id_org_id_bus_id_loc_id_c",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_penalties_ld_clients_tenant_id_org_id_bus_id_loc_id_clie",
                schema: "loandrift",
                table: "ld_penalties");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_penalty_waivers_ld_clients_tenant_id_org_id_bus_id_loc_i",
                schema: "loandrift",
                table: "ld_penalty_waivers");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_repayments_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_savings_accounts_ld_clients_tenant_id_org_id_bus_id_loc_",
                schema: "loandrift",
                table: "ld_savings_accounts");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_savings_transactions_ld_clients_tenant_id_org_id_bus_id_",
                schema: "loandrift",
                table: "ld_savings_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_loc_id_clie",
                schema: "loandrift",
                table: "ld_savings_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_savings_accounts");

            migrationBuilder.DropIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_penalty_waivers");

            migrationBuilder.DropIndex(
                name: "ix_ld_loan_details_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_investments");

            migrationBuilder.DropIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_loc_id_c",
                schema: "loandrift",
                table: "ld_investment_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_clients_comments");

            migrationBuilder.DropPrimaryKey(
                name: "ak_clients_tenant_id_org_id_bus_id_loc_id_id",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_contact",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_email",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_client_documents_paths");

            migrationBuilder.DropIndex(
                name: "ix_ld_client_businesses_tenant_id_org_id_bus_id_loc_id_client_",
                schema: "loandrift",
                table: "ld_client_businesses");

            migrationBuilder.AddUniqueConstraint(
                name: "ak_clients_tenant_id_org_id_bus_id_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "id" });

            migrationBuilder.AddPrimaryKey(
                name: "pk_ld_clients",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalties_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_credit_scores_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_contact",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "contact" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_email",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "email" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_businesses_clients_tenant_id_org_id_bus_id_client",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_documents_paths_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_identifications_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_clients_comments_clients_tenant_id_org_id_bus_id_client_",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_credit_scores_ld_clients_tenant_id_org_id_bus_id_client_",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_guarantors_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_investment_transactions_ld_clients_tenant_id_org_id_bus_",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_investments_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_loan_details_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_penalties_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_penalty_waivers_ld_clients_tenant_id_org_id_bus_id_clien",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_repayments_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_savings_accounts_ld_clients_tenant_id_org_id_bus_id_clie",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_savings_transactions_ld_clients_tenant_id_org_id_bus_id_",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_businesses_clients_tenant_id_org_id_bus_id_client",
                schema: "loandrift",
                table: "ld_client_businesses");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_documents_paths_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_documents_paths");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_client_identifications_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_identifications");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_clients_comments_clients_tenant_id_org_id_bus_id_client_",
                schema: "loandrift",
                table: "ld_clients_comments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_credit_scores_ld_clients_tenant_id_org_id_bus_id_client_",
                schema: "loandrift",
                table: "ld_credit_scores");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_guarantors_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_investment_transactions_ld_clients_tenant_id_org_id_bus_",
                schema: "loandrift",
                table: "ld_investment_transactions");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_investments_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_loan_details_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_penalties_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalties");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_penalty_waivers_ld_clients_tenant_id_org_id_bus_id_clien",
                schema: "loandrift",
                table: "ld_penalty_waivers");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_repayments_ld_clients_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_savings_accounts_ld_clients_tenant_id_org_id_bus_id_clie",
                schema: "loandrift",
                table: "ld_savings_accounts");

            migrationBuilder.DropForeignKey(
                name: "fk_ld_savings_transactions_ld_clients_tenant_id_org_id_bus_id_",
                schema: "loandrift",
                table: "ld_savings_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_savings_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_savings_accounts");

            migrationBuilder.DropIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalty_waivers");

            migrationBuilder.DropIndex(
                name: "ix_ld_penalties_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_penalties");

            migrationBuilder.DropIndex(
                name: "ix_ld_loan_details_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details");

            migrationBuilder.DropIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investments");

            migrationBuilder.DropIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_investment_transactions");

            migrationBuilder.DropIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropIndex(
                name: "ix_ld_credit_scores_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_credit_scores");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_clients_comments");

            migrationBuilder.DropUniqueConstraint(
                name: "ak_clients_tenant_id_org_id_bus_id_id",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropPrimaryKey(
                name: "pk_ld_clients",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_contact",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_email",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropIndex(
                name: "ix_ld_client_identifications_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_identifications");

            migrationBuilder.DropIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_documents_paths");

            migrationBuilder.DropIndex(
                name: "ix_ld_client_businesses_tenant_id_org_id_bus_id_client_id",
                schema: "loandrift",
                table: "ld_client_businesses");

            migrationBuilder.AddPrimaryKey(
                name: "ak_clients_tenant_id_org_id_bus_id_loc_id_id",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_transactions_tenant_id_org_id_bus_id_loc_id_clie",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_savings_accounts_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_repayments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_penalty_waivers_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_loan_details_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_investment_transactions_tenant_id_org_id_bus_id_loc_id_c",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantors_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_comments_tenant_id_org_id_bus_id_loc_id_client_id",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_contact",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "contact" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_clients_tenant_id_org_id_bus_id_loc_id_email",
                schema: "loandrift",
                table: "ld_clients",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "email" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_documents_paths_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_businesses_tenant_id_org_id_bus_id_loc_id_client_",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_businesses_clients_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_client_businesses",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_documents_paths_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_documents_paths",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_client_identifications_ld_clients_tenant_id_org_id_bus_i",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_clients_comments_clients_tenant_id_org_id_bus_id_loc_id_",
                schema: "loandrift",
                table: "ld_clients_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_credit_scores_ld_clients_tenant_id_org_id_bus_id_loc_id_",
                schema: "loandrift",
                table: "ld_credit_scores",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_guarantors_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                schema: "loandrift",
                table: "ld_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_investment_transactions_ld_clients_tenant_id_org_id_bus_",
                schema: "loandrift",
                table: "ld_investment_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_investments_ld_clients_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_investments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_loan_details_ld_clients_tenant_id_org_id_bus_id_loc_id_c",
                schema: "loandrift",
                table: "ld_loan_details",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_penalties_ld_clients_tenant_id_org_id_bus_id_loc_id_clie",
                schema: "loandrift",
                table: "ld_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_penalty_waivers_ld_clients_tenant_id_org_id_bus_id_loc_i",
                schema: "loandrift",
                table: "ld_penalty_waivers",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_repayments_ld_clients_tenant_id_org_id_bus_id_loc_id_cli",
                schema: "loandrift",
                table: "ld_repayments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_savings_accounts_ld_clients_tenant_id_org_id_bus_id_loc_",
                schema: "loandrift",
                table: "ld_savings_accounts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_ld_savings_transactions_ld_clients_tenant_id_org_id_bus_id_",
                schema: "loandrift",
                table: "ld_savings_transactions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                principalSchema: "loandrift",
                principalTable: "ld_clients",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Cascade);
        }
    }
}
