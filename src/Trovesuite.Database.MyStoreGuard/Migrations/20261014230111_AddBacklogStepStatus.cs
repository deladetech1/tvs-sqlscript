using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddBacklogStepStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_task_steps_status",
                schema: "mystoreguard",
                table: "msg_task_steps");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_task_steps_status",
                schema: "mystoreguard",
                table: "msg_task_steps",
                sql: "status IN ('BACKLOG','TODO','IN_PROGRESS','DONE','COMPLETED','CANCELLED')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_task_steps_status",
                schema: "mystoreguard",
                table: "msg_task_steps");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_task_steps_status",
                schema: "mystoreguard",
                table: "msg_task_steps",
                sql: "status IN ('TODO','IN_PROGRESS','DONE','COMPLETED','CANCELLED')");
        }
    }
}
