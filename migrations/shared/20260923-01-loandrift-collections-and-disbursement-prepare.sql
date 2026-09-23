-- Collections activity log, and a prepare step before disbursement.
--
-- Two gaps this closes:
--   1. A Collections Officer's work - calls, field visits, promises to pay and
--      what came of them - had nowhere to go. Arrears were only ever a computed
--      figure in a report, so nothing recorded that anyone had chased them.
--   2. Disbursement was a single action, so "prepares the payment" and
--      "authorises the payment" could not be different people. The money control
--      that matters in lending is exactly that split.

-- ---------------------------------------------------------------- collections

CREATE TABLE IF NOT EXISTS loandrift.ld_collection_activities (
    tenant_id        text NOT NULL,
    id               text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    loc_id           text NOT NULL,
    loan_id          text NOT NULL,
    client_id        text NOT NULL,

    activity_type    text NOT NULL,
    outcome          text,
    notes            text,

    -- A promise to pay is the one outcome that carries its own commitment, so
    -- the amount and date live on the activity rather than in free text.
    promised_amount  numeric(18,2),
    promised_date    text,
    promise_status   text NOT NULL DEFAULT 'NONE',

    -- Where the officer said they would pick it up again.
    next_action_date text,
    contacted_person text,
    contact_method   text,
    location_note    text,

    occurred_at      timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cdate            text,
    ctime            text,
    cdatetime        timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by       text,
    updated_by       text,
    deleted_by       text,
    delete_status    text NOT NULL DEFAULT 'NOT_DELETED',
    is_active        boolean NOT NULL DEFAULT true,
    description      text,

    CONSTRAINT pk_ld_collection_activities PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_collection_activities_delete_status
        CHECK (delete_status IN ('NOT_DELETED', 'DELETED', 'PENDING_DELETION')),
    CONSTRAINT ck_ld_collection_activities_type CHECK (activity_type IN (
        'CALL', 'SMS', 'EMAIL', 'FIELD_VISIT', 'LETTER', 'PROMISE_TO_PAY',
        'LEGAL_NOTICE', 'RESTRUCTURE_DISCUSSION', 'OTHER')),
    CONSTRAINT ck_ld_collection_activities_outcome CHECK (outcome IS NULL OR outcome IN (
        'REACHED', 'NO_ANSWER', 'WRONG_NUMBER', 'PROMISED_TO_PAY', 'PAID',
        'REFUSED', 'DISPUTED', 'NOT_AT_LOCATION', 'RELOCATED', 'DECEASED', 'OTHER')),
    -- KEPT: a promise only ever moves to KEPT when a repayment covers it.
    CONSTRAINT ck_ld_collection_activities_promise CHECK (promise_status IN (
        'NONE', 'PENDING', 'KEPT', 'BROKEN', 'CANCELLED')),
    CONSTRAINT ck_ld_collection_activities_promise_fields CHECK (
        activity_type <> 'PROMISE_TO_PAY'
        OR (promised_amount IS NOT NULL AND promised_amount > 0 AND promised_date IS NOT NULL)),
    CONSTRAINT fk_ld_collection_activities_loan
        FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, loan_id)
        REFERENCES loandrift.ld_loan_details(tenant_id, org_id, bus_id, loc_id, id) ON DELETE CASCADE
);

-- The worklist reads by loan, newest first; the promise board reads the open
-- promises by the date they fall due.
CREATE INDEX IF NOT EXISTS ix_ld_collection_activities_loan
    ON loandrift.ld_collection_activities (tenant_id, org_id, bus_id, loc_id, loan_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_ld_collection_activities_promises
    ON loandrift.ld_collection_activities (tenant_id, org_id, bus_id, loc_id, promise_status, promised_date)
    WHERE promise_status = 'PENDING';
CREATE INDEX IF NOT EXISTS ix_ld_collection_activities_client
    ON loandrift.ld_collection_activities (tenant_id, client_id, occurred_at DESC);

COMMENT ON TABLE loandrift.ld_collection_activities IS
    'Every contact attempt on an arrears account: calls, visits, promises to pay and their outcomes.';

-- ------------------------------------------------- disbursement prepare step

-- The row already exists for a released disbursement. These columns let one
-- person stage it and another release it, so the loan only moves to DISBURSED
-- on release.
ALTER TABLE loandrift.ld_loan_disbursements
    ADD COLUMN IF NOT EXISTS prepare_status text NOT NULL DEFAULT 'RELEASED',
    ADD COLUMN IF NOT EXISTS prepared_by text,
    ADD COLUMN IF NOT EXISTS prepared_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS prepare_note text,
    ADD COLUMN IF NOT EXISTS released_at timestamp with time zone;

-- Existing rows were disbursed under the single-action flow, so they are
-- already released - the default above keeps them that way.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ld_loan_disbursements_prepare_status') THEN
        ALTER TABLE loandrift.ld_loan_disbursements
            ADD CONSTRAINT ck_ld_loan_disbursements_prepare_status
            CHECK (prepare_status IN ('PREPARED', 'RELEASED', 'CANCELLED'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_ld_loan_disbursements_prepare_status
    ON loandrift.ld_loan_disbursements (tenant_id, org_id, bus_id, loc_id, prepare_status);

COMMENT ON COLUMN loandrift.ld_loan_disbursements.prepare_status IS
    'PREPARED once staged for authorisation, RELEASED once the money is authorised out.';
COMMENT ON COLUMN loandrift.ld_loan_disbursements.prepared_by IS
    'Who staged it. Whoever releases must be someone else.';
