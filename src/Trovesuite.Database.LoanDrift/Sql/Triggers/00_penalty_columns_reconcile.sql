-- =====================================================
-- SCHEMA RECONCILE — penalty & loan-reference columns
-- =====================================================
-- Runs before 02_loan_details_view.sql, which selects these columns and fails
-- with 42703 if any are absent.
--
-- Why this is needed at all: EF wraps a migration in ONE transaction. If any
-- single operation fails with "already exists" — e.g. CreateTable ld_penalties
-- on a database where the penalty tables were created outside EF — the WHOLE
-- migration rolls back, including every AddColumn in it. The runner's
-- SafeMigrateAsync then records that migration as applied, so EF will never
-- retry it: __EFMigrationsHistory says applied while the columns do not exist.
--
-- 20260706141618_AddLoanPenalties adds six columns before creating three
-- tables, so exactly those six are the ones lost to that rollback.
-- 20260731225418_AddLoanReferenceAndPenaltyPercentage is included for the same
-- reason; the view reads its columns too.
--
-- Every statement is IF NOT EXISTS, so on a healthy database this is a no-op.
-- Types and defaults are copied verbatim from the migrations, so a column
-- created here is indistinguishable from one EF would have created.

-- ---- 20260706141618_AddLoanPenalties -------------------------------------
ALTER TABLE loandrift.ld_repayments
    ADD COLUMN IF NOT EXISTS penalty_paid numeric(20,6) NOT NULL DEFAULT 0;

ALTER TABLE loandrift.ld_loan_types
    ADD COLUMN IF NOT EXISTS penalty_mode text NOT NULL DEFAULT 'NONE';

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS penalty_enabled boolean NOT NULL DEFAULT false;

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS penalty_mode text NOT NULL DEFAULT 'NONE';

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS penalty_settings_version_id text;

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS penalty_terms jsonb;

-- ---- 20260731225418_AddLoanReferenceAndPenaltyPercentage -----------------
ALTER TABLE loandrift.ld_loan_types
    ADD COLUMN IF NOT EXISTS penalty_percentage numeric(7,4);

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS penalty_percentage numeric(7,4);

-- loan_reference: the migration adds it with a bare `ADD COLUMN` inside a raw
-- Sql block, so on a database that already has the column that statement throws
-- and takes the rest of the migration down with it — the same trap again.
-- Reconcile the full end state: sequence, column, backfill, default, NOT NULL,
-- unique index. Each step is guarded, so this is a no-op on a healthy database.
CREATE SEQUENCE IF NOT EXISTS loandrift.ld_loan_reference_seq AS bigint START WITH 1 INCREMENT BY 1;

ALTER TABLE loandrift.ld_loan_details
    ADD COLUMN IF NOT EXISTS loan_reference text;

UPDATE loandrift.ld_loan_details
   SET loan_reference = 'LN-' || to_char(COALESCE(cdatetime, now()), 'YYYYMMDD') || '-'
                     || lpad(nextval('loandrift.ld_loan_reference_seq')::text, 6, '0')
 WHERE loan_reference IS NULL;

ALTER TABLE loandrift.ld_loan_details
    ALTER COLUMN loan_reference SET DEFAULT
        'LN-' || to_char(now(), 'YYYYMMDD') || '-'
              || lpad(nextval('loandrift.ld_loan_reference_seq')::text, 6, '0');

-- Only enforce NOT NULL once nothing violates it (the backfill above), so a
-- reconcile can never fail on unexpected data.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM loandrift.ld_loan_details WHERE loan_reference IS NULL) THEN
        ALTER TABLE loandrift.ld_loan_details ALTER COLUMN loan_reference SET NOT NULL;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ix_ld_loan_details_loan_reference
    ON loandrift.ld_loan_details (loan_reference);
