using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentVoidReason : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "void_reason",
                schema: "accounting",
                table: "acc_payments",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "voided_at",
                schema: "accounting",
                table: "acc_payments",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "void_reason",
                schema: "accounting",
                table: "acc_payments");

            migrationBuilder.DropColumn(
                name: "voided_at",
                schema: "accounting",
                table: "acc_payments");
        }
    }
}
