using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations;

/// <inheritdoc />
public partial class AddZhrEmployeeFullProfileSections : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "marital_status",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(50)",
            maxLength: 50,
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "net_salary",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "numeric(18,4)",
            precision: 18,
            scale: 4,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "next_of_kin_name",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "next_of_kin_phone",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(50)",
            maxLength: 50,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "relationship_to_next_of_kin",
            schema: "zeloshr",
            table: "zhr_employees",
            type: "character varying(100)",
            maxLength: 100,
            nullable: true);

        migrationBuilder.CreateTable(
            name: "zhr_employee_emergency_contacts",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                emergency_contact_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                emergency_contact_phone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                relationship = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_emergency_contacts", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_emergency_contacts_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_payment_methods",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                payment_mode = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                bank_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                account_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                account_number = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                branch_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_payment_methods", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_payment_methods_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_medical_profiles",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                blood_group = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                has_medical_condition = table.Column<bool>(type: "boolean", nullable: false),
                takes_regular_medication = table.Column<bool>(type: "boolean", nullable: false),
                disability_status = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                requires_accommodation = table.Column<bool>(type: "boolean", nullable: false),
                accommodation_details = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                emergency_medical_notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_medical_profiles", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_medical_profiles_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_medical_conditions",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                condition = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                severity = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                diagnosed_date = table.Column<DateOnly>(type: "date", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_medical_conditions", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_medical_conditions_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_allergies",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                allergen = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                reaction = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                severity = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_allergies", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_allergies_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_medications",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                dosage = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                frequency = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_medications", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_medications_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_skills",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                proficiency = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                years_of_experience = table.Column<int>(type: "integer", nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_skills", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_skills_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_experiences",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                company = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                job_title = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                employment_type = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                location = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                start_date = table.Column<DateOnly>(type: "date", nullable: true),
                end_date = table.Column<DateOnly>(type: "date", nullable: true),
                is_current = table.Column<bool>(type: "boolean", nullable: false),
                description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_experiences", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_experiences_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "zhr_employee_referrals",
            schema: "zeloshr",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                job_title = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                company = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                relationship = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                email = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                phone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "NOW()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_zhr_employee_referrals", x => x.id);
                table.ForeignKey(
                    name: "fk_zhr_employee_referrals_zhr_employees_employee_id",
                    column: x => x.employee_id,
                    principalSchema: "zeloshr",
                    principalTable: "zhr_employees",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_emergency_contacts_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_emergency_contacts",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_payment_methods_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_payment_methods",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_medical_profiles_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_medical_profiles",
            column: "employee_id",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_medical_conditions_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_medical_conditions",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_allergies_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_allergies",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_medications_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_medications",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_skills_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_skills",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_experiences_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_experiences",
            column: "employee_id");

        migrationBuilder.CreateIndex(
            name: "ix_zhr_employee_referrals_employee_id",
            schema: "zeloshr",
            table: "zhr_employee_referrals",
            column: "employee_id");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "zhr_employee_emergency_contacts", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_payment_methods", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_medical_profiles", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_medical_conditions", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_allergies", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_medications", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_skills", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_experiences", schema: "zeloshr");
        migrationBuilder.DropTable(name: "zhr_employee_referrals", schema: "zeloshr");

        migrationBuilder.DropColumn(name: "marital_status", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "net_salary", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "next_of_kin_name", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "next_of_kin_phone", schema: "zeloshr", table: "zhr_employees");
        migrationBuilder.DropColumn(name: "relationship_to_next_of_kin", schema: "zeloshr", table: "zhr_employees");
    }
}
