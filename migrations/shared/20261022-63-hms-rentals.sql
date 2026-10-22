-- HMS rentals: long lets, kept apart from short stays.
--
--   hms_renters       the people (or companies) who rent; "tenants" on screen, but
--                     tenant_id already means the platform's customer everywhere else
--   hms_leases        a unit let to a renter: rent, how often, advance, deposit
--   hms_rent_charges  what is owed: each period's rent, the deposit, utilities, late fees
--   hms_rent_payments what was paid; corrected by reversal, never edited
--
-- Arrears are what has fallen due less what has been paid, per lease. A unit has at most one
-- active lease, enforced here rather than trusted to the API.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS hms.hms_renters (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    full_name         text NOT NULL,
    email             text,
    phone             text,
    id_type           text,
    id_number         text,
    occupation        text,
    emergency_contact text,
    notes             text,
    archived_at       timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);
CREATE INDEX IF NOT EXISTS hms_renters_business_idx ON hms.hms_renters (bus_id, lower(full_name));

CREATE TABLE IF NOT EXISTS hms.hms_leases (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    property_id      text NOT NULL REFERENCES hms.hms_properties (id),
    unit_id          text NOT NULL REFERENCES hms.hms_units (id),
    renter_id        text NOT NULL REFERENCES hms.hms_renters (id),
    code             text NOT NULL,
    status           text NOT NULL DEFAULT 'draft',
    starts_on        date NOT NULL,
    ends_on          date,
    rent_amount      numeric(14,2) NOT NULL CHECK (rent_amount > 0),
    rent_period      text NOT NULL DEFAULT 'month',
    -- How many periods are paid up front when the lease starts (two years' rent is common in Ghana).
    advance_periods  int NOT NULL DEFAULT 1 CHECK (advance_periods BETWEEN 1 AND 60),
    deposit_amount   numeric(14,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
    deposit_refunded numeric(14,2) NOT NULL DEFAULT 0 CHECK (deposit_refunded >= 0),
    late_fee         numeric(14,2) NOT NULL DEFAULT 0 CHECK (late_fee >= 0),
    grace_days       int NOT NULL DEFAULT 5 CHECK (grace_days BETWEEN 0 AND 60),
    currency         text NOT NULL DEFAULT 'GHS',
    notes            text,
    ended_on         date,
    end_reason       text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hms_leases_dates_check CHECK (ends_on IS NULL OR ends_on > starts_on)
);
ALTER TABLE hms.hms_leases DROP CONSTRAINT IF EXISTS hms_leases_status_check;
ALTER TABLE hms.hms_leases ADD CONSTRAINT hms_leases_status_check CHECK (status IN ('draft', 'active', 'ended', 'terminated'));
ALTER TABLE hms.hms_leases DROP CONSTRAINT IF EXISTS hms_leases_rent_period_check;
ALTER TABLE hms.hms_leases ADD CONSTRAINT hms_leases_rent_period_check CHECK (rent_period IN ('month', 'quarter', 'half_year', 'year'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_leases_code_uq ON hms.hms_leases (bus_id, code);
CREATE UNIQUE INDEX IF NOT EXISTS hms_leases_one_active_uq ON hms.hms_leases (unit_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS hms_leases_business_idx ON hms.hms_leases (bus_id, status);

CREATE TABLE IF NOT EXISTS hms.hms_rent_charges (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    lease_id         text NOT NULL REFERENCES hms.hms_leases (id),
    kind             text NOT NULL DEFAULT 'rent',
    description      text NOT NULL,
    period_start     date,
    period_end       date,
    due_on           date NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    voided_at        timestamptz,
    voided_by        text,
    void_reason      text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text
);
ALTER TABLE hms.hms_rent_charges DROP CONSTRAINT IF EXISTS hms_rent_charges_kind_check;
ALTER TABLE hms.hms_rent_charges ADD CONSTRAINT hms_rent_charges_kind_check CHECK (kind IN ('rent', 'deposit', 'utility', 'late_fee', 'service', 'other'));
-- Generating a period's rent twice writes it once.
CREATE UNIQUE INDEX IF NOT EXISTS hms_rent_charges_period_uq ON hms.hms_rent_charges (lease_id, kind, period_start)
    WHERE kind IN ('rent', 'late_fee') AND voided_at IS NULL;
CREATE INDEX IF NOT EXISTS hms_rent_charges_due_idx ON hms.hms_rent_charges (bus_id, due_on);

CREATE TABLE IF NOT EXISTS hms.hms_rent_payments (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    lease_id            text NOT NULL REFERENCES hms.hms_leases (id),
    amount              numeric(14,2) NOT NULL CHECK (amount > 0),
    paid_on             date NOT NULL,
    method              text NOT NULL DEFAULT 'cash',
    reference           text,
    notes               text,
    reverses_payment_id text REFERENCES hms.hms_rent_payments (id),
    idempotency_key     text,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    recorded_by         text
);
ALTER TABLE hms.hms_rent_payments DROP CONSTRAINT IF EXISTS hms_rent_payments_method_check;
ALTER TABLE hms.hms_rent_payments ADD CONSTRAINT hms_rent_payments_method_check CHECK (method IN ('cash', 'card', 'momo', 'bank', 'cheque', 'other'));
CREATE UNIQUE INDEX IF NOT EXISTS hms_rent_payments_reverses_uq ON hms.hms_rent_payments (reverses_payment_id) WHERE reverses_payment_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hms_rent_payments_idem_uq ON hms.hms_rent_payments (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS hms_rent_payments_lease_idx ON hms.hms_rent_payments (lease_id, paid_on);

COMMIT;
