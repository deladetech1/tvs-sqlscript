using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityLogScopeIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_msg_activity_logs_tenant_id",
                schema: "mystoreguard",
                table: "msg_activity_logs");

            migrationBuilder.CreateIndex(
                name: "idx_msg_activity_logs_scope",
                schema: "mystoreguard",
                table: "msg_activity_logs",
                columns: new[] { "tenant_id", "org_id", "bus_id", "cdatetime" },
                descending: new[] { false, false, false, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_msg_activity_logs_scope",
                schema: "mystoreguard",
                table: "msg_activity_logs");

            migrationBuilder.CreateIndex(
                name: "ix_msg_activity_logs_tenant_id",
                schema: "mystoreguard",
                table: "msg_activity_logs",
                column: "tenant_id");
        }
    }
}
