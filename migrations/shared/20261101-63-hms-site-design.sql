-- HMS website design: luxury templates and everything beyond the words.
--
--   hms_sites.design   the logo, the banners that slide across the top (each with its words
--                      and button), a background picture, a gallery, the type, highlights,
--                      figures, reviews, questions, a film, more social links, and the order
--                      of the page's sections. Pictures are hms_files rows (entity 'site'),
--                      named by id.
--
-- Six more templates: noir, palace, riviera, safari, emerald, boutique.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE hms.hms_sites ADD COLUMN IF NOT EXISTS design jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE hms.hms_sites DROP CONSTRAINT IF EXISTS hms_sites_template_check;
ALTER TABLE hms.hms_sites ADD CONSTRAINT hms_sites_template_check CHECK (template IN ('classic', 'modern', 'minimal', 'bistro', 'resort',
    'noir', 'palace', 'riviera', 'safari', 'emerald', 'boutique'));

COMMIT;
