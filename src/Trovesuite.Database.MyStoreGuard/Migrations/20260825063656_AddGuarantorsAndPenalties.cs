using System;
using System.Text.Json;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddGuarantorsAndPenalties : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "msg_guarantors",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    customer_id = table.Column<string>(type: "text", nullable: false),
                    fullname = table.Column<string>(type: "varchar(255)", nullable: false),
                    occupation = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    digital_address = table.Column<string>(type: "text", nullable: true),
                    relationship = table.Column<string>(type: "text", nullable: true),
                    id_type = table.Column<string>(type: "text", nullable: true),
                    id_number = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_guarantors", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantors_msg_customers_tenant_id_org_id_bus_id_custom",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.customer_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_customers",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_installment_penalties",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    plan_id = table.Column<string>(type: "text", nullable: false),
                    schedule_id = table.Column<string>(type: "text", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false),
                    paid_amount = table.Column<decimal>(type: "numeric(18,2)", nullable: false, defaultValue: 0m),
                    status = table.Column<string>(type: "text", nullable: false, defaultValue: "OUTSTANDING"),
                    days_late = table.Column<int>(type: "integer", nullable: false),
                    snapshot = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    reason = table.Column<string>(type: "text", nullable: true),
                    waived_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    waived_by = table.Column<string>(type: "text", nullable: true),
                    waiver_reason = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_installment_penalties", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.CheckConstraint("ck_msg_installment_penalties_amount", "amount > 0");
                    table.CheckConstraint("ck_msg_installment_penalties_paid", "paid_amount >= 0 AND paid_amount <= amount");
                    table.CheckConstraint("ck_msg_installment_penalties_status", "status IN ('OUTSTANDING','PARTIALLY_PAID','CLEARED','WAIVED')");
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_cp_users_waived_by_tenant_id",
                        columns: x => new { x.waived_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_installment_plans_tenant_id_org_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.plan_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_plans",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_installment_penalties_installment_schedule_rows_tenant_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.schedule_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_installment_schedule",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_guarantor_contacts",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    guarantor_id = table.Column<string>(type: "text", nullable: false),
                    kind = table.Column<string>(type: "text", nullable: false),
                    value = table.Column<string>(type: "text", nullable: false),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_guarantor_contacts", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_guarantor_contacts_kind", "kind IN ('email','phone')");
                    table.ForeignKey(
                        name: "fk_msg_guarantor_contacts_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_contacts_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_contacts_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_contacts_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_contacts_msg_guarantors_tenant_id_org_id_bus_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.guarantor_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_guarantors",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_guarantor_documents",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    guarantor_id = table.Column<string>(type: "text", nullable: false),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    doc_type = table.Column<string>(type: "text", nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_guarantor_documents", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_guarantor_documents_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_documents_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_documents_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_documents_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_guarantor_documents_msg_guarantors_tenant_id_org_id_bus",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.guarantor_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_guarantors",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_sale_guarantors",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    loc_id = table.Column<string>(type: "text", nullable: false),
                    sale_id = table.Column<string>(type: "text", nullable: false),
                    guarantor_id = table.Column<string>(type: "text", nullable: false),
                    snapshot = table.Column<JsonDocument>(type: "jsonb", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_sale_guarantors", x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_cp_locations_loc_id_tenant_id",
                        columns: x => new { x.loc_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_locations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_msg_guarantors_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.guarantor_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_guarantors",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_sale_guarantors_msg_sales_tenant_id_org_id_bus_id_loc_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.loc_id, x.sale_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_sales",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_contacts_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_contacts",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_contacts_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_contacts",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_contacts_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_contacts",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_contacts_tenant_id_org_id_bus_id_guarantor_id",
                schema: "mystoreguard",
                table: "msg_guarantor_contacts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "guarantor_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_contacts_tenant_id_org_id_bus_id_guarantor_id1",
                schema: "mystoreguard",
                table: "msg_guarantor_contacts",
                columns: new[] { "tenant_id", "org_id", "bus_id", "guarantor_id", "kind" },
                unique: true,
                filter: "is_primary");

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_documents_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_documents",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_documents_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_documents",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_documents_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantor_documents",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantor_documents_tenant_id_org_id_bus_id_guarantor_id",
                schema: "mystoreguard",
                table: "msg_guarantor_documents",
                columns: new[] { "tenant_id", "org_id", "bus_id", "guarantor_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_tenant_id_org_id_bus_id_customer_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "customer_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_guarantors_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_guarantors",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_tenant_id_org_id_bus_id_loc_id_pl",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "plan_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_tenant_id_org_id_bus_id_loc_id_sc",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "schedule_id", "days_late" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_tenant_id_org_id_bus_id_plan_id_s",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "tenant_id", "org_id", "bus_id", "plan_id", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_installment_penalties_waived_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_installment_penalties",
                columns: new[] { "waived_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_loc_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "loc_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_tenant_id_org_id_bus_id_guarantor_id",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "guarantor_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_sale_guarantors_tenant_id_org_id_bus_id_loc_id_sale_id_",
                schema: "mystoreguard",
                table: "msg_sale_guarantors",
                columns: new[] { "tenant_id", "org_id", "bus_id", "loc_id", "sale_id", "guarantor_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_guarantor_contacts",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_guarantor_documents",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_installment_penalties",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_sale_guarantors",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_guarantors",
                schema: "mystoreguard");
        }
    }
}
