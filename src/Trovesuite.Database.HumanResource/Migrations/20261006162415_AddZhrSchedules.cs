using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrSchedules : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "zhr_shifts",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: true),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    start = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: false),
                    end = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: false),
                    break_minutes = table.Column<int>(type: "integer", nullable: false),
                    position = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    branch_id = table.Column<Guid>(type: "uuid", nullable: true),
                    department_id = table.Column<Guid>(type: "uuid", nullable: true),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    state = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    changed_since_publish = table.Column<bool>(type: "boolean", nullable: false),
                    cancelled = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_shifts", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_work_patterns",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    days_json = table.Column<string>(type: "jsonb", nullable: false),
                    break_minutes = table.Column<int>(type: "integer", nullable: false),
                    break_paid = table.Column<bool>(type: "boolean", nullable: false),
                    grace_minutes = table.Column<int>(type: "integer", nullable: true),
                    archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_work_patterns", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_shift_changes",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    shift_id = table.Column<Guid>(type: "uuid", nullable: false),
                    action = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    summary = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    by = table.Column<string>(type: "text", nullable: true),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_shift_changes", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_shift_changes_zhr_shifts_shift_id",
                        column: x => x.shift_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_shifts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pattern_assignments",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    pattern_id = table.Column<Guid>(type: "uuid", nullable: true),
                    scope = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    target = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    effective_from = table.Column<DateOnly>(type: "date", nullable: false),
                    reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pattern_assignments", x => x.id);
                    table.ForeignKey(
                        name: "fk_zhr_pattern_assignments_zhr_work_patterns_pattern_id",
                        column: x => x.pattern_id,
                        principalSchema: "zeloshr",
                        principalTable: "zhr_work_patterns",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pattern_assignments_pattern_id",
                schema: "zeloshr",
                table: "zhr_pattern_assignments",
                column: "pattern_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pattern_assignments_tenant_id_org_id_effective_from",
                schema: "zeloshr",
                table: "zhr_pattern_assignments",
                columns: new[] { "tenant_id", "org_id", "effective_from" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_shift_changes_shift_id",
                schema: "zeloshr",
                table: "zhr_shift_changes",
                column: "shift_id");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_shifts_tenant_id_org_id_date",
                schema: "zeloshr",
                table: "zhr_shifts",
                columns: new[] { "tenant_id", "org_id", "date" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_shifts_tenant_id_org_id_employee_id_date",
                schema: "zeloshr",
                table: "zhr_shifts",
                columns: new[] { "tenant_id", "org_id", "employee_id", "date" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_work_patterns_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_work_patterns",
                columns: new[] { "tenant_id", "org_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_pattern_assignments",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_shift_changes",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_work_patterns",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_shifts",
                schema: "zeloshr");
        }
    }
}
