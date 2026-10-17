using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class RetireLegacyPermissionIds : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The API accepted each old id as the id that replaced it (AccountingPermissions.LegacyAliases). Before
            // it stops, every role holding an old id is given the new ones, so nobody loses access; then the eleven
            // ids that no endpoint requires any more are deleted. This must run once: the seeds re-run every deploy,
            // and copying again would re-grant whatever an administrator later removed.
            //
            // On a fresh database this runs before the Accounting seeds, so there is nothing to copy or delete.
            migrationBuilder.Sql("""
                CREATE TEMP TABLE acc_legacy_pairs (old_id text NOT NULL, new_id text NOT NULL) ON COMMIT DROP;
                INSERT INTO acc_legacy_pairs (old_id, new_id) VALUES
                    ('permission-accounting-audit-get', 'permission-accounting-audit-log-list'),
                    ('permission-accounting-bank-add', 'permission-accounting-bank-account-create'),
                    ('permission-accounting-bank-get', 'permission-accounting-bank-account-get'),
                    ('permission-accounting-bank-get', 'permission-accounting-reconciliation-get'),
                    ('permission-accounting-bank-list', 'permission-accounting-bank-account-list'),
                    ('permission-accounting-bank-update', 'permission-accounting-bank-account-transfer'),
                    ('permission-accounting-bank-update', 'permission-accounting-bank-account-update'),
                    ('permission-accounting-bank-update', 'permission-accounting-reconciliation-complete'),
                    ('permission-accounting-bank-update', 'permission-accounting-reconciliation-reopen'),
                    ('permission-accounting-bank-update', 'permission-accounting-reconciliation-update'),
                    ('permission-accounting-data-source-add', 'permission-accounting-data-source-create'),
                    ('permission-accounting-data-source-add', 'permission-accounting-field-mapping-add'),
                    ('permission-accounting-data-source-list', 'permission-accounting-field-mapping-list'),
                    ('permission-accounting-exchange-rate-add', 'permission-accounting-revaluation-add'),
                    ('permission-accounting-exchange-rate-list', 'permission-accounting-revaluation-get'),
                    ('permission-accounting-exchange-rate-list', 'permission-accounting-revaluation-list'),
                    ('permission-accounting-fiscal-period-list', 'permission-accounting-fiscal-period-get'),
                    ('permission-accounting-fiscal-period-update', 'permission-accounting-fiscal-period-add'),
                    ('permission-accounting-fiscal-period-update', 'permission-accounting-fiscal-year-close'),
                    ('permission-accounting-fiscal-period-update', 'permission-accounting-fiscal-year-reopen'),
                    ('permission-accounting-rule-add', 'permission-accounting-accounting-rule-create'),
                    ('permission-accounting-rule-delete', 'permission-accounting-accounting-rule-delete'),
                    ('permission-accounting-rule-list', 'permission-accounting-accounting-rule-list'),
                    ('permission-accounting-rule-update', 'permission-accounting-accounting-rule-update'),
                    ('permission-accounting-tax-code-add', 'permission-accounting-tax-code-create');

                INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
                SELECT DISTINCT g.tenant_id, g.role_id, p.new_id
                  FROM core_platform.cp_role_permissions g
                  JOIN acc_legacy_pairs p ON p.old_id = g.permission_id
                  JOIN core_platform.cp_permissions np ON np.id = p.new_id
                 WHERE g.is_active AND g.delete_status = 'NOT_DELETED'
                ON CONFLICT (tenant_id, role_id, permission_id) DO UPDATE
                   SET is_active = TRUE, delete_status = 'NOT_DELETED'
                 WHERE NOT (core_platform.cp_role_permissions.is_active
                            AND core_platform.cp_role_permissions.delete_status = 'NOT_DELETED');

                DO $guard$
                DECLARE short int;
                BEGIN
                    SELECT count(*) INTO short
                      FROM core_platform.cp_role_permissions g
                      JOIN acc_legacy_pairs p ON p.old_id = g.permission_id
                     WHERE g.is_active AND g.delete_status = 'NOT_DELETED'
                       AND NOT EXISTS (
                           SELECT 1 FROM core_platform.cp_role_permissions n
                            WHERE n.tenant_id = g.tenant_id AND n.role_id = g.role_id AND n.permission_id = p.new_id
                              AND n.is_active AND n.delete_status = 'NOT_DELETED');
                    IF short > 0 THEN
                        RAISE EXCEPTION 'accounting: % old-id grant(s) could not be carried to their new ids; nothing was retired', short;
                    END IF;
                END
                $guard$;

                CREATE TEMP TABLE acc_retired_ids (id text NOT NULL) ON COMMIT DROP;
                INSERT INTO acc_retired_ids (id) VALUES
                    ('permission-accounting-audit-get'),
                    ('permission-accounting-bank-add'),
                    ('permission-accounting-bank-get'),
                    ('permission-accounting-bank-list'),
                    ('permission-accounting-bank-update'),
                    ('permission-accounting-data-source-add'),
                    ('permission-accounting-rule-add'),
                    ('permission-accounting-rule-delete'),
                    ('permission-accounting-rule-list'),
                    ('permission-accounting-rule-update'),
                    ('permission-accounting-tax-code-add');

                DELETE FROM core_platform.cp_role_permissions
                 WHERE permission_id IN (SELECT id FROM acc_retired_ids);
                DELETE FROM core_platform.cp_permissions
                 WHERE id IN (SELECT id FROM acc_retired_ids);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Not reversible: the retired ids' grants were folded into the ids that replaced them.
        }
    }
}
