-- CloudHams round 7: a big hospital's stock and receivables.
--
--   hospital_stores                 the stores of a facility: the main store, pharmacies, ward and
--                                   theatre stock. Every batch sits in one; each facility has a
--                                   default store (existing stock moves into it)
--   hospital_stock_transfers(+lines) stock asked for by one store, approved, sent and received by
--                                   another, batch by batch (MyStoreGuard's transfers)
--   hospital_stock_takes(+lines)    a count of a store against the system, posted as adjustments
--                                   only by someone other than whoever counted
--   hospital_invoices(+lines, +payments)  invoices to insurers, companies and others: drafted,
--                                   issued, paid in parts, voided with a reason. A company invoice
--                                   takes over what its patients owed on the visits it lists
--
-- Idempotent; safe to re-run.

BEGIN;

-- ======================================================================= stores
CREATE TABLE IF NOT EXISTS hospital.hospital_stores (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    facility_id  text NOT NULL REFERENCES hospital.hospital_facilities(id),
    name         text NOT NULL,
    kind         text NOT NULL DEFAULT 'pharmacy' CHECK (kind IN ('main', 'pharmacy', 'ward', 'theatre', 'laboratory', 'emergency', 'other')),
    ward_id      text REFERENCES hospital.hospital_wards(id),
    is_default   boolean NOT NULL DEFAULT false,
    dispenses    boolean NOT NULL DEFAULT true,
    receives     boolean NOT NULL DEFAULT true,
    is_active    boolean NOT NULL DEFAULT true,
    keeper_id    text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_stores_name_uq ON hospital.hospital_stores (facility_id, lower(name));
CREATE UNIQUE INDEX IF NOT EXISTS hospital_stores_default_uq ON hospital.hospital_stores (facility_id) WHERE is_default;

INSERT INTO hospital.hospital_stores (tenant_id, bus_id, facility_id, name, kind, is_default)
SELECT f.tenant_id, f.bus_id, f.id, 'Main pharmacy', 'pharmacy', true
  FROM hospital.hospital_facilities f
 WHERE NOT EXISTS (SELECT 1 FROM hospital.hospital_stores s WHERE s.facility_id = f.id AND s.is_default);

ALTER TABLE hospital.hospital_stock_batches ADD COLUMN IF NOT EXISTS store_id text REFERENCES hospital.hospital_stores(id);
ALTER TABLE hospital.hospital_stock_batches ADD COLUMN IF NOT EXISTS invoice_no text;
ALTER TABLE hospital.hospital_stock_moves ADD COLUMN IF NOT EXISTS store_id text REFERENCES hospital.hospital_stores(id);
ALTER TABLE hospital.hospital_stock_moves ADD COLUMN IF NOT EXISTS ref_type text;
ALTER TABLE hospital.hospital_stock_moves ADD COLUMN IF NOT EXISTS ref_id text;
ALTER TABLE hospital.hospital_stock_moves ADD COLUMN IF NOT EXISTS unit_cost numeric(14,4);

UPDATE hospital.hospital_stock_batches b SET store_id = s.id FROM hospital.hospital_stores s
 WHERE b.store_id IS NULL AND s.facility_id = b.facility_id AND s.is_default;
UPDATE hospital.hospital_stock_moves m SET store_id = coalesce((SELECT b.store_id FROM hospital.hospital_stock_batches b WHERE b.id = m.batch_id),
       (SELECT s.id FROM hospital.hospital_stores s WHERE s.facility_id = m.facility_id AND s.is_default))
 WHERE m.store_id IS NULL;
UPDATE hospital.hospital_stock_moves m SET unit_cost = b.unit_cost FROM hospital.hospital_stock_batches b WHERE m.unit_cost IS NULL AND b.id = m.batch_id;

CREATE INDEX IF NOT EXISTS hospital_batches_store_idx ON hospital.hospital_stock_batches (store_id, drug_id, expires_on) WHERE quantity > 0;
CREATE INDEX IF NOT EXISTS hospital_moves_store_idx ON hospital.hospital_stock_moves (store_id, cdatetime DESC);

SELECT hospital.widen_check('hospital.hospital_stock_moves', 'hospital_stock_moves_kind_check', $q$'transfer_in'$q$,
    $q$CHECK (kind IN ('receive', 'dispense', 'adjust', 'return', 'expire', 'damage', 'transfer_out', 'transfer_in', 'count', 'return_supplier'))$q$);

-- ======================================================================= transfers between stores
CREATE TABLE IF NOT EXISTS hospital.hospital_stock_transfers (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    facility_id    text NOT NULL REFERENCES hospital.hospital_facilities(id),
    number         text NOT NULL,
    from_store_id  text NOT NULL REFERENCES hospital.hospital_stores(id),
    to_store_id    text NOT NULL REFERENCES hospital.hospital_stores(id),
    status         text NOT NULL DEFAULT 'requested'
                   CHECK (status IN ('requested', 'approved', 'dispatched', 'received', 'rejected', 'cancelled')),
    priority       text NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine', 'urgent')),
    note           text,
    reject_reason  text,
    requested_by   text, requested_at  timestamptz NOT NULL DEFAULT now(),
    approved_by    text, approved_at   timestamptz,
    dispatched_by  text, dispatched_at timestamptz,
    received_by    text, received_at   timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hospital_transfers_two_stores CHECK (from_store_id <> to_store_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_transfers_number_uq ON hospital.hospital_stock_transfers (bus_id, number);
CREATE INDEX IF NOT EXISTS hospital_transfers_facility_idx ON hospital.hospital_stock_transfers (facility_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_stock_transfer_lines (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    transfer_id    text NOT NULL REFERENCES hospital.hospital_stock_transfers(id) ON DELETE CASCADE,
    drug_id        text NOT NULL REFERENCES hospital.hospital_drugs(id),
    requested_qty  numeric NOT NULL CHECK (requested_qty > 0),
    approved_qty   numeric CHECK (approved_qty >= 0),
    sent_qty       numeric CHECK (sent_qty >= 0),
    received_qty   numeric CHECK (received_qty >= 0),
    batches        jsonb NOT NULL DEFAULT '[]'::jsonb,
    note           text
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_transfer_lines_uq ON hospital.hospital_stock_transfer_lines (transfer_id, drug_id);

-- ======================================================================= stock takes
CREATE TABLE IF NOT EXISTS hospital.hospital_stock_takes (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    facility_id   text NOT NULL REFERENCES hospital.hospital_facilities(id),
    store_id      text NOT NULL REFERENCES hospital.hospital_stores(id),
    number        text NOT NULL,
    status        text NOT NULL DEFAULT 'counting' CHECK (status IN ('counting', 'submitted', 'posted', 'cancelled')),
    blind         boolean NOT NULL DEFAULT true,
    category      text,
    note          text,
    started_by    text, started_at   timestamptz NOT NULL DEFAULT now(),
    submitted_by  text, submitted_at timestamptz,
    posted_by     text, posted_at    timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_takes_number_uq ON hospital.hospital_stock_takes (bus_id, number);
-- One count at a time per store.
CREATE UNIQUE INDEX IF NOT EXISTS hospital_takes_open_uq ON hospital.hospital_stock_takes (store_id) WHERE status IN ('counting', 'submitted');

CREATE TABLE IF NOT EXISTS hospital.hospital_stock_take_lines (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    take_id      text NOT NULL REFERENCES hospital.hospital_stock_takes(id) ON DELETE CASCADE,
    drug_id      text NOT NULL REFERENCES hospital.hospital_drugs(id),
    batch_id     text NOT NULL REFERENCES hospital.hospital_stock_batches(id),
    system_qty   numeric NOT NULL,
    counted_qty  numeric CHECK (counted_qty >= 0),
    unit_cost    numeric(14,4) NOT NULL DEFAULT 0,
    reason       text,
    counted_by   text,
    counted_at   timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_take_lines_uq ON hospital.hospital_stock_take_lines (take_id, batch_id);

-- ======================================================================= invoices
CREATE TABLE IF NOT EXISTS hospital.hospital_invoices (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    facility_id       text NOT NULL REFERENCES hospital.hospital_facilities(id),
    number            text,
    customer_type     text NOT NULL CHECK (customer_type IN ('payer', 'company', 'other')),
    payer_id          text REFERENCES hospital.hospital_payers(id),
    customer_name     text NOT NULL,
    customer_email    text,
    customer_phone    text,
    customer_address  text,
    customer_ref      text,
    issue_date        date,
    due_date          date,
    period_from       date,
    period_to         date,
    status            text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'part_paid', 'paid', 'void')),
    currency          text,
    subtotal          numeric(14,2) NOT NULL DEFAULT 0,
    discount          numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    tax_percent       numeric(6,3) NOT NULL DEFAULT 0 CHECK (tax_percent >= 0 AND tax_percent <= 100),
    tax               numeric(14,2) NOT NULL DEFAULT 0,
    total             numeric(14,2) NOT NULL DEFAULT 0,
    paid              numeric(14,2) NOT NULL DEFAULT 0,
    notes             text,
    terms             text,
    created_by        text,
    issued_by         text, issued_at timestamptz,
    voided_by         text, voided_at timestamptz, void_reason text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz,
    CONSTRAINT hospital_invoices_payer CHECK ((customer_type = 'payer') = (payer_id IS NOT NULL)),
    CONSTRAINT hospital_invoices_numbered CHECK (status = 'draft' OR number IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_invoices_number_uq ON hospital.hospital_invoices (bus_id, number) WHERE number IS NOT NULL;
CREATE INDEX IF NOT EXISTS hospital_invoices_facility_idx ON hospital.hospital_invoices (facility_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS hospital.hospital_invoice_lines (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id    text NOT NULL REFERENCES hospital.hospital_invoices(id) ON DELETE CASCADE,
    sort          int NOT NULL DEFAULT 0,
    description   text NOT NULL,
    quantity      numeric NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price    numeric(14,2) NOT NULL,
    amount        numeric(14,2) NOT NULL,
    charge_id     text REFERENCES hospital.hospital_charges(id),
    encounter_id  text REFERENCES hospital.hospital_encounters(id),
    patient_id    text REFERENCES hospital.hospital_patients(id),
    -- share: which part of a charge it bills -- what the payer covers, or what the patient owed.
    share         text NOT NULL DEFAULT 'none' CHECK (share IN ('none', 'payer', 'patient')),
    active        boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS hospital_invoice_lines_charge_uq ON hospital.hospital_invoice_lines (charge_id, share) WHERE charge_id IS NOT NULL AND active;
CREATE INDEX IF NOT EXISTS hospital_invoice_lines_encounter_idx ON hospital.hospital_invoice_lines (encounter_id) WHERE active;

CREATE TABLE IF NOT EXISTS hospital.hospital_invoice_payments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    invoice_id   text NOT NULL REFERENCES hospital.hospital_invoices(id),
    amount       numeric(14,2) NOT NULL CHECK (amount > 0),
    method       text NOT NULL CHECK (method IN ('bank_transfer', 'cheque', 'cash', 'mobile_money', 'card', 'online', 'offset', 'other')),
    reference    text,
    paid_on      date NOT NULL,
    note         text,
    received_by  text,
    voided_at    timestamptz, voided_by text, void_reason text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hospital_invoice_payments_idx ON hospital.hospital_invoice_payments (invoice_id);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.stores',   'app-hospital', 'Stores & Transfers', 2, 'Several stores per facility, transfers between them batch by batch, stock takes posted by someone else, stock insights'),
('hospital.invoices', 'app-hospital', 'Invoices',           1, 'Invoices to insurers, companies and others: issued, paid in parts, aged and chased')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
