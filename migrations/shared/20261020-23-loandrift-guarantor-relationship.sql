-- LoanDrift: keep the guarantor's exact relationship to the borrower (QA F01).
-- relationship_to_borrower only holds a category (FAMILY, FRIEND, COLLEAGUE,
-- OTHER), so a BROTHER chosen at capture came back as FATHER. The exact value
-- now lives in `relationship`; the category stays for returns and reports.
-- Existing rows keep relationship NULL: the exact value was never stored.
ALTER TABLE loandrift.ld_guarantors ADD COLUMN IF NOT EXISTS relationship text;
