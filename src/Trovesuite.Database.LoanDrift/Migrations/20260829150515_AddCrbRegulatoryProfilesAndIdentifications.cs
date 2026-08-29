using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.LoanDrift.Migrations
{
    /// <inheritdoc />
    public partial class AddCrbRegulatoryProfilesAndIdentifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_repayments_payment_method",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_guarantors_id_type",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_clients_id_type",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.AddColumn<string>(
                name: "first_name",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "middle_names",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "nationality",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "surname",
                schema: "loandrift",
                table: "ld_guarantors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "first_name",
                schema: "loandrift",
                table: "ld_clients",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "middle_names",
                schema: "loandrift",
                table: "ld_clients",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "nationality",
                schema: "loandrift",
                table: "ld_clients",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "surname",
                schema: "loandrift",
                table: "ld_clients",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "title",
                schema: "loandrift",
                table: "ld_clients",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ld_branch_profile",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    branch_code = table.Column<string>(type: "text", nullable: false),
                    bog_branch_code = table.Column<string>(type: "text", nullable: true),
                    branch_name = table.Column<string>(type: "text", nullable: true),
                    is_head_office = table.Column<bool>(type: "boolean", nullable: false),
                    address_line1 = table.Column<string>(type: "text", nullable: true),
                    address_line2 = table.Column<string>(type: "text", nullable: true),
                    address_line3 = table.Column<string>(type: "text", nullable: true),
                    address_line4 = table.Column<string>(type: "text", nullable: true),
                    postal_code = table.Column<string>(type: "text", nullable: true),
                    digital_address = table.Column<string>(type: "text", nullable: true),
                    phone = table.Column<string>(type: "text", nullable: true),
                    email = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_branch_profile", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_branch_profile_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_branch_profile_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_client_identifications",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    client_id = table.Column<string>(type: "text", nullable: false),
                    id_type = table.Column<string>(type: "text", nullable: false),
                    id_number = table.Column<string>(type: "text", nullable: false),
                    other_id_label = table.Column<string>(type: "text", nullable: true),
                    issue_date = table.Column<string>(type: "text", nullable: true),
                    expiry_date = table.Column<string>(type: "text", nullable: true),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_client_identifications", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_client_identifications_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_client_identifications_id_type", "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT','SSNIT','EZWICH','TIN','NHIS','OTHER')");
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_client_identifications_ld_clients_tenant_id_org_id_bus_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.client_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_clients",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ld_company_profile",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    legal_name = table.Column<string>(type: "text", nullable: false),
                    trading_name = table.Column<string>(type: "text", nullable: true),
                    institution_type = table.Column<string>(type: "text", nullable: true),
                    bog_institution_code = table.Column<string>(type: "text", nullable: true),
                    bog_licence_number = table.Column<string>(type: "text", nullable: true),
                    registration_number = table.Column<string>(type: "text", nullable: true),
                    tin = table.Column<string>(type: "text", nullable: true),
                    incorporation_date = table.Column<string>(type: "text", nullable: true),
                    address_line1 = table.Column<string>(type: "text", nullable: true),
                    address_line2 = table.Column<string>(type: "text", nullable: true),
                    address_line3 = table.Column<string>(type: "text", nullable: true),
                    address_line4 = table.Column<string>(type: "text", nullable: true),
                    postal_code = table.Column<string>(type: "text", nullable: true),
                    digital_address = table.Column<string>(type: "text", nullable: true),
                    city = table.Column<string>(type: "text", nullable: true),
                    region = table.Column<string>(type: "text", nullable: true),
                    country = table.Column<string>(type: "text", nullable: false, defaultValue: "GH"),
                    phone = table.Column<string>(type: "text", nullable: true),
                    email = table.Column<string>(type: "text", nullable: true),
                    website = table.Column<string>(type: "text", nullable: true),
                    reporting_currency = table.Column<string>(type: "text", nullable: false, defaultValue: "GHS"),
                    contact_person_name = table.Column<string>(type: "text", nullable: true),
                    contact_person_phone = table.Column<string>(type: "text", nullable: true),
                    contact_person_email = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_company_profile", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_ld_company_profile_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_company_profile_institution_type", "institution_type IN ('MICROFINANCE','SAVINGS_AND_LOANS','RURAL_BANK','FINANCE_HOUSE','CREDIT_UNION','LEASING','MONEY_LENDER','OTHER',NULL)");
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_company_profile_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ld_guarantor_identifications",
                schema: "loandrift",
                columns: table => new
                {
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    guarantor_id = table.Column<string>(type: "text", nullable: false),
                    id_type = table.Column<string>(type: "text", nullable: false),
                    id_number = table.Column<string>(type: "text", nullable: false),
                    other_id_label = table.Column<string>(type: "text", nullable: true),
                    issue_date = table.Column<string>(type: "text", nullable: true),
                    expiry_date = table.Column<string>(type: "text", nullable: true),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ld_guarantor_identifications", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_ld_guarantor_identifications_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.CheckConstraint("ck_ld_guarantor_identifications_id_type", "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT','SSNIT','EZWICH','TIN','NHIS','OTHER')");
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_organizations_org_id_tenant",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ld_guarantor_identifications_ld_guarantors_tenant_id_org_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.guarantor_id },
                        principalSchema: "loandrift",
                        principalTable: "ld_guarantors",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_repayments_payment_method",
                schema: "loandrift",
                table: "ld_repayments",
                sql: "payment_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','CARD','OTHERS',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_guarantors_id_type",
                schema: "loandrift",
                table: "ld_guarantors",
                sql: "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT','SSNIT','EZWICH','TIN','NHIS','OTHER',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_clients_id_type",
                schema: "loandrift",
                table: "ld_clients",
                sql: "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT','SSNIT','EZWICH','TIN','NHIS','OTHER',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_clients_title",
                schema: "loandrift",
                table: "ld_clients",
                sql: "title IN ('MR','MRS','MISS','MS','DR','MADAM',NULL)");

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_tenant_id_org_id_bus_id_branch_code",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "tenant_id", "org_id", "bus_id", "branch_code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_branch_profile_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_branch_profile",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_tenant_id_org_id_bus_id_loc_id_cl",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id", "id_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_client_identifications_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ux_ld_client_identifications_primary",
                schema: "loandrift",
                table: "ld_client_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "client_id" },
                unique: true,
                filter: "is_primary");

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_tenant_id_org_id_bus_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "tenant_id", "org_id", "bus_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_company_profile_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_company_profile",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_bus_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_created_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_deleted_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_loc_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_org_id_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_tenant_id_org_id_bus_id_loc_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "guarantor_id", "id_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_ld_guarantor_identifications_updated_by_tenant_id",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ux_ld_guarantor_identifications_primary",
                schema: "loandrift",
                table: "ld_guarantor_identifications",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "guarantor_id" },
                unique: true,
                filter: "is_primary");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ld_branch_profile",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_client_identifications",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_company_profile",
                schema: "loandrift");

            migrationBuilder.DropTable(
                name: "ld_guarantor_identifications",
                schema: "loandrift");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_repayments_payment_method",
                schema: "loandrift",
                table: "ld_repayments");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_guarantors_id_type",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_clients_id_type",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropCheckConstraint(
                name: "ck_ld_clients_title",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropColumn(
                name: "first_name",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropColumn(
                name: "middle_names",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropColumn(
                name: "nationality",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropColumn(
                name: "surname",
                schema: "loandrift",
                table: "ld_guarantors");

            migrationBuilder.DropColumn(
                name: "first_name",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropColumn(
                name: "middle_names",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropColumn(
                name: "nationality",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropColumn(
                name: "surname",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.DropColumn(
                name: "title",
                schema: "loandrift",
                table: "ld_clients");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_repayments_payment_method",
                schema: "loandrift",
                table: "ld_repayments",
                sql: "payment_method IN ('CASH','CHEQUE','MOMO','BANK_TRANSFER','OTHERS',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_guarantors_id_type",
                schema: "loandrift",
                table: "ld_guarantors",
                sql: "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT',NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_ld_clients_id_type",
                schema: "loandrift",
                table: "ld_clients",
                sql: "id_type IN ('GHANA_CARD','VOTER_ID','DRIVERS_LICENSE','PASSPORT',NULL)");
        }
    }
}
