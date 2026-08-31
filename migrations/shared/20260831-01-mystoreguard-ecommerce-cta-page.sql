-- 20260831-01-mystoreguard-ecommerce-cta-page.sql
-- Where a home-page band's "browse more" link goes, as a page rather than a path.
--
-- cta_href asked whoever fills in the band for a URL path. That is a question a
-- shop owner has no way to answer: they do not know the storefront's routes, so
-- "/mk" for the Market page is not user error, it is a bad field — and it fails
-- silently, as a 404 nobody sees until a shopper clicks it.
--
-- The destination is now one of the storefront's own pages, held as the same
-- enum the rest of the module uses. MyStoreGuard says WHICH PAGE; the storefront
-- decides what URL that page has. Neither side has to know the other's business,
-- and there is nothing left to mistype.
--
-- cta_href is kept, not dropped: it is the only place an external destination
-- could live (a campaign, a landing page off-site), and existing rows may hold
-- one. Nothing writes it any more — the admin no longer offers the field — and
-- the storefront should prefer cta_page_key, treating a leftover href as a hint
-- to be ignored unless it recognises it.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    ADD COLUMN IF NOT EXISTS cta_page_key text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_home_sections_cta_page'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_cta_page
            CHECK (cta_page_key IS NULL
                   OR cta_page_key IN ('BIDDING', 'PRE_USED', 'MARKET'));
    END IF;
END $$;

COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.cta_page_key IS
    'Which storefront page the band''s link goes to. NULL means the band''s own '
    'source page, so the ordinary case needs no choice at all. The link is shown '
    'only when cta_label is set — that, not this, is what says "no link".';

COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.cta_href IS
    'DEPRECATED 20260831 in favour of cta_page_key. Retained for an external '
    'destination and for rows written before the change; the admin no longer '
    'offers it. A storefront should prefer cta_page_key and ignore a path here '
    'that it does not recognise, rather than sending a shopper to a 404.';

-- Bands whose link already pointed at their own source page lose nothing by
-- being expressed the new way, and a path that was only ever the default is one
-- less thing left lying around to be trusted later. Anything else — a typo, an
-- external URL — is left exactly as it is for a person to look at.
UPDATE mystoreguard.msg_ecommerce_home_sections
SET cta_href = NULL
WHERE deleted_by IS NULL
  AND source_page_key IS NOT NULL
  AND cta_href IS NOT NULL
  AND lower(trim(both '/' from cta_href)) IN (
        lower(source_page_key),
        lower(replace(source_page_key, '_', '-')),
        lower(replace(source_page_key, '_', ''))
  );
