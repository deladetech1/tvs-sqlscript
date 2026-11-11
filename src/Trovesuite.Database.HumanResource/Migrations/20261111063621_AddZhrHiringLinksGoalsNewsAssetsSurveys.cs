using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrHiringLinksGoalsNewsAssetsSurveys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "recipients",
                schema: "zeloshr",
                table: "zhr_saved_reports",
                type: "jsonb",
                nullable: false,
                defaultValue: "[]");

            migrationBuilder.AddColumn<string>(
                name: "run_as",
                schema: "zeloshr",
                table: "zhr_saved_reports",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "careers",
                schema: "zeloshr",
                table: "zhr_job_postings",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.CreateTable(
                name: "zhr_announcement_reads",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    announcement_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    acknowledged_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_announcement_reads", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_announcements",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    body = table.Column<string>(type: "character varying(8000)", maxLength: 8000, nullable: false),
                    audience_kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "all"),
                    audience_value = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    posted_by = table.Column<string>(type: "text", nullable: true),
                    posted_by_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    posted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    pinned = table.Column<bool>(type: "boolean", nullable: false),
                    requires_ack = table.Column<bool>(type: "boolean", nullable: false),
                    archived = table.Column<bool>(type: "boolean", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_announcements", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_assets",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    tag = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    serial = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "in_stock"),
                    assigned_to = table.Column<Guid>(type: "uuid", nullable: true),
                    assigned_on = table.Column<DateOnly>(type: "date", nullable: true),
                    history = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "[]"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_assets", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_candidate_links",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    token = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    candidate_id = table.Column<Guid>(type: "uuid", nullable: false),
                    record_id = table.Column<Guid>(type: "uuid", nullable: true),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    starts_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ends_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    details = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_candidate_links", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_email_messages",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    kind = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    to_email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    to_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    subject = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    body = table.Column<string>(type: "text", nullable: false),
                    cta_label = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    cta_url = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    send_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "scheduled"),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    error = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    related_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    file_token = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    file_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    file_content = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_email_messages", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_goal_check_ins",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    goal_id = table.Column<Guid>(type: "uuid", nullable: false),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    by_employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    by_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    confidence = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    note = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    values = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_goal_check_ins", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_goals",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    title = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    description = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    level = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    owner_id = table.Column<Guid>(type: "uuid", nullable: true),
                    team = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    parent_id = table.Column<Guid>(type: "uuid", nullable: true),
                    cycle = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                    start_on = table.Column<DateOnly>(type: "date", nullable: false),
                    due_on = table.Column<DateOnly>(type: "date", nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    key_results = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "[]"),
                    created_by_employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    return_note = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_goals", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_hiring_records",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    kind = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    job_posting_id = table.Column<Guid>(type: "uuid", nullable: true),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    details = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_hiring_records", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_prehire_portals",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    token = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false, defaultValue: "invited"),
                    invited_on = table.Column<DateOnly>(type: "date", nullable: false),
                    expires_on = table.Column<DateOnly>(type: "date", nullable: false),
                    data = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    review = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    history = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "[]"),
                    submitted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    reviewed_by = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_prehire_portals", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_survey_participations",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    survey_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_survey_participations", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_survey_responses",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    survey_id = table.Column<Guid>(type: "uuid", nullable: false),
                    department = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    answers = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "{}"),
                    answered_on = table.Column<DateOnly>(type: "date", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_survey_responses", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_surveys",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    intro = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    questions = table.Column<string>(type: "jsonb", nullable: false, defaultValue: "[]"),
                    audience_kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "all"),
                    audience_value = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "draft"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    created_on = table.Column<DateOnly>(type: "date", nullable: false),
                    closes_on = table.Column<DateOnly>(type: "date", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_surveys", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_announcement_reads_announcement_id_employee_id",
                schema: "zeloshr",
                table: "zhr_announcement_reads",
                columns: new[] { "announcement_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_announcement_reads_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_announcement_reads",
                columns: new[] { "tenant_id", "org_id", "employee_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_announcements_tenant_id_org_id_posted_at",
                schema: "zeloshr",
                table: "zhr_announcements",
                columns: new[] { "tenant_id", "org_id", "posted_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_assets_tenant_id_org_id_assigned_to",
                schema: "zeloshr",
                table: "zhr_assets",
                columns: new[] { "tenant_id", "org_id", "assigned_to" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_assets_tenant_id_org_id_tag",
                schema: "zeloshr",
                table: "zhr_assets",
                columns: new[] { "tenant_id", "org_id", "tag" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_candidate_links_tenant_id_org_id_employee_id_starts_at",
                schema: "zeloshr",
                table: "zhr_candidate_links",
                columns: new[] { "tenant_id", "org_id", "employee_id", "starts_at" },
                unique: true,
                filter: "kind = 'booking' AND status = 'booked'");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_candidate_links_tenant_id_org_id_kind_candidate_id",
                schema: "zeloshr",
                table: "zhr_candidate_links",
                columns: new[] { "tenant_id", "org_id", "kind", "candidate_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_candidate_links_token",
                schema: "zeloshr",
                table: "zhr_candidate_links",
                column: "token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_email_messages_file_token",
                schema: "zeloshr",
                table: "zhr_email_messages",
                column: "file_token",
                unique: true,
                filter: "file_token IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_email_messages_status_send_at",
                schema: "zeloshr",
                table: "zhr_email_messages",
                columns: new[] { "status", "send_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_email_messages_tenant_id_org_id_created_at",
                schema: "zeloshr",
                table: "zhr_email_messages",
                columns: new[] { "tenant_id", "org_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_goal_check_ins_tenant_id_org_id_goal_id",
                schema: "zeloshr",
                table: "zhr_goal_check_ins",
                columns: new[] { "tenant_id", "org_id", "goal_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_goals_tenant_id_org_id_level",
                schema: "zeloshr",
                table: "zhr_goals",
                columns: new[] { "tenant_id", "org_id", "level" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_goals_tenant_id_org_id_owner_id",
                schema: "zeloshr",
                table: "zhr_goals",
                columns: new[] { "tenant_id", "org_id", "owner_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_hiring_records_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_hiring_records",
                columns: new[] { "tenant_id", "org_id", "employee_id" },
                unique: true,
                filter: "kind = 'availability'");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_hiring_records_tenant_id_org_id_kind",
                schema: "zeloshr",
                table: "zhr_hiring_records",
                columns: new[] { "tenant_id", "org_id", "kind" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_prehire_portals_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_prehire_portals",
                columns: new[] { "tenant_id", "org_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_prehire_portals_token",
                schema: "zeloshr",
                table: "zhr_prehire_portals",
                column: "token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_survey_participations_survey_id_employee_id",
                schema: "zeloshr",
                table: "zhr_survey_participations",
                columns: new[] { "survey_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_survey_responses_tenant_id_org_id_survey_id",
                schema: "zeloshr",
                table: "zhr_survey_responses",
                columns: new[] { "tenant_id", "org_id", "survey_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_surveys_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_surveys",
                columns: new[] { "tenant_id", "org_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_announcement_reads",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_announcements",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_assets",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_candidate_links",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_email_messages",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_goal_check_ins",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_goals",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_hiring_records",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_prehire_portals",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_survey_participations",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_survey_responses",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_surveys",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "recipients",
                schema: "zeloshr",
                table: "zhr_saved_reports");

            migrationBuilder.DropColumn(
                name: "run_as",
                schema: "zeloshr",
                table: "zhr_saved_reports");

            migrationBuilder.DropColumn(
                name: "careers",
                schema: "zeloshr",
                table: "zhr_job_postings");
        }
    }
}
