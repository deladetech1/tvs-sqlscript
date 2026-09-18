-- A page key belongs to the shop, not to a list in the schema.
--
-- Pages became rows a shop creates, but eight CHECK constraints still named the
-- five the app used to ship with. So a shop could build a page, see it on the
-- storefront, and then be unable to do anything with it: a version for it was
-- refused by the database, and so was a band on it, a link to it, or a card
-- pointing at it. The page existed and could not be used, which is most of the
-- way to not having it.
--
-- What keeps a typo out is no longer a list of allowed words. It is that the
-- page has to exist: the API checks every key against this business's own pages
-- before it writes, and a key naming no page is refused there with a sentence
-- rather than here with a constraint violation.
--
-- The non-page halves of these constraints — status, layout — are kept, because
-- those really are closed sets the app owns.

-- Versions. The page half goes; status and layout stay.
ALTER TABLE mystoreguard.msg_ecommerce_versions
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_enums,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_versions_status_layout;

ALTER TABLE mystoreguard.msg_ecommerce_versions
    ADD CONSTRAINT ck_msg_ecommerce_versions_status_layout
        CHECK (status = ANY (ARRAY['DRAFT','PUBLISHED','ARCHIVED'])
               AND layout = ANY (ARRAY['GRID','CAROUSEL','HERO','LIST']));

-- Bands: the page one sits on, the page whose items fill it, and the pages its
-- two buttons lead to.
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_page,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_source,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_page,
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_home_sections_cta_secondary;

-- A carousel slide's buttons.
ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_banner_slides_cta;

-- A card inside a band.
ALTER TABLE mystoreguard.msg_ecommerce_section_cards
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_section_cards_link;

-- A link in the footer.
ALTER TABLE mystoreguard.msg_ecommerce_footer_links
    DROP CONSTRAINT IF EXISTS ck_msg_ecommerce_footer_links_link;
