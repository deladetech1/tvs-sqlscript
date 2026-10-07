using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrCandidatesAndRequisitionFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "budget_monthly",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "hiring_manager_id",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "openings",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<DateOnly>(
                name: "target_start_date",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_candidates",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    job_posting_id = table.Column<Guid>(type: "uuid", nullable: false),
                    full_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    email = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    phone = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    source = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                    stage = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    rating = table.Column<int>(type: "integer", nullable: true),
                    notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    applied_on = table.Column<DateOnly>(type: "date", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_candidates", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_candidates_tenant_id_org_id_job_posting_id",
                schema: "zeloshr",
                table: "zhr_candidates",
                columns: new[] { "tenant_id", "org_id", "job_posting_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_candidates",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "budget_monthly",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "hiring_manager_id",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "openings",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "target_start_date",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_job_postings");

            migrationBuilder.DropColumn(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_job_postings");
        }
    }
}
