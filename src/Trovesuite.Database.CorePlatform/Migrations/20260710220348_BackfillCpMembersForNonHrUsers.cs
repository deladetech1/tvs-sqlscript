using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.CorePlatform.Migrations
{
    /// <inheritdoc />
    public partial class BackfillCpMembersForNonHrUsers : Migration
    {
        // Sentinel written to cp_members.description so the backfilled rows can be
        // identified and removed cleanly in Down() without touching app-created rows.
        private const string BackfillTag = "backfill:cp_members:20260710220348";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Backfill cp_members for every cp_users row that is missing one, EXCEPT
            // HR-onboarded users (they live in cp_users + zeloshr.zhr_employees and must
            // stay out of the core-platform membership gate). Users imported from the
            // legacy backup never went through create_user/signup, so they have no
            // cp_members row and are currently locked out of login / password reset.
            //
            // The member row mirrors the user's delete_status, and derives is_active
            // from it (is_active = delete_status = 'NOT_DELETED'). This matches the app
            // invariant: cp_members.is_active tracks MEMBERSHIP deletion, not the user's
            // account-active flag. Deactivating a user never touches cp_members, so a
            // deactivated-but-not-deleted user keeps an active member row and can still
            // have their password reset -- backfilled rows must behave identically.
            // Guarded on to_regclass so the migration also runs on databases where the
            // HR (zeloshr) schema is not installed.
            migrationBuilder.Sql($@"
DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_employees') IS NOT NULL THEN
        INSERT INTO core_platform.cp_members
            (tenant_id, user_id, is_active, delete_status, created_by, description)
        SELECT u.tenant_id, u.id, (u.delete_status = 'NOT_DELETED'), u.delete_status, u.id, '{BackfillTag}'
        FROM core_platform.cp_users u
        WHERE NOT EXISTS (
                SELECT 1 FROM core_platform.cp_members m
                WHERE m.user_id = u.id AND m.tenant_id = u.tenant_id)
          AND NOT EXISTS (
                SELECT 1 FROM zeloshr.zhr_employees e
                WHERE e.user_id = u.id AND e.tenant_id = u.tenant_id);
    ELSE
        INSERT INTO core_platform.cp_members
            (tenant_id, user_id, is_active, delete_status, created_by, description)
        SELECT u.tenant_id, u.id, (u.delete_status = 'NOT_DELETED'), u.delete_status, u.id, '{BackfillTag}'
        FROM core_platform.cp_users u
        WHERE NOT EXISTS (
                SELECT 1 FROM core_platform.cp_members m
                WHERE m.user_id = u.id AND m.tenant_id = u.tenant_id);
    END IF;
END $$;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                $"DELETE FROM core_platform.cp_members WHERE description = '{BackfillTag}';");
        }
    }
}
