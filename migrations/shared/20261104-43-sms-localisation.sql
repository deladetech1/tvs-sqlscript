-- MyEduGuard: one product for every country.
--
--   sms_profiles.terminology   the words the school uses for its year groups, classes, terms,
--                              subjects, students and teachers (Form, Stream, Semester, Course,
--                              Pupil, Tutor...), shown everywhere in place of the defaults
--   sms_profiles.country_pack  the country pack the school applied at setup (grading scales,
--                              holidays, words, exam boards and data law)
--   sms_user_settings          each person's own language for the screens (English, French,
--                              Arabic -- right to left -- Portuguese, Spanish, Swahili)
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS terminology jsonb NOT NULL DEFAULT '{}';
ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS country_pack text;

CREATE TABLE IF NOT EXISTS sms.sms_user_settings (
    tenant_id   text NOT NULL,
    user_id     text NOT NULL,
    language    text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, user_id)
);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.multi-language',  'app-sms', 'Multi Language Interface',   1, 'The screens in English, French, Arabic (right to left), Portuguese, Spanish and Swahili'),
('sms.terminology',     'app-sms', 'Flexible Naming',            1, 'Grade, Year, Form, Class, Term and Semester renamed to match local usage'),
('sms.country-packs',   'app-sms', 'Country Configuration Packs', 2, 'Grading scales, holidays, words, exam boards and data protection law per country')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
