-- Invoicing: invoice templates.
--
-- A template is a design: fonts and colours, how the head, the parties, the lines, the totals
-- and the footer are laid out, which columns show, corner decoration, and the business's own
-- blocks (text, images such as a stamp or signature, lines, space) wherever it puts them. The
-- ready-made ones are in the app (presets); a business makes its own from any of them:
--   * inv_templates: a business's own designs (design jsonb, read by the PDF and the page alike).
--   * inv_template_assets: images used in them (PNG/JPEG, 1 MB at most).
-- inv_settings.template names the default: a preset's key, or custom:<id>. A customer can have
-- their own (inv_customers.template) and a document too (inv_invoices.template); empty: the
-- next one up.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS invoicing.inv_templates (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    name        text NOT NULL CHECK (btrim(name) <> ''),
    based_on    text NOT NULL DEFAULT '',
    design      jsonb NOT NULL,
    archived_at timestamptz,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_templates_bus_idx ON invoicing.inv_templates (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS invoicing.inv_template_assets (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    data        bytea NOT NULL,
    type        text NOT NULL CHECK (type IN ('image/png', 'image/jpeg')),
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);

-- The default used to be one of three designs; any preset key or custom:<id> now. The check
-- keeps its name (migration 05 re-runs and adds it only when that name is missing), with the
-- colour, paper and logo rules as they were.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_settings_design_ck'
                AND pg_get_constraintdef(oid) LIKE '%classic%') THEN
        ALTER TABLE invoicing.inv_settings DROP CONSTRAINT inv_settings_design_ck;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inv_settings_design_ck') THEN
        ALTER TABLE invoicing.inv_settings ADD CONSTRAINT inv_settings_design_ck CHECK (
            template ~ '^([a-z0-9-]{1,40}|custom:[0-9a-f-]{36})$'
            AND brand_color ~ '^#[0-9a-f]{6}$'
            AND paper IN ('a4', 'letter')
            AND (logo IS NULL OR (octet_length(logo) <= 512000 AND logo_type IN ('image/png', 'image/jpeg', 'image/webp'))));
    END IF;
END $$;

-- Only while it is a table (a view of Core Platform's customers since 20261019-30).
DO $guard$
BEGIN
    IF (SELECT relkind FROM pg_class WHERE oid = to_regclass('invoicing.inv_customers')) = 'r' THEN
        ALTER TABLE invoicing.inv_customers ADD COLUMN IF NOT EXISTS template text NOT NULL DEFAULT '';
    END IF;
END $guard$;
ALTER TABLE invoicing.inv_invoices ADD COLUMN IF NOT EXISTS template text NOT NULL DEFAULT '';

COMMIT;
