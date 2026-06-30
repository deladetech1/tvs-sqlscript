using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddStepCollaborationAnchor : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" });

            migrationBuilder.AddForeignKey(
                name: "fk_msg_task_attachments_task_steps_tenant_id_org_id_bus_id_ste",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_task_steps",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_task_comment_mentions_task_steps_tenant_id_org_id_bus_i",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_task_steps",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "fk_msg_task_comments_task_steps_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "step_id" },
                principalSchema: "mystoreguard",
                principalTable: "msg_task_steps",
                principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_msg_task_attachments_task_steps_tenant_id_org_id_bus_id_ste",
                schema: "mystoreguard",
                table: "msg_task_attachments");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_task_comment_mentions_task_steps_tenant_id_org_id_bus_i",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions");

            migrationBuilder.DropForeignKey(
                name: "fk_msg_task_comments_task_steps_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comments");

            migrationBuilder.DropIndex(
                name: "ix_msg_task_comments_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comments");

            migrationBuilder.DropIndex(
                name: "ix_msg_task_comment_mentions_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions");

            migrationBuilder.DropIndex(
                name: "ix_msg_task_attachments_tenant_id_org_id_bus_id_step_id",
                schema: "mystoreguard",
                table: "msg_task_attachments");

            migrationBuilder.DropColumn(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_comments");

            migrationBuilder.DropColumn(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions");

            migrationBuilder.DropColumn(
                name: "step_id",
                schema: "mystoreguard",
                table: "msg_task_attachments");
        }
    }
}
