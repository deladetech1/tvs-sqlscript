using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddLoginSecuritySettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "lock_reason",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "locked_at",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "unlocked_at",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "unlocked_by",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "allow_password_reuse",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "enforce_password_expiry",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "expiry_applies_to_owner",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "password_expiry_unit",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "text",
                nullable: false,
                defaultValue: "DAYS");

            migrationBuilder.AddColumn<int>(
                name: "password_expiry_value",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "integer",
                nullable: false,
                defaultValue: 90);

            migrationBuilder.AddColumn<int>(
                name: "password_history_count",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "integer",
                nullable: false,
                defaultValue: 5);

            migrationBuilder.AddColumn<bool>(
                name: "reuse_applies_to_owner",
                schema: "core_platform",
                table: "cp_password_policies",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "cp_account_lockout_settings",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    is_enabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    max_failed_attempts = table.Column<int>(type: "integer", nullable: false, defaultValue: 5),
                    release_mode = table.Column<string>(type: "text", nullable: false, defaultValue: "AUTOMATIC"),
                    lockout_duration_minutes = table.Column<int>(type: "integer", nullable: false, defaultValue: 30),
                    applies_to_owner = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_account_lockout_settings", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_account_lockout_settings_attempts", "max_failed_attempts >= 1");
                    table.CheckConstraint("ck_cp_account_lockout_settings_duration", "lockout_duration_minutes >= 1");
                    table.CheckConstraint("ck_cp_account_lockout_settings_release_mode", "release_mode IN ('AUTOMATIC','MANUAL')");
                    table.ForeignKey(
                        name: "fk_cp_account_lockout_settings_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_account_lockout_settings_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_account_lockout_settings_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "cp_session_settings",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    session_timeout_minutes = table.Column<int>(type: "integer", nullable: false, defaultValue: 1440),
                    applies_to_owner = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_session_settings", x => new { x.id, x.tenant_id });
                    table.CheckConstraint("ck_cp_session_settings_timeout", "session_timeout_minutes >= 1");
                    table.ForeignKey(
                        name: "fk_cp_session_settings_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_cp_session_settings_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_cp_session_settings_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_cp_user_login_tracking_locked",
                schema: "core_platform",
                table: "cp_user_login_tracking",
                columns: new[] { "tenant_id", "is_locked" },
                filter: "is_locked = true");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_password_policies_expiry_value",
                schema: "core_platform",
                table: "cp_password_policies",
                sql: "password_expiry_value >= 1");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_password_policies_history_count",
                schema: "core_platform",
                table: "cp_password_policies",
                sql: "password_history_count >= 1");

            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_password_policies_password_expiry_unit",
                schema: "core_platform",
                table: "cp_password_policies",
                sql: "password_expiry_unit IN ('DAYS','WEEKS','MONTHS','QUARTERS','SEMI_ANNUAL','YEARS')");

            migrationBuilder.CreateIndex(
                name: "ix_cp_account_lockout_settings_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_account_lockout_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_account_lockout_settings_tenant_id",
                schema: "core_platform",
                table: "cp_account_lockout_settings",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_account_lockout_settings_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_account_lockout_settings",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_session_settings_created_by_tenant_id",
                schema: "core_platform",
                table: "cp_session_settings",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_cp_session_settings_tenant_id",
                schema: "core_platform",
                table: "cp_session_settings",
                column: "tenant_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_cp_session_settings_updated_by_tenant_id",
                schema: "core_platform",
                table: "cp_session_settings",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "cp_account_lockout_settings",
                schema: "core_platform");

            migrationBuilder.DropTable(
                name: "cp_session_settings",
                schema: "core_platform");

            migrationBuilder.DropIndex(
                name: "ix_cp_user_login_tracking_locked",
                schema: "core_platform",
                table: "cp_user_login_tracking");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_password_policies_expiry_value",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_password_policies_history_count",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_password_policies_password_expiry_unit",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "lock_reason",
                schema: "core_platform",
                table: "cp_user_login_tracking");

            migrationBuilder.DropColumn(
                name: "locked_at",
                schema: "core_platform",
                table: "cp_user_login_tracking");

            migrationBuilder.DropColumn(
                name: "unlocked_at",
                schema: "core_platform",
                table: "cp_user_login_tracking");

            migrationBuilder.DropColumn(
                name: "unlocked_by",
                schema: "core_platform",
                table: "cp_user_login_tracking");

            migrationBuilder.DropColumn(
                name: "allow_password_reuse",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "enforce_password_expiry",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "expiry_applies_to_owner",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "password_expiry_unit",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "password_expiry_value",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "password_history_count",
                schema: "core_platform",
                table: "cp_password_policies");

            migrationBuilder.DropColumn(
                name: "reuse_applies_to_owner",
                schema: "core_platform",
                table: "cp_password_policies");
        }
    }
}
