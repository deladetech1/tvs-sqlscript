using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrDisciplinaryOutcomeAndAudit : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "closed_on",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "outcome",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "closed_on",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "outcome",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");

            migrationBuilder.DropColumn(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_disciplinary_cases");
        }
    }
}
