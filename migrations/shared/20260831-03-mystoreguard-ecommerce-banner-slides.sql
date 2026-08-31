-- 20260831-03-mystoreguard-ecommerce-banner-slides.sql
-- The hero is a carousel, so its content is rows rather than columns.
--
-- 20260831-02 modelled it as one banner: eyebrow, picture, countdown and two
-- links, all as columns on the section. That is a poster. A carousel is several
-- of those in sequence, and "several" is a table — the alternative is
-- image_2, image_3, and a ceiling nobody chose.
--
-- The section stays the band: it keeps its position on the page, its visibility
-- and now how fast it turns. What it SHOWS moves into slides beneath it.
--
-- The columns from 02 are kept and deprecated rather than dropped: dropping
-- breaks any API pod still running mid-deploy, and their content is carried into
-- a first slide below so nothing anybody typed is lost.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. How the carousel behaves. Only ever read for a HERO.
-- =====================================================================================
ALTER TABLE mystoreguard.msg_ecommerce_home_sections
    -- Seconds between slides. 0 means it does not turn on its own — a shop with
    -- one slide, or one that would rather shoppers moved it themselves.
    ADD COLUMN IF NOT EXISTS autoplay_seconds integer NOT NULL DEFAULT 6;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_home_sections_autoplay'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_home_sections
            ADD CONSTRAINT ck_msg_ecommerce_home_sections_autoplay
            -- 0 to 60. Faster than about three seconds is unreadable, and the
            -- upper bound only exists so a typo cannot park a carousel for an hour.
            CHECK (autoplay_seconds >= 0 AND autoplay_seconds <= 60);
    END IF;
END $$;


-- =====================================================================================
-- 2. The slides.
--
--    One row per panel. The fields are the ones 02 put on the section, because
--    a slide IS what that banner was — this migration is about there being more
--    than one of them, not about them being different.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_banner_slides (
    id                      text        PRIMARY KEY,
    tenant_id               text        NOT NULL,
    org_id                  text        NOT NULL,
    bus_id                  text        NOT NULL,
    section_id              text        NOT NULL
        REFERENCES mystoreguard.msg_ecommerce_home_sections (id) ON DELETE CASCADE,

    -- The order they turn in.
    sort_order              integer     NOT NULL DEFAULT 0,

    eyebrow                 text,
    title                   text,
    subtitle                text,

    image_document_id       text,
    image_external_url      text,

    countdown_at            timestamptz,

    cta_label               text,
    cta_page_key            text,
    cta_secondary_label     text,
    cta_secondary_page_key  text,

    -- The product this slide is about, if any. Supplies its picture and price so
    -- neither is typed and neither goes stale. No FK on purpose: a deleted
    -- product should blank the slide's product, not refuse the delete.
    featured_product_id     text,

    -- A slide can be taken out of rotation without being thrown away — which is
    -- what somebody wants when a promotion ends and might come back.
    is_visible              boolean     NOT NULL DEFAULT true,

    cdate                   date,
    ctime                   time,
    cdatetime               timestamptz NOT NULL DEFAULT now(),
    udatetime               timestamptz,
    created_by              text,
    updated_by              text,
    deleted_by              text
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_ecommerce_banner_slides_cta'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
            ADD CONSTRAINT ck_msg_ecommerce_banner_slides_cta CHECK (
                (cta_page_key IS NULL
                 OR cta_page_key IN ('BIDDING', 'PRE_USED', 'MARKET'))
                AND (cta_secondary_page_key IS NULL
                     OR cta_secondary_page_key IN ('BIDDING', 'PRE_USED', 'MARKET'))
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_banner_slides_section
    ON mystoreguard.msg_ecommerce_banner_slides (section_id, sort_order)
    WHERE deleted_by IS NULL;


-- =====================================================================================
-- 3. Carry each existing banner across as its first slide.
--
--    Only where the section actually said something — a HERO with no picture, no
--    words and no product had nothing to carry, and creating an empty slide for
--    it would put a blank panel in a carousel nobody had filled in yet.
--
--    Guarded on the section having no slides at all, so re-running never adds a
--    second copy and never disturbs slides somebody has since edited.
-- =====================================================================================
INSERT INTO mystoreguard.msg_ecommerce_banner_slides (
    id, tenant_id, org_id, bus_id, section_id, sort_order,
    eyebrow, title, subtitle, image_document_id, image_external_url,
    countdown_at, cta_label, cta_page_key,
    cta_secondary_label, cta_secondary_page_key, featured_product_id,
    is_visible, cdate, ctime, cdatetime, created_by
)
SELECT
    'ebs-migrated-' || md5(s.id),
    s.tenant_id, s.org_id, s.bus_id, s.id, 0,
    s.eyebrow, s.title, s.subtitle, s.image_document_id, s.image_external_url,
    s.countdown_at, s.cta_label, s.cta_page_key,
    s.cta_secondary_label, s.cta_secondary_page_key, s.featured_product_id,
    true, now()::date, now()::time, now(), 'migration-20260831-03'
FROM mystoreguard.msg_ecommerce_home_sections s
WHERE s.section_key = 'HERO'
  AND s.deleted_by IS NULL
  AND COALESCE(
        s.eyebrow, s.title, s.subtitle, s.image_document_id,
        s.image_external_url, s.cta_label, s.featured_product_id
      ) IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM mystoreguard.msg_ecommerce_banner_slides existing
        WHERE existing.section_id = s.id
  )
ON CONFLICT (id) DO NOTHING;


-- =====================================================================================
-- 4. Retire the section-level banner columns.
--
--    Left in place, unread. Same reasoning as msg_store_configs.is_visible_on_ecommerce
--    and cta_href before them: a column costs little, and dropping one out from
--    under a running pod costs a deploy.
-- =====================================================================================
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.eyebrow IS
    'DEPRECATED 20260831-03. A hero is a carousel; its content lives in '
    'msg_ecommerce_banner_slides. Carried into a first slide by that migration.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.image_document_id IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.image_external_url IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.countdown_at IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.cta_secondary_label IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.cta_secondary_page_key IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
COMMENT ON COLUMN mystoreguard.msg_ecommerce_home_sections.featured_product_id IS
    'DEPRECATED 20260831-03 — see msg_ecommerce_banner_slides.';
