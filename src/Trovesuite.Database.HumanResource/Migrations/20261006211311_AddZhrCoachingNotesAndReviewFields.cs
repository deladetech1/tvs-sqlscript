using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrCoachingNotesAndReviewFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "rating",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "numeric(2,1)",
                precision: 2,
                scale: 1,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "reviewer_id",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "shared_on",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "NOW()");

            migrationBuilder.AddColumn<string>(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_performance_reviews",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_coaching_notes",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    author_id = table.Column<string>(type: "text", nullable: false),
                    body = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    escalated = table.Column<bool>(type: "boolean", nullable: false),
                    escalated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_coaching_notes", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_coaching_notes_tenant_id_org_id_author_id",
                schema: "zeloshr",
                table: "zhr_coaching_notes",
                columns: new[] { "tenant_id", "org_id", "author_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_coaching_notes",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "created_at",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "created_by",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "rating",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "reviewer_id",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "shared_on",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "updated_at",
                schema: "zeloshr",
                table: "zhr_performance_reviews");

            migrationBuilder.DropColumn(
                name: "updated_by",
                schema: "zeloshr",
                table: "zhr_performance_reviews");
        }
    }
}
