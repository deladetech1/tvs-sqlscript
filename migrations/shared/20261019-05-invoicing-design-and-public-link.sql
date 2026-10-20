-- Invoicing Release 1, part three: what an invoice looks like, and the link a customer opens.
--
-- The business as its invoices show it (inv_settings.business_*): name, address, contacts.
-- Until saved here they read from the business's details in core-platform. The logo is kept
-- in the row (logo, logo_type): a few hundred kilobytes at most, PNG, JPEG or WebP -- never
-- SVG, which can carry script.
--
-- The design: one of the templates, the brand colour, the paper size, and the notes, terms and
-- footer a new invoice starts with.
--
-- The public link (inv_invoices.public_token): 48 hex characters, made when an invoice is
-- issued (or asked for), and the only key to the customer's page -- no sign-in. Making a new
-- one ends the old. Opening it counts a view; the first is viewed_at.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE invoicing.inv_settings
    ADD COLUMN IF NOT EXISTS business_name     text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS business_address  text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS business_country  text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS business_email    text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS business_phone    text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS business_website  text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS logo              bytea,
    ADD COLUMN IF NOT EXISTS logo_type         text,
    ADD COLUMN IF NOT EXISTS template          text NOT NULL DEFAULT 'classic',
    ADD COLUMN IF NOT EXISTS brand_color       text NOT NULL DEFAULT '#e11d48',
    ADD COLUMN IF NOT EXISTS paper             text NOT NULL DEFAULT 'a4',
    ADD COLUMN IF NOT EXISTS default_notes     text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS default_terms     text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS default_footer    text NOT NULL DEFAULT '';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_settings_design_ck') THEN
        ALTER TABLE invoicing.inv_settings ADD CONSTRAINT inv_settings_design_ck CHECK (
            template IN ('classic', 'modern', 'compact')
            AND brand_color ~ '^#[0-9a-f]{6}$'
            AND paper IN ('a4', 'letter')
            AND (logo IS NULL OR (octet_length(logo) <= 512000 AND logo_type IN ('image/png', 'image/jpeg', 'image/webp'))));
    END IF;
END $$;

ALTER TABLE invoicing.inv_invoices
    ADD COLUMN IF NOT EXISTS public_token    text,
    ADD COLUMN IF NOT EXISTS view_count      integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_viewed_at  timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS inv_invoices_public_token_uq ON invoicing.inv_invoices (public_token) WHERE public_token IS NOT NULL;

COMMIT;
