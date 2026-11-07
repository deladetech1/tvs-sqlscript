-- Hospital, part 4: billing and insurance claims.
--
--   * services and their prices (consultations, procedures, imaging, nursing, registration);
--     lab tests, medicines and bed days carry their own price (part 3);
--   * payers: government schemes (NHIS, NHIF/SHA, NHIA, Medicare, a national health service),
--     private insurers, corporate schemes; each patient's policies with them;
--   * charges: every service captured on the visit it was given in. Immutable: a correction is a
--     reversal (a negative charge pointing at the one it reverses) plus a new charge;
--   * payments (with their receipts), deposits and refunds; waivers awaiting approval;
--   * claims built from a visit's covered charges, followed to payment;
--   * payments started online through the organisation's gateway in Core Platform.
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS hospital.hospital_services (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    code        text,
    name        text NOT NULL,
    category    text NOT NULL DEFAULT 'procedure'
                CHECK (category IN ('registration', 'consultation', 'procedure', 'imaging', 'nursing', 'theatre', 'bed', 'other')),
    price       numeric(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    is_active   boolean NOT NULL DEFAULT true,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_services_name_uq ON hospital.hospital_services (bus_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_payers (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    name              text NOT NULL,
    kind              text NOT NULL DEFAULT 'private_insurer' CHECK (kind IN ('government', 'private_insurer', 'corporate', 'other')),
    code              text,
    coverage_percent  numeric(5,2) NOT NULL DEFAULT 100 CHECK (coverage_percent BETWEEN 0 AND 100),
    phone             text,
    email             text,
    claim_days        int NOT NULL DEFAULT 30,
    is_active         boolean NOT NULL DEFAULT true,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_payers_name_uq ON hospital.hospital_payers (bus_id, lower(name));

CREATE TABLE IF NOT EXISTS hospital.hospital_policies (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    bus_id            text NOT NULL,
    patient_id        text NOT NULL REFERENCES hospital.hospital_patients(id) ON DELETE CASCADE,
    payer_id          text NOT NULL REFERENCES hospital.hospital_payers(id),
    member_no         text NOT NULL,
    plan_name         text,
    valid_from        date,
    valid_to          date,
    -- NULL: the payer's own coverage.
    coverage_percent  numeric(5,2) CHECK (coverage_percent BETWEEN 0 AND 100),
    is_primary        boolean NOT NULL DEFAULT true,
    status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_policies_member_uq ON hospital.hospital_policies (payer_id, lower(member_no));
CREATE INDEX IF NOT EXISTS hospital_policies_patient_idx ON hospital.hospital_policies (patient_id);

CREATE TABLE IF NOT EXISTS hospital.hospital_charges (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    facility_id     text NOT NULL,
    encounter_id    text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id      text NOT NULL REFERENCES hospital.hospital_patients(id),
    source          text NOT NULL CHECK (source IN ('consultation', 'lab', 'drug', 'procedure', 'imaging', 'bed', 'service', 'manual')),
    source_id       text,
    service_id      text,
    description     text NOT NULL,
    quantity        numeric NOT NULL DEFAULT 1,
    unit_price      numeric(14,2) NOT NULL,
    amount          numeric(14,2) NOT NULL,
    payer_id        text REFERENCES hospital.hospital_payers(id),
    covered_amount  numeric(14,2) NOT NULL DEFAULT 0,
    patient_amount  numeric(14,2) NOT NULL,
    reverses_id     text REFERENCES hospital.hospital_charges(id),
    reason          text,
    created_by      text,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_charges_encounter_idx ON hospital.hospital_charges (encounter_id);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_charges_reversal_uq ON hospital.hospital_charges (reverses_id) WHERE reverses_id IS NOT NULL;

CREATE OR REPLACE FUNCTION hospital.charges_are_final() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF coalesce(current_setting('hospital.purge', true), '') = 'on' THEN
        RETURN coalesce(NEW, OLD);
    END IF;
    RAISE EXCEPTION 'a charge is never changed: reverse it and post it again' USING ERRCODE = 'check_violation';
END
$f$;
DROP TRIGGER IF EXISTS hospital_charges_final ON hospital.hospital_charges;
CREATE TRIGGER hospital_charges_final BEFORE UPDATE OR DELETE ON hospital.hospital_charges
    FOR EACH ROW EXECUTE FUNCTION hospital.charges_are_final();

CREATE TABLE IF NOT EXISTS hospital.hospital_payments (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL,
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    encounter_id  text REFERENCES hospital.hospital_encounters(id),
    receipt_no    text NOT NULL,
    kind          text NOT NULL DEFAULT 'payment' CHECK (kind IN ('payment', 'deposit', 'refund')),
    amount        numeric(14,2) NOT NULL CHECK (amount > 0),
    currency      text,
    method        text NOT NULL CHECK (method IN ('cash', 'card', 'mobile_money', 'bank_transfer', 'cheque', 'online', 'other')),
    reference     text,
    note          text,
    received_by   text,
    voided_at     timestamptz,
    voided_by     text,
    void_reason   text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_payments_receipt_uq ON hospital.hospital_payments (bus_id, receipt_no);
CREATE INDEX IF NOT EXISTS hospital_payments_encounter_idx ON hospital.hospital_payments (encounter_id);
CREATE INDEX IF NOT EXISTS hospital_payments_day_idx ON hospital.hospital_payments (facility_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_waivers (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    facility_id    text NOT NULL,
    encounter_id   text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id     text NOT NULL REFERENCES hospital.hospital_patients(id),
    amount         numeric(14,2) NOT NULL CHECK (amount > 0),
    reason         text NOT NULL,
    status         text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_by   text,
    decided_by     text,
    decided_at     timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_waivers_encounter_idx ON hospital.hospital_waivers (encounter_id);

CREATE TABLE IF NOT EXISTS hospital.hospital_claims (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    facility_id       text NOT NULL,
    payer_id          text NOT NULL REFERENCES hospital.hospital_payers(id),
    policy_id         text REFERENCES hospital.hospital_policies(id),
    encounter_id      text NOT NULL REFERENCES hospital.hospital_encounters(id),
    patient_id        text NOT NULL REFERENCES hospital.hospital_patients(id),
    number            text NOT NULL,
    status            text NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'submitted', 'approved', 'partially_approved', 'rejected', 'paid')),
    amount_claimed    numeric(14,2) NOT NULL DEFAULT 0,
    amount_approved   numeric(14,2),
    amount_paid       numeric(14,2),
    diagnoses         jsonb NOT NULL DEFAULT '[]',
    rejection_reason  text,
    payment_reference text,
    notes             text,
    submitted_at      timestamptz,
    decided_at        timestamptz,
    paid_at           timestamptz,
    created_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_claims_number_uq ON hospital.hospital_claims (bus_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_claims_visit_uq ON hospital.hospital_claims (encounter_id, payer_id);
CREATE INDEX IF NOT EXISTS hospital_claims_status_idx ON hospital.hospital_claims (bus_id, status, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_claim_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    claim_id     text NOT NULL REFERENCES hospital.hospital_claims(id) ON DELETE CASCADE,
    charge_id    text REFERENCES hospital.hospital_charges(id),
    description  text NOT NULL,
    quantity     numeric NOT NULL DEFAULT 1,
    amount       numeric(14,2) NOT NULL
);
CREATE INDEX IF NOT EXISTS hospital_claim_lines_claim_idx ON hospital.hospital_claim_lines (claim_id);

CREATE TABLE IF NOT EXISTS hospital.hospital_online_payments (
    reference     text PRIMARY KEY,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL,
    patient_id    text NOT NULL REFERENCES hospital.hospital_patients(id),
    encounter_id  text REFERENCES hospital.hospital_encounters(id),
    amount_minor  bigint NOT NULL,
    currency      text NOT NULL,
    checkout_url  text,
    status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed')),
    payment_id    text REFERENCES hospital.hospital_payments(id),
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    settled_at    timestamptz
);
CREATE INDEX IF NOT EXISTS hospital_online_pending_idx ON hospital.hospital_online_payments (cdatetime) WHERE status = 'pending';

COMMIT;
