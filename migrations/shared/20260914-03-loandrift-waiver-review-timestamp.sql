-- Older externally-created waiver tables can be missing this column even when
-- EF records AddLoanPenalties as applied. Reconcile the existing model safely.
-- Leave historical unknown review times NULL; the transaction feed falls back
-- to cdatetime. Do not invent approval dates for existing waivers.
ALTER TABLE loandrift.ld_penalty_waivers
    ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
