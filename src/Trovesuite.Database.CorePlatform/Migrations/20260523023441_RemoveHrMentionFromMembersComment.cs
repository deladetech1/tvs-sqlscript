using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class RemoveHrMentionFromMembersComment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterTable(
                name: "cp_members",
                schema: "core_platform",
                comment: "Rows here are users added directly at the core-platform level, NOT app-onboarded users.",
                oldComment: "Rows here are users added directly at the core-platform level. HR-onboarded users live in cp_users + human_resource.hr_employees, NOT here.");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterTable(
                name: "cp_members",
                schema: "core_platform",
                comment: "Rows here are users added directly at the core-platform level. HR-onboarded users live in cp_users + human_resource.hr_employees, NOT here.",
                oldComment: "Rows here are users added directly at the core-platform level, NOT app-onboarded users.");
        }
    }
}
