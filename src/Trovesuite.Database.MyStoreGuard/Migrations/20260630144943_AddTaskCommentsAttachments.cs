using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class AddTaskCommentsAttachments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The naming convention now derives the msg_tasks primary-key constraint name as
            // ak_tasks_... (because it is referenced as a composite principal key by the new
            // comment/mention/attachment FKs). EF scaffolds this as DropPrimaryKey + AddPrimaryKey,
            // which Postgres rejects on a live table whose PK is referenced by existing FKs
            // (msg_task_steps, msg_task_notifications, ...). A constraint RENAME reaches the exact
            // end state the model snapshot expects without disturbing the dependent FKs.
            migrationBuilder.Sql(
                "ALTER TABLE mystoreguard.msg_tasks " +
                "RENAME CONSTRAINT pk_msg_tasks TO ak_tasks_tenant_id_org_id_bus_id_id;");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_task_notifications_kind",
                schema: "mystoreguard",
                table: "msg_task_notifications");

            migrationBuilder.CreateTable(
                name: "msg_task_comments",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    task_id = table.Column<string>(type: "text", nullable: false),
                    body = table.Column<string>(type: "text", nullable: false),
                    edited_at = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ak_task_comments_tenant_id_org_id_bus_id_id", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_task_comments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_comments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comments_tasks_tenant_id_org_id_bus_id_task_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.task_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tasks",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_attachments",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    task_id = table.Column<string>(type: "text", nullable: false),
                    comment_id = table.Column<string>(type: "text", nullable: true),
                    document_id = table.Column<string>(type: "text", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    delete_status = table.Column<string>(type: "text", nullable: false, defaultValue: "NOT_DELETED"),
                    cdate = table.Column<string>(type: "text", nullable: true),
                    ctime = table.Column<string>(type: "text", nullable: true),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true),
                    updated_by = table.Column<string>(type: "text", nullable: true),
                    deleted_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_attachments", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.CheckConstraint("ck_msg_task_attachments_delete_status", "delete_status IN ('PENDING','DELETED','NOT_DELETED')");
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_users_deleted_by_tenant_id",
                        columns: x => new { x.deleted_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_cp_users_updated_by_tenant_id",
                        columns: x => new { x.updated_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_msg_document_paths_tenant_id_org_id_bu",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.document_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_document_paths",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_task_comments_tenant_id_org_id_bus_id_",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.comment_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_comments",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_attachments_tasks_tenant_id_org_id_bus_id_task_id",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.task_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tasks",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "msg_task_comment_mentions",
                schema: "mystoreguard",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false, defaultValueSql: "gen_random_uuid()::text"),
                    tenant_id = table.Column<string>(type: "text", nullable: false),
                    org_id = table.Column<string>(type: "text", nullable: false),
                    bus_id = table.Column<string>(type: "text", nullable: false),
                    comment_id = table.Column<string>(type: "text", nullable: false),
                    task_id = table.Column<string>(type: "text", nullable: false),
                    mentioned_user_id = table.Column<string>(type: "text", nullable: false),
                    cdatetime = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true, defaultValueSql: "NOW()"),
                    created_by = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_msg_task_comment_mentions", x => new { x.tenant_id, x.org_id, x.bus_id, x.id });
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_cp_businesses_bus_id_tenant_id",
                        columns: x => new { x.bus_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_businesses",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_cp_organizations_org_id_tenant_id",
                        columns: x => new { x.org_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_organizations",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_cp_tenants_tenant_id",
                        column: x => x.tenant_id,
                        principalSchema: "core_platform",
                        principalTable: "cp_tenants",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_cp_users_created_by_tenant_id",
                        columns: x => new { x.created_by, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_cp_users_mentioned_user_id_tenant",
                        columns: x => new { x.mentioned_user_id, x.tenant_id },
                        principalSchema: "core_platform",
                        principalTable: "cp_users",
                        principalColumns: new[] { "id", "tenant_id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_msg_task_comments_tenant_id_org_i",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.comment_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_task_comments",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_msg_task_comment_mentions_tasks_tenant_id_org_id_bus_id_tas",
                        columns: x => new { x.tenant_id, x.org_id, x.bus_id, x.task_id },
                        principalSchema: "mystoreguard",
                        principalTable: "msg_tasks",
                        principalColumns: new[] { "tenant_id", "org_id", "bus_id", "id" },
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_task_notifications_kind",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                sql: "kind IN ('ASSIGNED','READY','DONE_NEEDS_APPROVAL','REMINDER','MENTIONED')");

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_deleted_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "deleted_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_tenant_id_org_id_bus_id_comment_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "comment_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_tenant_id_org_id_bus_id_document_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "document_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_tenant_id_org_id_bus_id_task_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "task_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_attachments_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_attachments",
                columns: new[] { "updated_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_mentioned_user_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "mentioned_user_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_tenant_id_org_id_bus_id_comment_i",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "comment_id", "mentioned_user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comment_mentions_tenant_id_org_id_bus_id_task_id",
                schema: "mystoreguard",
                table: "msg_task_comment_mentions",
                columns: new[] { "tenant_id", "org_id", "bus_id", "task_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_bus_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "bus_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_created_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "created_by", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_org_id_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "org_id", "tenant_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_tenant_id_org_id_bus_id_task_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "tenant_id", "org_id", "bus_id", "task_id" });

            migrationBuilder.CreateIndex(
                name: "ix_msg_task_comments_updated_by_tenant_id",
                schema: "mystoreguard",
                table: "msg_task_comments",
                columns: new[] { "updated_by", "tenant_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "msg_task_attachments",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_comment_mentions",
                schema: "mystoreguard");

            migrationBuilder.DropTable(
                name: "msg_task_comments",
                schema: "mystoreguard");

            migrationBuilder.Sql(
                "ALTER TABLE mystoreguard.msg_tasks " +
                "RENAME CONSTRAINT ak_tasks_tenant_id_org_id_bus_id_id TO pk_msg_tasks;");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_task_notifications_kind",
                schema: "mystoreguard",
                table: "msg_task_notifications");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_task_notifications_kind",
                schema: "mystoreguard",
                table: "msg_task_notifications",
                sql: "kind IN ('ASSIGNED','READY','DONE_NEEDS_APPROVAL','REMINDER')");
        }
    }
}
