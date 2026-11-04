-- MyEduGuard: recurring payments and payment reconciliation.
--
--   sms_autopay            a family's standing instruction: the card it saved (Core Platform keeps
--                          the card; this keeps only its id and how it reads, "Visa 4081"), charged
--                          for each instalment as it falls due, up to a limit if one is set
--   sms_autopay_charges    each charge tried: the instalment, the amount, how it went
--   sms_settlement_batches what a gateway or bank says it paid out over a period, brought in from
--   sms_settlement_lines   its report, line by line, and matched against the payments recorded:
--                          matched, a different amount, or unknown -- and the payments recorded
--                          that the report lacks
--
-- Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS sms.sms_autopay (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    profile_id        text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    family_id         text NOT NULL REFERENCES sms.sms_families(id) ON DELETE CASCADE,
    student_id        text NOT NULL REFERENCES sms.sms_students(id) ON DELETE CASCADE,
    authorization_id  text NOT NULL,
    card_label        text,
    max_amount        numeric(12,2),
    status            text NOT NULL DEFAULT 'active',
    from_reference    text,
    last_charged_on   date,
    stopped_at        timestamptz,
    stopped_by        text,
    cdatetime         timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_autopay', 'sms_autopay_check', $q$'stopped'$q$, $q$CHECK (status IN ('active', 'stopped') AND (max_amount IS NULL OR max_amount > 0))$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_autopay_student_uq ON sms.sms_autopay (student_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS sms.sms_autopay_charges (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    autopay_id      text NOT NULL REFERENCES sms.sms_autopay(id) ON DELETE CASCADE,
    installment_id  text REFERENCES sms.sms_fee_installments(id) ON DELETE SET NULL,
    reference       text NOT NULL,
    amount          numeric(12,2) NOT NULL,
    status          text NOT NULL DEFAULT 'pending',
    error           text,
    tried_on        date NOT NULL DEFAULT CURRENT_DATE,
    cdatetime       timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_autopay_charges', 'sms_autopay_charges_status_check', $q$'failed'$q$, $q$CHECK (status IN ('pending', 'paid', 'failed'))$q$);
CREATE INDEX IF NOT EXISTS sms_autopay_charges_idx ON sms.sms_autopay_charges (autopay_id, tried_on DESC);

CREATE TABLE IF NOT EXISTS sms.sms_settlement_batches (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    source        text NOT NULL,
    period_from   date NOT NULL,
    period_to     date NOT NULL,
    lines         integer NOT NULL DEFAULT 0,
    gross         numeric(14,2) NOT NULL DEFAULT 0,
    fees          numeric(14,2) NOT NULL DEFAULT 0,
    net           numeric(14,2) NOT NULL DEFAULT 0,
    status        text NOT NULL DEFAULT 'open',
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    CHECK (period_to >= period_from)
);
SELECT sms.widen_check('sms.sms_settlement_batches', 'sms_settlement_batches_status_check', $q$'closed'$q$, $q$CHECK (status IN ('open', 'closed'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_settlement_lines (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    batch_id       text NOT NULL REFERENCES sms.sms_settlement_batches(id) ON DELETE CASCADE,
    txn_on         date,
    reference      text,
    payer          text,
    amount         numeric(14,2) NOT NULL,
    fee            numeric(14,2) NOT NULL DEFAULT 0,
    matched_kind   text,
    matched_id     text,
    expected       numeric(14,2),
    match_status   text NOT NULL DEFAULT 'unmatched',
    note           text,
    resolved_by    text,
    resolved_at    timestamptz
);
SELECT sms.widen_check('sms.sms_settlement_lines', 'sms_settlement_lines_check', $q$'resolved'$q$, $q$CHECK (
    match_status IN ('matched', 'amount_differs', 'unmatched', 'resolved') AND (matched_kind IS NULL OR matched_kind IN ('online', 'fee_payment')))$q$);
CREATE INDEX IF NOT EXISTS sms_settlement_lines_batch_idx ON sms.sms_settlement_lines (batch_id, match_status);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.recurring-payments',     'app-sms', 'Recurring Payments',     3, 'Saved cards charged for each instalment as it falls due'),
('sms.payment-reconciliation', 'app-sms', 'Payment Reconciliation', 2, 'Gateway and bank settlements matched against student payments')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
