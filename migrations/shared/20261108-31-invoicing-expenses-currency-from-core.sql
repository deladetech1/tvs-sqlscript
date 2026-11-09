-- Invoicing and Expenses keep no base currency of their own. A business's currency is its default
-- currency in Core Platform (Settings > General > Currencies; core_platform.cp_currencies), read
-- live by the apps, and every other currency they offer is one of the tenant's own there.
--
-- invoicing.inv_settings.base_currency was NOT NULL DEFAULT 'USD' (20261019-02): a business that
-- saved its Invoicing settings without choosing got US dollars it never asked for. The apps no
-- longer read or write the column; the default and NOT NULL go so a new settings row is not
-- stamped 'USD'. expenses.exp_settings.base_currency was already nullable with no default; it is
-- no longer read either. Both columns stay (old rows keep what they say, nothing is rewritten).
--
-- Idempotent; safe to re-run on every deploy (DROP DEFAULT / DROP NOT NULL are no-ops when done).

BEGIN;

ALTER TABLE IF EXISTS invoicing.inv_settings ALTER COLUMN base_currency DROP DEFAULT;
ALTER TABLE IF EXISTS invoicing.inv_settings ALTER COLUMN base_currency DROP NOT NULL;
ALTER TABLE IF EXISTS expenses.exp_settings  ALTER COLUMN base_currency DROP DEFAULT;

DO $$
BEGIN
    IF to_regclass('invoicing.inv_settings') IS NOT NULL THEN
        COMMENT ON COLUMN invoicing.inv_settings.base_currency IS
            'No longer used: the business''s currency is its default in core_platform.cp_currencies, read live.';
    END IF;
END $$;

DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(table_schema || '.' || table_name || '.' || column_name, ', ') INTO bad
      FROM information_schema.columns
     WHERE table_schema IN ('invoicing', 'expenses', 'projects')
       AND column_name ~ 'currency'
       AND column_default ~ '''[A-Z]{3}''';
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'an Invoicing, Expenses or Projects currency column still defaults to a fixed currency: %', bad;
    END IF;
END $$;

COMMIT;
