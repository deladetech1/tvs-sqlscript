-- MyEduGuard: the website's design, and the school's campuses.
--
--   sms_website.design   the site's look beyond its template: the logo, banners that slide across
--                        the top (each with its words and button), the type, an announcement,
--                        highlights, figures, programmes, the leadership, a gallery, what
--                        families say, questions answered, a film, the order of the sections and
--                        how their cards are set out. Pictures are the school's files (entity
--                        "website"), named by id.
--   sms_website.accent   the site's colour ('' the template's own)
--   sms_campuses         the school's sites (one, or a main campus and others), with an address
--   sms_buildings        each campus's buildings and blocks: classrooms, the hall, the labs, the
--                        hostels... with their floors
--   sms_resources        rooms now sit in a building, on a floor
--   sms_hostels          and boarding houses in a building
--
-- The site lives at the school's portal label (/site/{label}); its own web address is for later.
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_website ADD COLUMN IF NOT EXISTS design jsonb NOT NULL DEFAULT '{}';
ALTER TABLE sms.sms_website ADD COLUMN IF NOT EXISTS accent text NOT NULL DEFAULT '';
SELECT sms.widen_check('sms.sms_website', 'sms_website_theme_check', $q$'playground'$q$, $q$CHECK (theme IN ('classic', 'modern', 'bold',
    'heritage', 'ivy', 'scholar', 'royal', 'crimson', 'coastal', 'savanna', 'kente', 'sunrise', 'playground', 'garden', 'stem', 'minimal',
    'nordic', 'noir', 'campus'))$q$);

CREATE TABLE IF NOT EXISTS sms.sms_campuses (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name        text NOT NULL,
    address     text,
    is_main     boolean NOT NULL DEFAULT false,
    notes       text,
    sort_order  integer NOT NULL DEFAULT 0,
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS sms_campuses_name_uq ON sms.sms_campuses (profile_id, lower(name)) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sms_campuses_main_uq ON sms.sms_campuses (profile_id) WHERE is_main AND archived_at IS NULL;

CREATE TABLE IF NOT EXISTS sms.sms_buildings (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campus_id   text NOT NULL REFERENCES sms.sms_campuses(id) ON DELETE CASCADE,
    name        text NOT NULL,
    code        text,
    kind        text NOT NULL DEFAULT 'academic',
    floors      integer NOT NULL DEFAULT 1,
    notes       text,
    sort_order  integer NOT NULL DEFAULT 0,
    archived_at timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_buildings', 'sms_buildings_check', $q$'other'$q$, $q$CHECK (
    kind IN ('academic', 'admin', 'hostel', 'hall', 'library', 'lab', 'sports', 'dining', 'staff', 'health', 'chapel', 'other') AND floors BETWEEN 1 AND 60)$q$);
CREATE UNIQUE INDEX IF NOT EXISTS sms_buildings_name_uq ON sms.sms_buildings (campus_id, lower(name)) WHERE archived_at IS NULL;

ALTER TABLE sms.sms_resources ADD COLUMN IF NOT EXISTS building_id text REFERENCES sms.sms_buildings(id) ON DELETE SET NULL;
ALTER TABLE sms.sms_resources ADD COLUMN IF NOT EXISTS floor integer;
ALTER TABLE sms.sms_hostels ADD COLUMN IF NOT EXISTS building_id text REFERENCES sms.sms_buildings(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS sms_resources_building_idx ON sms.sms_resources (building_id) WHERE building_id IS NOT NULL;

COMMIT;
