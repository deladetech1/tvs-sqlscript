using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddReturnPlanSettlement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "cash_refund_amount",
                schema: "mystoreguard",
                table: "msg_returns",
                type: "numeric(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "installment_plan_id",
                schema: "mystoreguard",
                table: "msg_returns",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "plan_settled_amount",
                schema: "mystoreguard",
                table: "msg_returns",
                type: "numeric(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "plan_written_off_amount",
                schema: "mystoreguard",
                table: "msg_returns",
                type: "numeric(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateIndex(
                name: "ix_msg_returns_tenant_id_org_id_bus_id_loc_id_installment_plan",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "installment_plan_id" });

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_returns_plan_amounts",
                schema: "mystoreguard",
                table: "msg_returns",
                sql: "plan_settled_amount >= 0 AND plan_written_off_amount >= 0 AND cash_refund_amount >= 0");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_returns_plan_link",
                schema: "mystoreguard",
                table: "msg_returns",
                sql: "installment_plan_id IS NOT NULL OR (plan_settled_amount = 0 AND plan_written_off_amount = 0)");

            migrationBuilder.AddForeignKey(
                name: "fk_msg_returns_msg_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_returns",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "installment_plan_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_installment_plans",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_returns_msg_installment_plans_tenant_id_org_id_bus_id_l",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropIndex(
                name: "ix_msg_returns_tenant_id_org_id_bus_id_loc_id_installment_plan",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_returns_plan_amounts",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_returns_plan_link",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropColumn(
                name: "cash_refund_amount",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropColumn(
                name: "installment_plan_id",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropColumn(
                name: "plan_settled_amount",
                schema: "mystoreguard",
                table: "msg_returns");

            migrationBuilder.DropColumn(
                name: "plan_written_off_amount",
                schema: "mystoreguard",
                table: "msg_returns");
        }
    }
}
