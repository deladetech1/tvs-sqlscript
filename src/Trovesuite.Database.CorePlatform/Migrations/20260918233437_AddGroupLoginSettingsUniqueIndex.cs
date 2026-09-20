using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddGroupLoginSettingsUniqueIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_cp_login_settings_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings");

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "group_id", "tenant_id", "delete_status" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_group_tenant",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "group_id", "tenant_id" },
                unique: true,
                filter: "group_id IS NOT NULL AND delete_status = 'NOT_DELETED'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_cp_login_settings_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings");

            migrationBuilder.DropIndex(
                name: "ix_cp_login_settings_group_tenant",
                schema: "core_platform",
                table: "cp_login_settings");

            migrationBuilder.CreateIndex(
                name: "ix_cp_login_settings_group_id_tenant_id",
                schema: "core_platform",
                table: "cp_login_settings",
                columns: new[] { "group_id", "tenant_id" });
        }
    }
}
