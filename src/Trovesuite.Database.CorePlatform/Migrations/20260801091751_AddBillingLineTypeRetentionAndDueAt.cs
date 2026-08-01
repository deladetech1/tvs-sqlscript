using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class AddBillingLineTypeRetentionAndDueAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "due_at",
                schema: "core_platform",
                table: "cp_billings_logs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "line_type",
                schema: "core_platform",
                table: "cp_billings_logs",
                type: "text",
                nullable: false,
                defaultValue: "SUBSCRIPTION");

            migrationBuilder.AddColumn<int>(
                name: "retention_days",
                schema: "core_platform",
                table: "cp_billings_logs",
                type: "integer",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "due_at",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropColumn(
                name: "line_type",
                schema: "core_platform",
                table: "cp_billings_logs");

            migrationBuilder.DropColumn(
                name: "retention_days",
                schema: "core_platform",
                table: "cp_billings_logs");
        }
    }
}
