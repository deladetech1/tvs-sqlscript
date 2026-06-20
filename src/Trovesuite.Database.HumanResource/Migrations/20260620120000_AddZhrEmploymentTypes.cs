using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Trovesuite.Database.HumanResource;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(HumanResourceDbContext))]
    [Migration("20260620120000_AddZhrEmploymentTypes")]
    public partial class AddZhrEmploymentTypes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "zhr_employment_types",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_system_default = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_employment_types", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employment_types_tenant_id_org_id_is_active",
                schema: "zeloshr",
                table: "zhr_employment_types",
                columns: new[] { "tenant_id", "org_id", "is_active" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employment_types_tenant_id_org_id_name",
                schema: "zeloshr",
                table: "zhr_employment_types",
                columns: new[] { "tenant_id", "org_id", "name" },
                unique: true);

            migrationBuilder.AddColumn<Guid>(
                name: "employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "employment_type_id");

            migrationBuilder.AddForeignKey(
                name: "fk_zhr_employees_zhr_employment_types_employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "employment_type_id",
                principalSchema: "zeloshr",
                principalTable: "zhr_employment_types",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_zhr_employees_zhr_employment_types_employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "employment_type_id",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropTable(
                name: "zhr_employment_types",
                schema: "zeloshr");
        }
    }
}
