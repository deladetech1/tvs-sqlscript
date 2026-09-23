-- A payment says which late charge it cleared.
--
-- Every other part of an instalment payment already leaves a row in
-- msg_installment_allocations saying where that part of the money went: the
-- deposit, each instalment, any overpayment. Money that cleared a late charge
-- left no such row. It updated the penalty and told the till, and that was all.
--
-- That gap only showed itself when a payment had to be given back: a refund
-- reads the allocations to know what to unwind, so the penalty part of a
-- payment was the one part nothing could trace, and nothing could reverse.
--
-- Two things were in the way. The allocation type had no PENALTY, and the
-- only reference column, schedule_id, is a foreign key into the schedule, so
-- it cannot hold the id of a penalty. This adds penalty_id beside it and
-- widens both checks to match.
--
-- Replayable.

BEGIN;

ALTER TABLE mystoreguard.msg_installment_allocations
    ADD COLUMN IF NOT EXISTS penalty_id TEXT;

COMMENT ON COLUMN mystoreguard.msg_installment_allocations.penalty_id IS
    'The late charge this part of the payment cleared. Set only on PENALTY allocations.';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'mystoreguard.msg_installment_allocations'::regclass
           AND conname  = 'fk_msg_installment_allocations_penalty'
    ) THEN
        ALTER TABLE mystoreguard.msg_installment_allocations
            ADD CONSTRAINT fk_msg_installment_allocations_penalty
            FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, penalty_id)
            REFERENCES mystoreguard.msg_installment_penalties
                       (tenant_id, org_id, bus_id, loc_id, id)
            ON DELETE CASCADE;
    END IF;
END $$;

-- PENALTY joins the list of things a payment can be spent on.
ALTER TABLE mystoreguard.msg_installment_allocations
    DROP CONSTRAINT IF EXISTS ck_msg_installment_allocations_allocation_type;
ALTER TABLE mystoreguard.msg_installment_allocations
    ADD CONSTRAINT ck_msg_installment_allocations_allocation_type
    CHECK (allocation_type = ANY (ARRAY[
        'INITIAL', 'SCHEDULED', 'PENALTY', 'OVERPAYMENT', 'SETTLEMENT_DISCOUNT'
    ]));

-- Each kind of allocation points at exactly the thing it paid, and at nothing
-- else: an instalment allocation names an instalment, a penalty allocation
-- names a penalty, and a deposit or overpayment names neither.
ALTER TABLE mystoreguard.msg_installment_allocations
    DROP CONSTRAINT IF EXISTS ck_msg_installment_allocations_shape;
ALTER TABLE mystoreguard.msg_installment_allocations
    ADD CONSTRAINT ck_msg_installment_allocations_shape
    CHECK (
        (allocation_type = 'SCHEDULED' AND schedule_id IS NOT NULL AND penalty_id IS NULL)
     OR (allocation_type = 'PENALTY'   AND penalty_id  IS NOT NULL AND schedule_id IS NULL)
     OR (allocation_type NOT IN ('SCHEDULED', 'PENALTY')
         AND schedule_id IS NULL AND penalty_id IS NULL)
    );

CREATE INDEX IF NOT EXISTS idx_msg_installment_allocations_penalty
    ON mystoreguard.msg_installment_allocations (tenant_id, penalty_id)
    WHERE penalty_id IS NOT NULL;

COMMIT;
