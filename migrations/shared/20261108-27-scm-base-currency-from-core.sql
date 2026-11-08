-- SCM takes its currency from Core Platform.
--
-- The rule (owner): the only currencies an app offers are the tenant's own, set up in Core
-- Platform (Settings > General > Currencies; core_platform.cp_currencies), and the base currency
-- is Core's default. SCM kept its own: scm.scm_settings.base_currency, defaulting to 'GHS'.
-- The SCM API no longer reads that column (it only mirrors Core's default when settings are
-- saved); this file makes the database side follow too:
--
--   1. the column loses its 'GHS' default (the column and its rows stay: nothing is rewritten);
--   2. the two books functions from 20261102-85 that read it -- scm_acc_publish_reference and
--      scm_acc_publish_shortage -- read Core's default instead: the default, else the first
--      live currency, as internal/platform/corecur.Default.
--
-- 20261102-85 re-runs before this file on every deploy and puts the old bodies back, so step 2
-- edits the LIVE definitions in place (only the one sub-select is replaced) rather than
-- restating 120 lines that would drift from that file. Idempotent: run again it finds the old
-- text gone and changes nothing. A function whose text no longer matches either form is left
-- alone with a WARNING (a deploy is not blocked over it).

BEGIN;

DO $mig$
DECLARE
    fn record;
    def text;
    new_def text;
BEGIN
    IF to_regclass('scm.scm_settings') IS NOT NULL THEN
        ALTER TABLE scm.scm_settings ALTER COLUMN base_currency DROP DEFAULT;
    END IF;

    FOR fn IN
        SELECT * FROM (VALUES
            ('scm.scm_acc_publish_reference(text,text,text,text)',
             '(SELECT base_currency FROM scm.scm_settings WHERE bus_id = p_bus AND tenant_id = p_tenant)',
             '(SELECT upper(btrim(c.code)) FROM core_platform.cp_currencies c WHERE c.tenant_id = p_tenant AND c.delete_status = ''NOT_DELETED'' AND coalesce(c.is_active, true) ORDER BY c.is_default DESC NULLS LAST, c.cdatetime LIMIT 1)'),
            ('scm.scm_acc_publish_shortage(text)',
             '(SELECT base_currency FROM scm.scm_settings WHERE bus_id = bs.bus_id)',
             '(SELECT upper(btrim(c.code)) FROM core_platform.cp_currencies c WHERE c.tenant_id = bs.tenant_id AND c.delete_status = ''NOT_DELETED'' AND coalesce(c.is_active, true) ORDER BY c.is_default DESC NULLS LAST, c.cdatetime LIMIT 1)')
        ) AS t(sig, old_text, new_text)
    LOOP
        IF to_regprocedure(fn.sig) IS NULL THEN
            CONTINUE;
        END IF;
        def := pg_get_functiondef(to_regprocedure(fn.sig));
        IF position(fn.old_text IN def) > 0 THEN
            new_def := replace(def, fn.old_text, fn.new_text);
            EXECUTE new_def;
        ELSIF position('core_platform.cp_currencies' IN def) = 0 THEN
            RAISE WARNING '20261108-27: % no longer reads scm_settings.base_currency as expected; left unchanged', fn.sig;
        END IF;
    END LOOP;
END
$mig$;

-- Self-check: neither function reads SCM's own currency any more.
DO $chk$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'scm'
                  AND p.proname IN ('scm_acc_publish_reference', 'scm_acc_publish_shortage')
                  AND p.prosrc LIKE '%SELECT base_currency FROM scm.scm_settings%') THEN
        RAISE WARNING '20261108-27: an SCM books function still reads scm_settings.base_currency';
    END IF;
END
$chk$;

COMMIT;
