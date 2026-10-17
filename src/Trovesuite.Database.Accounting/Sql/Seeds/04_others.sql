SET search_path TO core_platform;

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-accounting-admin', 'permission-app-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-organization-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-accounting-admin', 'permission-user-get-locations'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-organisation-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-organisation-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-account-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-post'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-approve'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-reverse'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-journal-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-report-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-dimension-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-dimension-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-dimension-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-currency-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-currency-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-currency-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-tax-code-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-tax-code-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-tax-code-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-customer-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-customer-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-customer-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-customer-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-approve'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-invoice-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-approve'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bill-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-receipt-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-receipt-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-receipt-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-receipt-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-payment-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-payment-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-payment-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-payment-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-credit-note-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-credit-note-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-credit-note-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-credit-note-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-credit-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-credit-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-credit-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-supplier-credit-void'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-exchange-rate-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-exchange-rate-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-exchange-rate-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-custom-field-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-custom-field-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-custom-field-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-custom-field-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-data-source-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-data-source-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-data-source-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-user-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-opening-balance-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-opening-balance-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-statement-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-statement-import'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-statement-exclude'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-statement-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-import-post'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-data-source-sync'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-field-mapping-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-field-mapping-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounting-rule-create'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounting-rule-delete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounting-rule-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-accounting-rule-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-audit-log-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-account-create'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-account-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-account-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-account-transfer'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-bank-account-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-data-source-create'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-field-mapping-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-field-mapping-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-period-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-year-close'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-fiscal-year-reopen'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-reconciliation-complete'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-reconciliation-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-reconciliation-reopen'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-reconciliation-update'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-revaluation-add'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-revaluation-get'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-revaluation-list'),
('system-tenant-id', 'role-accounting-admin', 'permission-accounting-tax-code-create')
ON CONFLICT DO NOTHING;

-- Retired ids (WI-19). The API accepted each old id as the id that replaced it; before it stopped, every role
-- holding an old id gets the new ones, and only then are the eleven ids no endpoint requires deleted. This runs
-- every deploy but does work only while an old id still exists, and nothing creates them any more, so it acts
-- once per database -- after the ids above exist, which an EF migration (they run before the seeds) could not
-- rely on for a database that skipped the deploy that added them. Grants count while NOT_DELETED: the auth
-- package ignores is_active, so an inactive grant still opened the endpoint.
DROP TABLE IF EXISTS pg_temp.acc_legacy_pairs, pg_temp.acc_retired_ids;
CREATE TEMP TABLE acc_legacy_pairs (old_id text NOT NULL, new_id text NOT NULL);
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

CREATE TEMP TABLE acc_retired_ids (id text NOT NULL);
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

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id)
SELECT DISTINCT g.tenant_id, g.role_id, p.new_id
  FROM core_platform.cp_role_permissions g
  JOIN acc_legacy_pairs p ON p.old_id = g.permission_id
  JOIN core_platform.cp_permissions np ON np.id = p.new_id
 WHERE g.delete_status = 'NOT_DELETED'
   AND EXISTS (SELECT 1 FROM core_platform.cp_permissions o
                WHERE o.id IN (SELECT id FROM acc_retired_ids))
ON CONFLICT (tenant_id, role_id, permission_id) DO UPDATE
   SET is_active = TRUE, delete_status = 'NOT_DELETED'
 WHERE NOT (core_platform.cp_role_permissions.is_active
            AND core_platform.cp_role_permissions.delete_status = 'NOT_DELETED');

DO $retire$
DECLARE short int;
BEGIN
    SELECT count(*) INTO short
      FROM core_platform.cp_role_permissions g
      JOIN acc_legacy_pairs p ON p.old_id = g.permission_id
     WHERE g.delete_status = 'NOT_DELETED'
       AND EXISTS (SELECT 1 FROM core_platform.cp_permissions o
                    WHERE o.id IN (SELECT id FROM acc_retired_ids))
       AND NOT EXISTS (
           SELECT 1 FROM core_platform.cp_role_permissions n
            WHERE n.tenant_id = g.tenant_id AND n.role_id = g.role_id AND n.permission_id = p.new_id
              AND n.is_active AND n.delete_status = 'NOT_DELETED');
    IF short > 0 THEN
        RAISE EXCEPTION 'accounting: % old-id grant(s) could not be carried to their new ids; nothing was retired', short;
    END IF;
END
$retire$;

DELETE FROM core_platform.cp_role_permissions WHERE permission_id IN (SELECT id FROM acc_retired_ids);
DELETE FROM core_platform.cp_permissions WHERE id IN (SELECT id FROM acc_retired_ids);
DROP TABLE pg_temp.acc_legacy_pairs, pg_temp.acc_retired_ids;
