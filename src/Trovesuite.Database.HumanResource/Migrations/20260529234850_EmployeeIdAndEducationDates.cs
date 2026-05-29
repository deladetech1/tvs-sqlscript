using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class EmployeeIdAndEducationDates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "id_expiry_date",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "id_issue_date",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "end_date",
                schema: "zeloshr",
                table: "zhr_employee_education",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "start_date",
                schema: "zeloshr",
                table: "zhr_employee_education",
                type: "date",
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_employee_education
                SET start_date = make_date(start_year, 1, 1)
                WHERE start_date IS NULL AND start_year IS NOT NULL;

                UPDATE zeloshr.zhr_employee_education
                SET end_date = make_date(end_year, 12, 31)
                WHERE end_date IS NULL AND end_year IS NOT NULL;
                """);

            migrationBuilder.DropColumn(
                name: "end_year",
                schema: "zeloshr",
                table: "zhr_employee_education");

            migrationBuilder.DropColumn(
                name: "start_year",
                schema: "zeloshr",
                table: "zhr_employee_education");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "end_year",
                schema: "zeloshr",
                table: "zhr_employee_education",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "start_year",
                schema: "zeloshr",
                table: "zhr_employee_education",
                type: "integer",
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE zeloshr.zhr_employee_education
                SET start_year = EXTRACT(YEAR FROM start_date)::integer
                WHERE start_year IS NULL AND start_date IS NOT NULL;

                UPDATE zeloshr.zhr_employee_education
                SET end_year = EXTRACT(YEAR FROM end_date)::integer
                WHERE end_year IS NULL AND end_date IS NOT NULL;
                """);

            migrationBuilder.DropColumn(
                name: "id_expiry_date",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "id_issue_date",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "end_date",
                schema: "zeloshr",
                table: "zhr_employee_education");

            migrationBuilder.DropColumn(
                name: "start_date",
                schema: "zeloshr",
                table: "zhr_employee_education");
        }
    }
}
