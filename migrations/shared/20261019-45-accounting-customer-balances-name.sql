-- =====================================================================
-- Accounting: account 1120 is "Customer Balances", not "Customer Instalment Balances"
-- ---------------------------------------------------------------------
-- 1120 is where MyStoreGuard posts every customer balance (docs/POSTINGS.md §3): instalment balances
-- once the goods have gone, and also a cancelled walk-in sale credited back until its payments are
-- refunded. Accounting created it with the old name. Only accounts still carrying that default are
-- renamed: a name a business chose itself is left alone. Re-runs every deploy: idempotent.
-- =====================================================================
BEGIN;

DO $$
BEGIN
    IF to_regclass('accounting.acc_accounts') IS NOT NULL THEN
        UPDATE accounting.acc_accounts
           SET name = 'Customer Balances', updated_at = now()
         WHERE code = '1120' AND name = 'Customer Instalment Balances';
    END IF;
END $$;

COMMIT;
