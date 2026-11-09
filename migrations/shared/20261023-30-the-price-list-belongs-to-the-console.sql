-- =====================================================================
-- The price list belongs to the Deladetech console, with a history
-- ---------------------------------------------------------------------
-- Until now two things wrote list prices and the later one always won:
--
--   * the console (Billing > Price list), which updates
--     cp_app_tier_configs.price / .rate in every database it can reach, and
--   * the CorePlatform seed (04_others.sql), which upserted the same rows
--     with ON CONFLICT DO UPDATE SET price, rate on EVERY tvs-sqlscript
--     deploy -- and the bundle migration (20261022-76) did the same for
--     cp_bundle_tier_configs.
--
-- So a console change reported success and the next deploy silently put
-- the old price back, and bills followed the seed. From this release the
-- seed and 20261022-76 only CREATE rows that do not exist; an existing
-- row's price, rate and max_login_users are the console's.
--
-- WHAT THIS FILE DOES
--
-- 1. core_platform.cp_price_list_changes: one row per list-price change,
--    in the database whose price changed (every database has its own copy
--    of the price list -- the pool and each silo -- so each keeps its own
--    history beside the rows it explains). The console writes a row in the
--    same transaction as every price/rate change it makes. changed_by is
--    plain text (an operator's email, or 'migration:<file>'), deliberately
--    NOT a foreign key to cp_users: the person changing a list price is
--    one of us, not a user of any tenant.
--
-- 2. The owner's 2026-10-22 decision (business apps per business, the
--    Finance bundle 40/80/150) applied ONCE per database, recorded under
--    decision_key '2026-10-22-business-apps'. A database that already has
--    those prices (dev) records them unchanged; a database that does not
--    have them yet (prod, before this reaches it) gets them -- which is
--    what the old seed upsert would have done on its next deploy, and what
--    the insert-only seed no longer will. Once recorded, a re-run (every
--    deploy) does nothing, so a later console change is never reverted.
--
-- HOW A FUTURE PRICE DECISION IS APPLIED
--
-- In the console, Billing > Price list (owner only). It writes every
-- database it can reach, records each change here with who and why, and
-- names any database it could not reach. Not in the seed, and not in a
-- migration -- a migration that writes prices is a second source again.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_price_list_changes (
    id                  text PRIMARY KEY
                        DEFAULT ('plc_' || replace(gen_random_uuid()::text, '-', '')),
    -- APP_TIER: cp_app_tier_configs.  BUNDLE_TIER: cp_bundle_tier_configs.
    -- APP_METER: cp_app_tier_meter_prices (meter_key).  APP_VOLUME:
    -- cp_apps.volume_threshold/volume_discount (config_id = app id). Both
    -- since shared/20261026-11; the CHECK below lists them because this file
    -- owns it and re-runs before that one on every deploy.
    kind                text NOT NULL,
    config_id           text NOT NULL,
    app_id              text,
    bundle_id           text,
    subscription_id     text NOT NULL,
    old_price           numeric(12,2),
    new_price           numeric(12,2),
    old_rate            numeric(12,4),
    new_rate            numeric(12,4),
    old_max_login_users integer,
    new_max_login_users integer,
    reason              text,
    changed_by          text NOT NULL,
    -- CONSOLE or MIGRATION.
    source              text NOT NULL,
    -- Groups the rows of one decision; also what makes a one-off migration
    -- step run once.
    decision_key        text,
    changed_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE core_platform.cp_price_list_changes
    DROP CONSTRAINT IF EXISTS ck_cp_price_list_changes_kind;
ALTER TABLE core_platform.cp_price_list_changes
    ADD CONSTRAINT ck_cp_price_list_changes_kind CHECK (kind IN ('APP_TIER', 'BUNDLE_TIER', 'APP_METER', 'APP_VOLUME'));
ALTER TABLE core_platform.cp_price_list_changes
    DROP CONSTRAINT IF EXISTS ck_cp_price_list_changes_source;
ALTER TABLE core_platform.cp_price_list_changes
    ADD CONSTRAINT ck_cp_price_list_changes_source CHECK (source IN ('CONSOLE', 'MIGRATION'));

CREATE INDEX IF NOT EXISTS ix_cp_price_list_changes_config
    ON core_platform.cp_price_list_changes (kind, config_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS ix_cp_price_list_changes_decision
    ON core_platform.cp_price_list_changes (decision_key);

COMMENT ON TABLE core_platform.cp_price_list_changes IS
    'Every change to a list price (cp_app_tier_configs / cp_bundle_tier_configs) in THIS database: old and new price, rate and seat cap, who (text, not a cp_users FK) and why. Written by the Deladetech console in the same transaction as the change. The console is the only writer of list prices after a row is first created (shared/20261023-30).';

-- --------------------------------------------- the 2026-10-22 decision, once
DO $$
DECLARE
    applied int := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM core_platform.cp_price_list_changes
                WHERE decision_key = '2026-10-22-business-apps') THEN
        RAISE NOTICE '20261023-30: the 2026-10-22 prices were applied here already; the console owns them now';
        RETURN;
    END IF;

    CREATE TEMP TABLE _plc_apps (id text PRIMARY KEY, price numeric, max_users integer)
        ON COMMIT DROP;
    INSERT INTO _plc_apps VALUES
        ('tier-cfg-crm-basic',  45.00,  3), ('tier-cfg-crm-advance', 120.00, 10), ('tier-cfg-crm-premium', 250.00, 25),
        ('tier-cfg-prj-basic',  25.00,  5), ('tier-cfg-prj-advance',  60.00, 15), ('tier-cfg-prj-premium', 120.00, 40),
        ('tier-cfg-inv-basic',  10.00,  3), ('tier-cfg-inv-advance',  20.00, 10), ('tier-cfg-inv-premium',  35.00, 25),
        ('tier-cfg-exp-basic',  15.00, 10), ('tier-cfg-exp-advance',  30.00, 25), ('tier-cfg-exp-premium',  60.00, 60),
        ('tier-cfg-acc-basic',  25.00,  2), ('tier-cfg-acc-advance',  50.00,  5), ('tier-cfg-acc-premium',  90.00, 15);

    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, app_id, subscription_id, old_price, new_price, old_rate, new_rate,
         old_max_login_users, new_max_login_users, reason, changed_by, source, decision_key)
    SELECT 'APP_TIER', c.id, c.app_id, c.subscription_id, c.price, v.price, c.rate, c.rate,
           c.max_login_users, v.max_users,
           'Owner decision 2026-10-22: business apps priced per business',
           'migration:20261023-30', 'MIGRATION', '2026-10-22-business-apps'
      FROM core_platform.cp_app_tier_configs c
      JOIN _plc_apps v ON v.id = c.id;

    UPDATE core_platform.cp_app_tier_configs c
       SET price = v.price, max_login_users = v.max_users
      FROM _plc_apps v
     WHERE v.id = c.id
       AND (c.price, c.max_login_users) IS DISTINCT FROM (v.price, v.max_users);
    GET DIAGNOSTICS applied = ROW_COUNT;

    -- The Finance bundle (20261022-76 runs first, so the table exists).
    INSERT INTO core_platform.cp_price_list_changes
        (kind, config_id, bundle_id, subscription_id, old_price, new_price, old_rate, new_rate,
         reason, changed_by, source, decision_key)
    SELECT 'BUNDLE_TIER', c.id, c.bundle_id, c.subscription_id, c.price, v.price, c.rate, c.rate,
           'Owner decision 2026-10-22: Finance bundle',
           'migration:20261023-30', 'MIGRATION', '2026-10-22-business-apps'
      FROM core_platform.cp_bundle_tier_configs c
      JOIN (VALUES ('bundle-cfg-finance-basic', 40.00::numeric),
                   ('bundle-cfg-finance-advance', 80.00::numeric),
                   ('bundle-cfg-finance-premium', 150.00::numeric)) AS v(id, price)
        ON v.id = c.id;

    UPDATE core_platform.cp_bundle_tier_configs c
       SET price = v.price, updated_at = now()
      FROM (VALUES ('bundle-cfg-finance-basic', 40.00::numeric),
                   ('bundle-cfg-finance-advance', 80.00::numeric),
                   ('bundle-cfg-finance-premium', 150.00::numeric)) AS v(id, price)
     WHERE v.id = c.id AND c.price IS DISTINCT FROM v.price;

    RAISE NOTICE '20261023-30: recorded the 2026-10-22 prices (% app tier row(s) changed here)', applied;
END $$;

-- ----------------------------------------------------------- invariants
DO $$
DECLARE
    wrong text;
BEGIN
    -- Who changed a list price is one of us, never a tenant user: no FK may
    -- appear on changed_by (history-columns-are-user-fks).
    SELECT string_agg(conname, ', ') INTO wrong
      FROM pg_constraint
     WHERE conrelid = 'core_platform.cp_price_list_changes'::regclass
       AND contype = 'f';
    IF wrong IS NOT NULL THEN
        RAISE EXCEPTION 'cp_price_list_changes must carry no foreign key: %', wrong;
    END IF;
END $$;

COMMIT;
