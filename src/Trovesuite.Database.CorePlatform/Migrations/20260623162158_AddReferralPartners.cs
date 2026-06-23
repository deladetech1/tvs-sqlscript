using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddReferralPartners : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "cp_referral_partners",
                schema: "core_platform",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    fullname = table.Column<string>(type: "text", nullable: false),
                    whatsapp_number = table.Column<string>(type: "text", nullable: false),
                    address = table.Column<string>(type: "text", nullable: false),
                    profession = table.Column<string>(type: "text", nullable: false),
                    products = table.Column<string>(type: "text", nullable: false),
                    consent = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_cp_referral_partners", x => x.id);
                    table.CheckConstraint("ck_cp_referral_partners_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "cp_referral_partners",
                schema: "core_platform");
        }
    }
}
