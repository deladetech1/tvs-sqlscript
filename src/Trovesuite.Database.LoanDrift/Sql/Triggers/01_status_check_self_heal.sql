-- Self-heal status CHECK on existing deployments. CREATE TABLE IF NOT EXISTS skips
-- the table block when ld_loan_details already exists, so adding statuses to the
-- inline CHECK above has no effect on a deployed DB. This rebuilds the constraint.
ALTER TABLE loandrift.ld_loan_details DROP CONSTRAINT IF EXISTS ld_loan_details_status_check;
ALTER TABLE loandrift.ld_loan_details ADD CONSTRAINT ld_loan_details_status_check
    CHECK (status IN ('REGISTERED', 'CAPTURED', 'APPROVED', 'REJECTED', 'DISBURSED',
                      'CLOSED', 'DEFAULTED', 'WRITTEN_OFF', 'ACTIVE', 'COMPLETED'));
