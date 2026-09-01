-- =====================================================================================
-- The storefront's online payment switch, separate from the till's
-- =====================================================================================
--
-- msg_online_payment_settings held one switch and a list of locations: whether
-- this business takes online payment, and at which counters. The storefront then
-- had to borrow it, and borrowing was wrong in both directions.
--
-- A counter is in a place, so asking "may this location take card payments" is
-- the right question for a till. A shopper is not in a place, so the same
-- question asked of them made their ability to pay depend on which branch they
-- happened to buy from. And a shop may perfectly well want one without the
-- other: cards at the counter but not online while they trial the storefront,
-- or online only, with the tills taking cash as they always have.
--
-- So the storefront gets its own switch, and it is business-wide by nature —
-- there is no location to scope it to.
--
-- Existing rows are backfilled from the till's switch rather than defaulting to
-- off. A shop that already had online payment on, and a storefront already
-- taking payments through it, should not have that stop because the settings
-- grew a second field. New businesses start off, because a payment option is
-- never offered by accident.
-- =====================================================================================

ALTER TABLE mystoreguard.msg_online_payment_settings
    ADD COLUMN IF NOT EXISTS storefront_is_enabled boolean NOT NULL DEFAULT false;

-- Idempotent, and it must be: this folder is replayed on every deploy. The
-- stamp below is what makes the backfill run once — without it, a shop that
-- later switches the storefront off would have it switched back on by the next
-- deployment.
ALTER TABLE mystoreguard.msg_online_payment_settings
    ADD COLUMN IF NOT EXISTS storefront_backfilled_at timestamptz;

UPDATE mystoreguard.msg_online_payment_settings
SET storefront_is_enabled  = is_enabled,
    storefront_backfilled_at = now()
WHERE storefront_backfilled_at IS NULL;

COMMENT ON COLUMN mystoreguard.msg_online_payment_settings.storefront_is_enabled
    IS 'Whether the ecommerce storefront may take online payment. Business-wide: '
       'a shopper is not at a location, so loc_ids does not apply to them. '
       'Independent of is_enabled, which governs the tills.';

COMMENT ON COLUMN mystoreguard.msg_online_payment_settings.storefront_backfilled_at
    IS 'When storefront_is_enabled was seeded from the till switch. Present so '
       'the backfill runs once and never re-enables a storefront a shop has '
       'since turned off — this folder replays on every deploy.';
