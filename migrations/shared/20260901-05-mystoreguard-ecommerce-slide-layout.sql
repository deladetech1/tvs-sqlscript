-- 20260901-05-mystoreguard-ecommerce-slide-layout.sql
-- A slide decides how it uses its picture.
--
-- The hero has been through three shapes now — a full-bleed image with words
-- over it, then a 4:3 card beside the words — and each time the shape was picked
-- for the whole carousel. That was the mistake. Shops do not have one kind of
-- picture: a banner exported from Canva already carries its own headline and
-- wants nothing drawn on top of it, a 16:9 product shot wants words over it, and
-- a plain photograph wants words beside it. One setting for all three slides
-- means two of them are always wrong.
--
--   BESIDE        picture in a card next to the words        4:3
--   BEHIND        picture fills the band, words over it      wide
--   PICTURE_ONLY  the picture IS the slide, nothing on top   wide
--
-- BESIDE is the default because it is what every existing slide was drawn as,
-- so the default is the backfill.
--
-- Idempotent; safe to re-run on every deploy.


ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
    ADD COLUMN IF NOT EXISTS slide_layout text NOT NULL DEFAULT 'BESIDE';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_ecommerce_banner_slides_layout'
    ) THEN
        ALTER TABLE mystoreguard.msg_ecommerce_banner_slides
            ADD CONSTRAINT ck_msg_ecommerce_banner_slides_layout
            CHECK (slide_layout IN ('BESIDE', 'BEHIND', 'PICTURE_ONLY'));
    END IF;
END $$;

COMMENT ON COLUMN mystoreguard.msg_ecommerce_banner_slides.slide_layout IS
    'How this slide uses its picture. BESIDE puts it in a card next to the '
    'words; BEHIND fills the band with it and lays the words over; PICTURE_ONLY '
    'draws nothing on top, for a banner that already carries its own message.';
