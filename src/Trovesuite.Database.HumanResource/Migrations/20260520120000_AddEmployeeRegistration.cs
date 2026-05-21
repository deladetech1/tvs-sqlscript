using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddEmployeeRegistration : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "ix_zhr_employees_tenant_id_ghana_card_number",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.AlterColumn<string>(
            name: "first_name",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "last_name",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<DateOnly>(
            name: "date_of_birth",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "date",
            nullable: true,
            oldClrType: typeof(DateOnly),
            oldType: "date");

        migrationBuilder.AlterColumn<string>(
            name: "gender",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "nationality",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "ghana_card_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "personal_email",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "personal_phone",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "residential_address",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "ghana_post_gps",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AddColumn<string>(
            name: "user_id",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(128)",
            maxLength: 128,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "full_name",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(500)",
            maxLength: 500,
            nullable: false,
            defaultValue: "");

        migrationBuilder.AddColumn<string>(
            name: "nationality_id_type",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "id_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "work_email",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "phone",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "linkedin_url",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "state",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "profile_photo_url",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "lifecycle_status",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: false,
            defaultValue: "draft");

        migrationBuilder.AddColumn<bool>(
            name: "is_draft",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "boolean",
            nullable: false,
            defaultValue: true);

        migrationBuilder.AddColumn<string>(
            name: "work_arrangement",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "work_location",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "pay_grade",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "reports_to_id",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "dotted_line_manager_id",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "uuid",
            nullable: true);

        migrationBuilder.AddColumn<DateOnly>(
            name: "start_date",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "date",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "working_hours",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "notice_period",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "gross_salary",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "numeric(18,4)",
            precision: 18,
            scale: 4,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "pay_frequency",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "annualized_cost",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "numeric(18,4)",
            precision: 18,
            scale: 4,
            nullable: true);

        migrationBuilder.AddColumn<DateOnly>(
            name: "salary_effective_from",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "date",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "currency",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(8)",
            maxLength: 8,
            nullable: false,
            defaultValue: "GHS");

        migrationBuilder.AddColumn<string>(
            name: "ssnit_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "tin_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "tier2_pension_provider",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "tier3_pension_provider",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "payment_method",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "bank_account_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "mobile_money_number",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "created_by",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "updated_by",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "text",
            nullable: true);

        migrationBuilder.Sql("""
            UPDATE zeloshr.zhr_employees
            SET full_name = TRIM(CONCAT_WS(' ', first_name, NULLIF(middle_name, ''), last_name))
            WHERE full_name = '' OR full_name IS NULL;

            UPDATE zeloshr.zhr_employees
            SET reports_to_id = manager_id
            WHERE reports_to_id IS NULL AND manager_id IS NOT NULL;

            UPDATE zeloshr.zhr_employees
            SET start_date = employment_start_date
            WHERE start_date IS NULL AND employment_start_date IS NOT NULL;

            UPDATE zeloshr.zhr_employees
            SET lifecycle_status = CASE
                WHEN LOWER(lifecycle_state) IN ('active') THEN 'active'
                WHEN LOWER(lifecycle_state) IN ('terminated') THEN 'terminated'
                WHEN LOWER(lifecycle_state) IN ('pre-hire', 'pre hire') THEN 'pre_hire'
                ELSE LOWER(REPLACE(lifecycle_state, ' ', '_'))
            END,
            is_draft = false
            WHERE employee_code IS NOT NULL;
            """);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_ghana_card_number",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "ghana_card_number" },
            unique: true,
            filter: "ghana_card_number IS NOT NULL AND ghana_card_number <> ''");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_user_id",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "user_id" },
            unique: true,
            filter: "user_id IS NOT NULL");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_dotted_line_manager_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "dotted_line_manager_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_manager_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "manager_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_reports_to_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "reports_to_id");

        migrationBuilder.AddForeignKey(
            name: "fk_zhr_employees_zhr_employees_dotted_line_manager_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "dotted_line_manager_id",
            principalSchema: "zeloshr",
            principalTable: "zhr_employees",
            principalColumn: "id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "fk_zhr_employees_zhr_employees_manager_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "manager_id",
            principalSchema: "zeloshr",
            principalTable: "zhr_employees",
            principalColumn: "id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.AddForeignKey(
            name: "fk_zhr_employees_zhr_employees_reports_to_id",
            schema: "zeloshr",
            table: "zhr_employees",
            column: "reports_to_id",
            principalSchema: "zeloshr",
            principalTable: "zhr_employees",
            principalColumn: "id",
            onDelete: ReferentialAction.Restrict);

        migrationBuilder.CreateTable(
            name: "zhr_employee_education",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                institution = table.Column<string>(type: "text", nullable: false),
                degree = table.Column<string>(type: "text", nullable: true),
                field_of_study = table.Column<string>(type: "text", nullable: true),
                start_year = table.Column<int>(type: "integer", nullable: true),
                end_year = table.Column<int>(type: "integer", nullable: true),
                is_current = table.Column<bool>(type: "boolean", nullable: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_education", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_education_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_certifications",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                name = table.Column<string>(type: "text", nullable: false),
                issuing_body = table.Column<string>(type: "text", nullable: true),
                issue_date = table.Column<DateOnly>(type: "date", nullable: true),
                expiry_date = table.Column<DateOnly>(type: "date", nullable: true),
                credential_id = table.Column<string>(type: "text", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_certifications", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_certifications_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_education_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_education",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_certifications_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_certifications",
            column: "employee_id");

        migrationBuilder.AlterColumn<string>(
            name: "employee_full_name",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AlterColumn<string>(
            name: "uploaded_by",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "text",
            nullable: true,
            oldClrType: typeof(string),
            oldType: "text");

        migrationBuilder.AddColumn<string>(
            name: "file_name",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "character varying(512)",
            maxLength: 512,
            nullable: false,
            defaultValue: "");

        migrationBuilder.AddColumn<long>(
            name: "file_size_bytes",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "bigint",
            nullable: false,
            defaultValue: 0L);

        migrationBuilder.AddColumn<string>(
            name: "blob_url",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "character varying(2048)",
            maxLength: 2048,
            nullable: false,
            defaultValue: "");

        migrationBuilder.AddColumn<string>(
            name: "content_type",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "character varying(128)",
            maxLength: 128,
            nullable: false,
            defaultValue: "application/octet-stream");

        migrationBuilder.AddColumn<bool>(
            name: "is_deleted",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.Sql("""
            UPDATE zeloshr.zhr_employee_documents
            SET file_name = COALESCE(NULLIF(document_name, ''), 'legacy-document'),
                file_size_bytes = GREATEST(file_size_kb, 0) * 1024
            WHERE file_name = '';
            """);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_documents_tenant_id_org_id_employee_id_category",
            schema: "zeloshr",
            table: "zhr_employee_documents",
            columns: new[] { "tenant_id", "org_id", "employee_id", "category" });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "zhr_employee_certifications", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_education", schema: "zeloshr");

        migrationBuilder.DropIndex(
            name: "ix_zhr_employee_documents_tenant_id_org_id_employee_id_category",
            schema: "zeloshr",
            table: "zhr_employee_documents");

        migrationBuilder.DropColumn(name: "is_deleted", schema: "zeloshr", table: "zhr_employee_documents");
        migrationBuilder.DropColumn(name: "content_type", schema: "zeloshr", table: "zhr_employee_documents");
        migrationBuilder.DropColumn(name: "blob_url", schema: "zeloshr", table: "zhr_employee_documents");
        migrationBuilder.DropColumn(name: "file_size_bytes", schema: "zeloshr", table: "zhr_employee_documents");
        migrationBuilder.DropColumn(name: "file_name", schema: "zeloshr", table: "zhr_employee_documents");

        migrationBuilder.DropForeignKey(
            name: "fk_zhr_employees_zhr_employees_dotted_line_manager_id",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropForeignKey(
            name: "fk_zhr_employees_zhr_employees_manager_id",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropForeignKey(
            name: "fk_zhr_employees_zhr_employees_reports_to_id",
            schema: "zeloshr",
            table: "zhr_employees");

        migrationBuilder.DropIndex(name: "ix_zhr_employees_tenant_id_user_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropIndex(name: "ix_zhr_employees_reports_to_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropIndex(name: "ix_zhr_employees_manager_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropIndex(name: "ix_zhr_employees_dotted_line_manager_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropIndex(name: "ix_zhr_employees_tenant_id_ghana_card_number", schema: "zeloshr", table: "zhr_employees");

        migrationBuilder.DropColumn(name: "updated_by", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "created_by", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "mobile_money_number", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "bank_account_number", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "payment_method", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "tier3_pension_provider", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "tier2_pension_provider", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "tin_number", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "ssnit_number", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "currency", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "salary_effective_from", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "annualized_cost", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "pay_frequency", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "gross_salary", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "notice_period", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "working_hours", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "start_date", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "dotted_line_manager_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "reports_to_id", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "pay_grade", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "work_location", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "work_arrangement", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "is_draft", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "lifecycle_status", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "profile_photo_url", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "state", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "linkedin_url", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "phone", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "work_email", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "id_number", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "nationality_id_type", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "full_name", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "user_id", schema: "zeloshr", table: "zhr_employees");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employees_tenant_id_ghana_card_number",
            schema: "zeloshr",
            table: "zhr_employees",
            columns: new[] { "tenant_id", "ghana_card_number" },
            unique: true);
    }
}
