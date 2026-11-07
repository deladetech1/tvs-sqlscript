-- CloudHams (app-hospital), part 8: the workspace and the money behind the facility.
--
-- Activities: tasks and follow-ups (assigned, due, done) and meetings, in hospital_entries.
-- The calendar: appointments, theatre, shifts, tasks and meetings in one place (no table).
-- Expenses: what the facility spends, submitted, approved by someone else and paid, with the
-- receipt attached (hospital_entries; files may now belong to an expense).
-- Finance: money in (payments) against money out (expenses), month by month (no table).
-- Messages: SMS to a patient or a group of them (tomorrow's appointments, the admitted, a list),
-- each one kept in hospital_messages.
--
-- Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= receipts
SELECT hospital.widen_check('hospital.hospital_files', 'hospital_files_entity_check', $q$'expense'$q$,
    $q$CHECK (entity_type IS NULL OR entity_type IN ('facility', 'patient', 'encounter', 'order', 'expense'))$q$);

-- ======================================================================= messages
CREATE TABLE IF NOT EXISTS hospital.hospital_messages (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    batch_id      text NOT NULL,
    audience      text NOT NULL,
    patient_id    text REFERENCES hospital.hospital_patients(id),
    to_name       text,
    to_phone      text NOT NULL,
    body          text NOT NULL,
    status        text NOT NULL DEFAULT 'sent',
    error         text,
    sent_by       text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
SELECT hospital.widen_check('hospital.hospital_messages', 'hospital_messages_status_check', $q$'failed'$q$,
    $q$CHECK (status IN ('sent', 'failed'))$q$);
CREATE INDEX IF NOT EXISTS hospital_messages_facility_idx ON hospital.hospital_messages (facility_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS hospital_messages_batch_idx ON hospital.hospital_messages (batch_id);
CREATE INDEX IF NOT EXISTS hospital_messages_patient_idx ON hospital.hospital_messages (patient_id, cdatetime DESC);

-- Tasks are found by who they are assigned to.
CREATE INDEX IF NOT EXISTS hospital_entries_assigned_idx ON hospital.hospital_entries (assigned_to, kind, status) WHERE assigned_to IS NOT NULL;

-- ======================================================================= permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-hospital-expenses', 'CloudHams Expenses', 'What the facility spends, approved and paid', 'rt-subscribed-app-hospital'),
('rt-hospital-messages', 'CloudHams Messages', 'Text messages to patients', 'rt-subscribed-app-hospital')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name, description = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('expenses', 'rt-hospital-expenses', 'get',     'View expenses and the finance overview'),
    ('expenses', 'rt-hospital-expenses', 'create',  'Record expenses and submit them for approval'),
    ('expenses', 'rt-hospital-expenses', 'approve', 'Approve, reject and pay expenses'),
    ('messages', 'rt-hospital-messages', 'get',     'View the messages sent to patients'),
    ('messages', 'rt-hospital-messages', 'send',    'Send text messages to patients')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-hospital-' || spec.resource_key || '-' || spec.action,
       'CloudHams ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name = EXCLUDED.permission_name, resource_type_id = EXCLUDED.resource_type_id,
                               description = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'hospital', resource_key = substring(p.id FROM '^permission-hospital-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'), target = '', scope = 'any'
 WHERE p.id LIKE 'permission-hospital-%' AND (p.app_prefix IS DISTINCT FROM 'hospital' OR p.action IS NULL);

-- Everyone records what they spend; the director and billing approve; the viewer reads.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description), CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
    ('role-hospital-director', 'expenses', 'get'), ('role-hospital-director', 'expenses', 'create'), ('role-hospital-director', 'expenses', 'approve'),
    ('role-hospital-director', 'messages', 'get'), ('role-hospital-director', 'messages', 'send'),
    ('role-hospital-billing', 'expenses', 'get'), ('role-hospital-billing', 'expenses', 'create'), ('role-hospital-billing', 'expenses', 'approve'),
    ('role-hospital-billing', 'messages', 'get'), ('role-hospital-billing', 'messages', 'send'),
    ('role-hospital-cashier', 'expenses', 'get'), ('role-hospital-cashier', 'expenses', 'create'),
    ('role-hospital-records', 'messages', 'get'), ('role-hospital-records', 'messages', 'send'), ('role-hospital-records', 'expenses', 'create'),
    ('role-hospital-relations', 'messages', 'get'), ('role-hospital-relations', 'messages', 'send'), ('role-hospital-relations', 'expenses', 'create'),
    ('role-hospital-operations', 'expenses', 'get'), ('role-hospital-operations', 'expenses', 'create'),
    ('role-hospital-doctor', 'expenses', 'create'), ('role-hospital-nurse', 'expenses', 'create'),
    ('role-hospital-lab', 'expenses', 'create'), ('role-hospital-pharmacist', 'expenses', 'create'),
    ('role-hospital-viewer', 'expenses', 'get'), ('role-hospital-viewer', 'messages', 'get')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p ON p.app_prefix = 'hospital' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ============================================================ features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.activities', 'app-hospital', 'Activities',  1, 'Tasks and follow-ups assigned to staff with due dates, and meetings'),
('hospital.calendar',   'app-hospital', 'Calendar',    1, 'Appointments, theatre, shifts, tasks and meetings by day, week and month'),
('hospital.expenses',   'app-hospital', 'Expenses',    1, 'Spending recorded with receipts, approved by someone else and paid'),
('hospital.finance',    'app-hospital', 'Finance',     2, 'Money in against money out, month by month, with what is owed and claimed'),
('hospital.messages',   'app-hospital', 'Messages',    2, 'Text messages to a patient or a group: tomorrow''s appointments, the admitted, a list')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
