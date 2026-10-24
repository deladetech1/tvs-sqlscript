-- HMS: cleaning teams and inspections, outside contractors, and security deposits.
--
--   hms_housekeeping_tasks   several people on one clean (assignees), who actually cleaned it,
--                            and the supervisor's inspection: passed, or failed and sent back.
--   hms_maintenance_tickets  assigned to staff or to an outside contractor (their name, phone,
--                            email, where they are), and the supervisor's inspection of the work.
--   hms_security_deposits,
--   hms_deposit_movements    refundable money held against damage beyond fair wear and tear,
--                            unpaid rent or a broken agreement: taken before moving in (a lease) or
--                            checking in (a stay), kept back in part with reasons and evidence,
--                            refunded or forfeited. A liability, never revenue, until kept.

BEGIN;

-- ============================================================= housekeeping
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS assignees text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS cleaned_by text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS started_at timestamptz;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS inspection_result text;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS inspection_note text;
ALTER TABLE hms.hms_housekeeping_tasks ADD COLUMN IF NOT EXISTS failed_inspections int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_housekeeping_tasks DROP CONSTRAINT IF EXISTS hms_housekeeping_tasks_inspection_check;
ALTER TABLE hms.hms_housekeeping_tasks ADD CONSTRAINT hms_housekeeping_tasks_inspection_check
    CHECK (inspection_result IS NULL OR inspection_result IN ('passed', 'failed'));
UPDATE hms.hms_housekeeping_tasks SET assignees = ARRAY[assigned_to] WHERE assigned_to IS NOT NULL AND cardinality(assignees) = 0;
UPDATE hms.hms_housekeeping_tasks SET cleaned_by = ARRAY[completed_by]
 WHERE completed_by IS NOT NULL AND cardinality(cleaned_by) = 0 AND status IN ('done', 'inspected');
CREATE INDEX IF NOT EXISTS hms_housekeeping_tasks_done_idx ON hms.hms_housekeeping_tasks (bus_id, completed_at) WHERE completed_at IS NOT NULL;

-- ============================================================== maintenance
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS assignee_type text NOT NULL DEFAULT 'internal';
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS external_name text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS external_phone text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS external_email text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS external_location text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS inspected_at timestamptz;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS inspected_by text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS inspection_result text;
ALTER TABLE hms.hms_maintenance_tickets ADD COLUMN IF NOT EXISTS inspection_note text;
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_assignee_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_assignee_check CHECK (assignee_type IN ('internal', 'external'));
ALTER TABLE hms.hms_maintenance_tickets DROP CONSTRAINT IF EXISTS hms_maintenance_tickets_inspection_check;
ALTER TABLE hms.hms_maintenance_tickets ADD CONSTRAINT hms_maintenance_tickets_inspection_check
    CHECK (inspection_result IS NULL OR inspection_result IN ('passed', 'failed'));

-- ========================================================= security deposits
CREATE TABLE IF NOT EXISTS hms.hms_security_deposits (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    property_id     text REFERENCES hms.hms_properties (id),
    code            text NOT NULL,
    lease_id        text REFERENCES hms.hms_leases (id),
    reservation_id  text REFERENCES hms.hms_reservations (id),
    renter_id       text REFERENCES hms.hms_renters (id),
    guest_id        text REFERENCES hms.hms_guests (id),
    holder_name     text NOT NULL,
    holder_phone    text,
    holder_email    text,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    currency        text NOT NULL,
    status          text NOT NULL DEFAULT 'pending',
    due_back_on     date,
    terms           text,
    notes           text,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_security_deposits DROP CONSTRAINT IF EXISTS hms_security_deposits_status_check;
ALTER TABLE hms.hms_security_deposits ADD CONSTRAINT hms_security_deposits_status_check
    CHECK (status IN ('pending', 'held', 'part_refunded', 'refunded', 'forfeited', 'cancelled'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_security_deposits_code_uq ON hms.hms_security_deposits (bus_id, code);
CREATE INDEX IF NOT EXISTS hms_security_deposits_bus_idx ON hms.hms_security_deposits (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hms.hms_deposit_movements (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    deposit_id      text NOT NULL REFERENCES hms.hms_security_deposits (id),
    kind            text NOT NULL,             -- received, deduction, refund, forfeit
    category        text,                      -- for a deduction
    description     text,
    amount          numeric(14,2) NOT NULL CHECK (amount > 0),
    method          text,
    reference       text,
    on_date         date NOT NULL DEFAULT CURRENT_DATE,
    voided_at       timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text
);
ALTER TABLE hms.hms_deposit_movements DROP CONSTRAINT IF EXISTS hms_deposit_movements_kind_check;
ALTER TABLE hms.hms_deposit_movements ADD CONSTRAINT hms_deposit_movements_kind_check CHECK (kind IN ('received', 'deduction', 'refund', 'forfeit'));
ALTER TABLE hms.hms_deposit_movements DROP CONSTRAINT IF EXISTS hms_deposit_movements_category_check;
ALTER TABLE hms.hms_deposit_movements ADD CONSTRAINT hms_deposit_movements_category_check CHECK (category IS NULL OR category IN
    ('damage', 'unpaid_rent', 'unpaid_bill', 'cleaning', 'lease_violation', 'missing_items', 'keys', 'other'));
CREATE INDEX IF NOT EXISTS hms_deposit_movements_deposit_idx ON hms.hms_deposit_movements (deposit_id, cdatetime);

-- Evidence of damage on a deposit (photos, quotes).
ALTER TABLE hms.hms_files DROP CONSTRAINT IF EXISTS hms_files_entity_check;
ALTER TABLE hms.hms_files ADD CONSTRAINT hms_files_entity_check CHECK (entity_type IS NULL OR entity_type IN
    ('property', 'unit_type', 'unit', 'guest', 'reservation', 'lease', 'renter', 'ticket', 'lost_item', 'asset', 'event', 'expense', 'staff',
     'menu_item', 'menu_category', 'addon', 'activity', 'table', 'stock_item', 'voucher', 'owner', 'site', 'invoice', 'deposit', 'housekeeping_task'));

COMMIT;
