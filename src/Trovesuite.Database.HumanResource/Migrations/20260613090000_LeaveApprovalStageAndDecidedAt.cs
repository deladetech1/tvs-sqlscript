using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260613090000_LeaveApprovalStageAndDecidedAt")]
    public partial class LeaveApprovalStageAndDecidedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "approval_stage",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "character varying(40)",
                maxLength: 40,
                nullable: false,
                defaultValue: "pending_line_manager");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "hod_approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "hod_decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "lm_approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "lm_decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE zeloshr.zhr_leave_requests
                SET approval_stage = 'approved'
                WHERE status = 'Approved';

                UPDATE zeloshr.zhr_leave_requests
                SET approval_stage = 'rejected'
                WHERE status = 'Rejected';

                UPDATE zeloshr.zhr_leave_requests
                SET approval_stage = 'pending_final'
                WHERE status = 'Pending';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "approval_stage",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "hod_approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "hod_decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "lm_approver_id",
                schema: "zeloshr",
                table: "zhr_leave_requests");

            migrationBuilder.DropColumn(
                name: "lm_decided_at",
                schema: "zeloshr",
                table: "zhr_leave_requests");
        }
    }
}
