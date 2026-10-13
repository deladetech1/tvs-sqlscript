using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddMfaOtpExpiryMinutes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "otp_expiry_minutes",
                schema: "core_platform",
                table: "cp_multi_factor_settings",
                type: "integer",
                nullable: false,
                defaultValue: 3);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "otp_expiry_minutes",
                schema: "core_platform",
                table: "cp_multi_factor_settings");
        }
    }
}
