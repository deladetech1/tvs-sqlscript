using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <summary>
    /// Give a tenant a name.
    ///
    /// A tenant has never had one — only an id, and a Description that signup
    /// never set. That was survivable while one person belonged to exactly one
    /// tenant, because nothing had to name one: you were simply in it. Once the
    /// same email can exist in two, sign-in has to ask which, and a question
    /// offering two rows of uuids is not a question anybody can answer.
    ///
    /// Hand-written rather than left as EF scaffolded it. EF produced
    /// AddColumn(nullable: false, defaultValue: "") followed by the check
    /// constraint btrim(tenant_name) &lt;&gt; '', which contradict each other: the
    /// column write fills every existing row with the empty string and the
    /// constraint then refuses every one of those rows. On any database with a
    /// tenant in it — which is all of them — that migration cannot apply.
    ///
    /// So: add it nullable, put a real name in every row, and only then make it
    /// NOT NULL and add the constraint.
    /// </summary>
    public partial class AddTenantName : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "tenant_name",
                schema: "core_platform",
                table: "cp_tenants",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            // Best available name, in order of how much the owner would
            // recognise it. Every branch is COALESCEd rather than run as
            // separate UPDATEs so a tenant is visited once and cannot be left
            // null by a gap between them.
            migrationBuilder.Sql(@"
                UPDATE core_platform.cp_tenants t
                   SET tenant_name = LEFT(BTRIM(COALESCE(

                       -- 1. Its organisation, when it has exactly one. True for
                       --    every Basic and Advance tenant by tier limit
                       --    (max_organizations = 1), so this is the usual answer
                       --    and it is the name the owner actually typed.
                       --    Restricted to exactly one: picking arbitrarily from
                       --    several would name a group after one of its parts.
                       --
                       --    MIN() rather than the bare column because HAVING with
                       --    no GROUP BY aggregates the whole set, and a plain
                       --    o.org_name there is not grouped or aggregated. With
                       --    COUNT(*) = 1 the minimum IS that single row's name.
                       (SELECT MIN(o.org_name)
                          FROM core_platform.cp_organizations o
                         WHERE o.tenant_id = t.id
                           AND o.delete_status = 'NOT_DELETED'
                           AND BTRIM(COALESCE(o.org_name, '')) <> ''
                        HAVING COUNT(*) = 1),

                       -- 2. The owner's own name. A tenant with no organisation
                       --    yet is one that got as far as signing up, and the
                       --    owner is the only human attached to it.
                       (SELECT u.fullname
                          FROM core_platform.cp_users u
                         WHERE u.tenant_id = t.id
                           AND u.is_owner = true
                           AND u.delete_status = 'NOT_DELETED'
                           AND BTRIM(COALESCE(u.fullname, '')) <> ''
                         ORDER BY u.cdatetime NULLS LAST
                         LIMIT 1),

                       -- 3. The ops-side registry, which survives a tenant whose
                       --    owner row has since been removed.
                       (SELECT r.fullname
                          FROM core_platform.cp_tenant_owners_registry r
                         WHERE r.tenant_id = t.id
                           AND BTRIM(COALESCE(r.fullname, '')) <> ''
                         ORDER BY r.is_active DESC, r.cdatetime NULLS LAST
                         LIMIT 1),

                       -- 4. Nothing known about it. Still has to be nameable, and
                       --    a short id is at least something support can be given
                       --    over the phone.
                       'Organisation ' || LEFT(REPLACE(t.id, 'tenant-', ''), 8)

                   )), 120)
                 WHERE t.tenant_name IS NULL;
            ");

            // The seeded system tenant is not a customer and has no owner or
            // organisation, so it would fall to branch 4 and be called
            // 'Organisation system-t'. It is named here instead. 03_roles.sql
            // also sets it, but seeds and migrations run in separate passes and
            // this must hold on its own.
            migrationBuilder.Sql(@"
                UPDATE core_platform.cp_tenants
                   SET tenant_name = 'Trovesuite System'
                 WHERE id = 'system-tenant-id';
            ");

            // NOT NULL plus a default. The default is for the deploy window:
            // migrations ship on a separate pipeline from the backend, so the OLD
            // backend runs against this column for a while and its tenant INSERT
            // does not name it. Without a default that insert fails NOT NULL and
            // signup is down until the backend lands.
            migrationBuilder.AlterColumn<string>(
                name: "tenant_name",
                schema: "core_platform",
                table: "cp_tenants",
                type: "character varying(120)",
                maxLength: 120,
                nullable: false,
                defaultValue: "Unnamed organisation");

            // Added last. A name of spaces satisfies NOT NULL and renders as
            // empty everywhere it is shown, which is the failure NOT NULL was
            // supposed to prevent.
            migrationBuilder.AddCheckConstraint(
                name: "ck_cp_tenants_tenant_name_not_blank",
                schema: "core_platform",
                table: "cp_tenants",
                sql: "btrim(tenant_name) <> ''");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_cp_tenants_tenant_name_not_blank",
                schema: "core_platform",
                table: "cp_tenants");

            migrationBuilder.DropColumn(
                name: "tenant_name",
                schema: "core_platform",
                table: "cp_tenants");
        }
    }
}
