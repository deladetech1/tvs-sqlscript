-- =====================================================
-- LOAN REFERENCE — SYSTEM GENERATED AND IMMUTABLE
-- =====================================================
-- The reference is assigned by the ld_loan_details.loan_reference column default
-- (LN-YYYYMMDD-NNNNNN off loandrift.ld_loan_reference_seq). It is the primary
-- business identifier for a loan, so it must never change once issued and must
-- never be supplied by a caller.

CREATE SEQUENCE IF NOT EXISTS loandrift.ld_loan_reference_seq AS bigint START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE FUNCTION loandrift.ld_enforce_loan_reference()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Ignore anything a caller passed in; the sequence is the only source.
        IF NEW.loan_reference IS NULL OR NEW.loan_reference = '' THEN
            NEW.loan_reference := 'LN-' || to_char(now(), 'YYYYMMDD') || '-'
                || lpad(nextval('loandrift.ld_loan_reference_seq')::text, 6, '0');
        END IF;
        RETURN NEW;
    END IF;

    -- UPDATE: the reference is immutable.
    IF NEW.loan_reference IS DISTINCT FROM OLD.loan_reference THEN
        RAISE EXCEPTION 'loan_reference is immutable (loan %, % -> %)',
            OLD.id, OLD.loan_reference, NEW.loan_reference
            USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ld_loan_reference ON loandrift.ld_loan_details;
CREATE TRIGGER trg_ld_loan_reference
    BEFORE INSERT OR UPDATE ON loandrift.ld_loan_details
    FOR EACH ROW EXECUTE FUNCTION loandrift.ld_enforce_loan_reference();
