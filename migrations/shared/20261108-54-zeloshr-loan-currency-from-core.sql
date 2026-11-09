-- ZelosHR staff-loan postings take their currency from Core Platform, never a guessed 'GHS'.
--
-- The rule (owner): the only currencies an app offers are the tenant's own, set up in Core
-- Platform (Settings > General > Currencies; core_platform.cp_currencies), and the base currency
-- is Core's default. No hard-coded GHS/USD fallback in code or SQL.
--
-- zeloshr.zhr_acc_loan_figures (20261019-44) describes a staff loan for Accounting in the
-- employee's pay group currency, and fell back to 'GHS' when the group had none. It now falls
-- back to the tenant's Core default currency (the default, else the first live one, as the other
-- apps' corecur.Default), and to NULL when Core has none -- Accounting then reports the event
-- rather than booking it in a currency the company does not use. A pay group whose currency is
-- '' (ZelosHR no longer writes 'GHS' when Core has none) counts as no currency.
--
-- 20261019-44 re-runs before this file on every deploy and puts the old body back, so this edits
-- the LIVE definition in place (only the two coalesce(...) expressions are replaced) rather than
-- restating the whole function. Idempotent: run again it finds the old text gone and changes
-- nothing. A function whose text matches neither form is left alone with a WARNING.
-- Nothing is rewritten: no rows are touched, only how future events are described.

BEGIN;

DO $mig$
DECLARE
    def text;
    new_def text;
    old_text constant text := 'coalesce(v_currency, ''GHS'')';
    new_text constant text :=
        'coalesce(nullif(btrim(v_currency), ''''), (SELECT upper(btrim(c.code)) FROM core_platform.cp_currencies c'
        || ' WHERE c.tenant_id = ln.tenant_id AND c.delete_status = ''NOT_DELETED'' AND coalesce(c.is_active, true)'
        || ' ORDER BY c.is_default DESC NULLS LAST, c.cdatetime LIMIT 1))';
BEGIN
    IF to_regprocedure('zeloshr.zhr_acc_loan_figures(uuid)') IS NULL THEN
        RETURN;
    END IF;
    def := pg_get_functiondef(to_regprocedure('zeloshr.zhr_acc_loan_figures(uuid)'));
    IF position(old_text IN def) > 0 THEN
        new_def := replace(def, old_text, new_text);
        EXECUTE new_def;
    ELSIF position('core_platform.cp_currencies' IN def) = 0 THEN
        RAISE WARNING '20261108-54: zeloshr.zhr_acc_loan_figures no longer reads its currency as expected; left unchanged';
    END IF;
END
$mig$;

-- Self-check: the loan description no longer names a fixed currency.
DO $chk$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'zeloshr' AND p.proname = 'zhr_acc_loan_figures'
                  AND p.prosrc LIKE '%''GHS''%') THEN
        RAISE WARNING '20261108-54: zeloshr.zhr_acc_loan_figures still falls back to GHS';
    END IF;
END
$chk$;

COMMIT;
