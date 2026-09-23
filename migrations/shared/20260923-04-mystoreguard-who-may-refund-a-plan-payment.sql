-- Who may give a plan payment back.
--
-- Refunding a plan payment hands money out of the till and reopens a debt the
-- customer believed was settled. That is not the same authority as taking a
-- payment, so it does not ride on the payment permission.
--
-- It is granted to exactly the roles that already hold close-refund, which is
-- the closest thing the shop already has: the permission for declaring that
-- money owed back to a customer has changed hands. A shop that trusts somebody
-- with one already trusts them with the other, and a shop that does not can
-- take it away from either.
--
-- Replayable.

BEGIN;

INSERT INTO core_platform.cp_permissions
    (id, permission_name, description, resource_type_id, cdate, ctime, cdatetime)
VALUES (
    'permission-msg-installment-plan-refund-payment',
    'Mystoreguard Installment Payment Refund',
    'Can give a plan payment back and put the plan where it stood before it. '
    'Held separately from taking payments: it hands money out of the till and '
    'reopens a debt the customer thought was settled.',
    'rt-installment-plans',
    CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
)
ON CONFLICT (id) DO NOTHING;

-- Every role, in every tenant, that can already close a refund.
INSERT INTO core_platform.cp_role_permissions
    (tenant_id, id, role_id, permission_id, cdate, ctime, cdatetime)
SELECT rp.tenant_id,
       'rp-msg-inst-refund-pay-' || substr(md5(rp.tenant_id || rp.role_id), 1, 24),
       rp.role_id,
       'permission-msg-installment-plan-refund-payment',
       CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP
  FROM core_platform.cp_role_permissions rp
 WHERE rp.permission_id = 'permission-msg-installment-plan-close-refund'
   AND NOT EXISTS (
       SELECT 1 FROM core_platform.cp_role_permissions x
        WHERE x.tenant_id = rp.tenant_id
          AND x.role_id = rp.role_id
          AND x.permission_id = 'permission-msg-installment-plan-refund-payment')
 GROUP BY rp.tenant_id, rp.role_id;

COMMIT;
