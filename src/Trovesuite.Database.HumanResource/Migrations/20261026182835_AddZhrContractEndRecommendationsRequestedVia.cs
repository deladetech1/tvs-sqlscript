using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrContractEndRecommendationsRequestedVia : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "recommendation",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "recommendation_note",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "recommended_at",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "recommended_by",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "contract_end_date",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "requested_via",
                schema: "zeloshr",
                table: "zhr_compensation_versions",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "hr");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "recommendation",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "recommendation_note",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "recommended_at",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "recommended_by",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "contract_end_date",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "requested_via",
                schema: "zeloshr",
                table: "zhr_compensation_versions");
        }
    }
}
