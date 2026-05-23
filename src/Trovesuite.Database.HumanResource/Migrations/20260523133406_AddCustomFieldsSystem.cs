using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomFieldsSystem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employees",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_departments",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.AddColumn<string>(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_branches",
                type: "jsonb",
                nullable: false,
                defaultValue: "{}");

            migrationBuilder.CreateTable(
                name: "zhr_custom_field_audit_log",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    entity_id = table.Column<Guid>(type: "uuid", nullable: false),
                    field_key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    old_value = table.Column<string>(type: "text", nullable: true),
                    new_value = table.Column<string>(type: "text", nullable: true),
                    changed_by = table.Column<string>(type: "text", nullable: false),
                    changed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    change_type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_custom_field_audit_log", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_custom_field_definitions",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    field_key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    label = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    field_type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    is_required = table.Column<bool>(type: "boolean", nullable: false),
                    is_sensitive = table.Column<bool>(type: "boolean", nullable: false),
                    is_filterable = table.Column<bool>(type: "boolean", nullable: false),
                    is_searchable = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    section_name = table.Column<string>(type: "text", nullable: true),
                    section_order = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    options = table.Column<string>(type: "jsonb", nullable: true),
                    validation_rules = table.Column<string>(type: "jsonb", nullable: true),
                    default_value = table.Column<string>(type: "text", nullable: true),
                    placeholder = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_custom_field_definitions", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_lifecycle_events_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_lifecycle_events",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employees_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employees",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_employee_documents_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_departments_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_departments",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_branches_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_branches",
                column: "custom_fields_data")
                .Annotation("Npgsql:IndexMethod", "gin");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_audit_log_tenant_id_org_id_entity_type_ent",
                schema: "zeloshr",
                table: "zhr_custom_field_audit_log",
                columns: new[] { "tenant_id", "org_id", "entity_type", "entity_id", "changed_at" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_definitions_tenant_id_org_id_entity_type_f",
                schema: "zeloshr",
                table: "zhr_custom_field_definitions",
                columns: new[] { "tenant_id", "org_id", "entity_type", "field_key" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ix_zhr_custom_field_definitions_tenant_id_org_id_entity_type_s",
                schema: "zeloshr",
                table: "zhr_custom_field_definitions",
                columns: new[] { "tenant_id", "org_id", "entity_type", "section_order", "display_order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_custom_field_audit_log",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_custom_field_definitions",
                schema: "zeloshr");

            migrationBuilder.DropIndex(
                name: "ix_zhr_lifecycle_events_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropIndex(
                name: "ix_zhr_employees_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropIndex(
                name: "ix_zhr_employee_documents_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employee_documents");

            migrationBuilder.DropIndex(
                name: "ix_zhr_departments_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_departments");

            migrationBuilder.DropIndex(
                name: "ix_zhr_branches_custom_fields_data",
                schema: "zeloshr",
                table: "zhr_branches");

            migrationBuilder.DropColumn(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_lifecycle_events");

            migrationBuilder.DropColumn(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employees");

            migrationBuilder.DropColumn(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_employee_documents");

            migrationBuilder.DropColumn(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_departments");

            migrationBuilder.DropColumn(
                name: "custom_fields_data",
                schema: "zeloshr",
                table: "zhr_branches");
        }
    }
}
