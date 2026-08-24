-- =====================================================================
-- Deposit sales become Installment sales
-- ---------------------------------------------------------------------
-- "Deposit" only ever meant "a sale you are allowed to underpay" — no plan,
-- no schedule, no due date, no interest, and no rule about which goods
-- qualify. It is being replaced by a real installment product, so the mode
-- is renamed everywhere before any of that is built on top of it.
--
-- The DATA and the CHECK constraints are handled by the EF migration
-- RenameDepositSaleModeToInstallment, which has to do the backfill itself:
-- Postgres validates every existing row when a CHECK is added, so the
-- UPDATE must sit between dropping the old constraint and adding the new
-- one. Shared SQL runs AFTER the EF migrations — too late to help there.
--
-- What is left for this file is the feature catalog, which is plain data on
-- a table shared SQL owns.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

SET search_path TO core_platform;

-- ---------------------------------------------------------------------
-- Retire the old gate key.
--
-- 20260821-02 now inserts 'sales.installment' (ADVANCE, rank 2 — same tier
-- the deposit gate was on, so nobody gains or loses the capability in this
-- rename) and no longer lists 'sales.deposit'. That INSERT ... ON CONFLICT
-- cannot remove a row it stopped mentioning, so the stale one is deleted
-- here.
--
-- Deleting rather than setting is_active = false: an inactive row reads as
-- "gated feature, currently ungated", which is not what happened. The
-- feature did not stop being gated, it stopped existing under that name.
-- Nothing references cp_app_feature_catalog by FK, so the delete is safe.
-- ---------------------------------------------------------------------
DELETE FROM core_platform.cp_app_feature_catalog
WHERE feature_key = 'sales.deposit'
  AND app_id = 'app-mystoreguard';

-- ---------------------------------------------------------------------
-- Safety net for any database whose sales predate the EF migration but
-- whose constraint somehow already allows the new value (a hand-patched
-- enterprise DB, a restored snapshot). A no-op on a healthy database: the
-- CHECK makes 'DEPOSIT' unstorable, so there is nothing left to match.
-- ---------------------------------------------------------------------
UPDATE mystoreguard.msg_sales
   SET sale_mode = 'INSTALLMENT'
 WHERE sale_mode = 'DEPOSIT';

UPDATE mystoreguard.msg_invoices
   SET sale_mode = 'INSTALLMENT'
 WHERE sale_mode = 'DEPOSIT';
