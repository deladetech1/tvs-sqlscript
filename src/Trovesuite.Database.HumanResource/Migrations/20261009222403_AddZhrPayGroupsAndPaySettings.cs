using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrPayGroupsAndPaySettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "approval_delegate_id",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "approval_delegate_until",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "compensation_approver_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'[]'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "disbursement_account_name",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "disbursement_account_number",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(60)",
                maxLength: 60,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "disbursement_bank",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "disbursement_branch",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "enabled_payment_methods_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'[]'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "non_working_day_rule",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(10)",
                maxLength: 10,
                nullable: false,
                defaultValue: "before");

            migrationBuilder.AddColumn<string>(
                name: "pay_day_rule",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "day");

            migrationBuilder.AddColumn<string>(
                name: "payroll_approver_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'[]'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "payroll_preparer_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'[]'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "payslip_options_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "jsonb",
                nullable: false,
                defaultValueSql: "'{}'::jsonb");

            migrationBuilder.AddColumn<string>(
                name: "payslip_release",
                schema: "zeloshr",
                table: "zhr_payroll_settings",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "approved");

            migrationBuilder.AddColumn<Guid>(
                name: "pay_group_id",
                schema: "zeloshr",
                table: "zhr_payroll_runs",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "zhr_pay_group_members",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    pay_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    employee_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pay_group_members", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "zhr_pay_groups",
                schema: "zeloshr",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    tenant_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    org_id = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    entity_name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    frequency = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    variance_threshold_percent = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false),
                    payment_channels_json = table.Column<string>(type: "jsonb", nullable: false),
                    is_default = table.Column<bool>(type: "boolean", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_zhr_pay_groups", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_group_members_tenant_id_org_id_employee_id",
                schema: "zeloshr",
                table: "zhr_pay_group_members",
                columns: new[] { "tenant_id", "org_id", "employee_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_group_members_tenant_id_org_id_pay_group_id",
                schema: "zeloshr",
                table: "zhr_pay_group_members",
                columns: new[] { "tenant_id", "org_id", "pay_group_id" });

            migrationBuilder.CreateIndex(
                name: "ix_zhr_pay_groups_tenant_id_org_id",
                schema: "zeloshr",
                table: "zhr_pay_groups",
                columns: new[] { "tenant_id", "org_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "zhr_pay_group_members",
                schema: "zeloshr");

            migrationBuilder.DropTable(
                name: "zhr_pay_groups",
                schema: "zeloshr");

            migrationBuilder.DropColumn(
                name: "approval_delegate_id",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "approval_delegate_until",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "compensation_approver_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "disbursement_account_name",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "disbursement_account_number",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "disbursement_bank",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "disbursement_branch",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "enabled_payment_methods_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "non_working_day_rule",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "pay_day_rule",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "payroll_approver_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "payroll_preparer_ids_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "payslip_options_json",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "payslip_release",
                schema: "zeloshr",
                table: "zhr_payroll_settings");

            migrationBuilder.DropColumn(
                name: "pay_group_id",
                schema: "zeloshr",
                table: "zhr_payroll_runs");
        }
    }
}
