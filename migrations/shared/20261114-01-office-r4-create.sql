-- Office R4: create (business templates and AI).
--
--   of_templates  a business's own templates (Administration › Templates): a file saved as a
--                 template or uploaded, with a title, description and category, shown in the
--                 gallery once published. The built-in templates ship in the backend and have no
--                 rows here
--   of_ai_runs    one row per AI call (outline, create, assist): who, which action, how many
--                 characters went in and came out, and how it ended. For the per-person rate limit
--                 and the admin's view; NEVER the prompt or the text
--
-- Permission office|templates|manage||any goes to no role: Office Admin is allowed by BEING the
-- role and holds no office rows (20261110-01), and the Editor and Viewer do not manage templates.
-- Features office.ai (ADVANCE) and office.business_templates (ADVANCE); the built-in templates
-- are part of BASIC and need no feature.
--
-- Every row carries tenant_id and bus_id; ids are text uuids. Neither table has an FK to
-- of_documents: a template is a copy that outlives the file it was saved from, and an AI run is
-- the record of a call and stays when its file is purged.
-- A template's ext is checked for shape only: which formats an editor stores is one list, the
-- marked block at the end of 20261110-02, and the backend holds a template to it.
-- No grants: the app group's default privileges cover new tables (01-database.md §8).
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R4-create.md §5.3, §6, §9. Idempotent;
-- safe to re-run.

BEGIN;

-- ========================================================================= templates
CREATE TABLE IF NOT EXISTS office.of_templates (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    seq            bigint GENERATED ALWAYS AS IDENTITY,
    editor         text NOT NULL
                   CONSTRAINT of_templates_editor_check CHECK (editor IN ('docs', 'sheets', 'slides', 'pdf')),
    ext            text NOT NULL
                   CONSTRAINT of_templates_ext_check CHECK (ext ~ '^[a-z0-9]{1,16}$'),
    title          text NOT NULL
                   CONSTRAINT of_templates_title_check CHECK (btrim(title) <> ''),
    description    text NOT NULL DEFAULT '',
    category       text NOT NULL
                   CONSTRAINT of_templates_category_check CHECK (btrim(category) <> ''),
    blob_key       text NOT NULL
                   CONSTRAINT of_templates_blob_key_check CHECK (blob_key <> ''),
    size_bytes     bigint NOT NULL
                   CONSTRAINT of_templates_size_check CHECK (size_bytes >= 0),
    thumbnail_key  text,  -- NULL until the converter has made one (the card shows the app glyph)
    published      boolean NOT NULL DEFAULT false,
    created_by     text NOT NULL,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    udatetime      timestamptz NOT NULL DEFAULT now()
);
-- The gallery (published, per editor, newest first) and Administration › Templates.
CREATE INDEX IF NOT EXISTS of_templates_gallery_idx
    ON office.of_templates (tenant_id, bus_id, published, editor, seq DESC);

-- =========================================================================== AI runs
CREATE TABLE IF NOT EXISTS office.of_ai_runs (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    seq           bigint GENERATED ALWAYS AS IDENTITY,
    user_id       text NOT NULL,
    action        text NOT NULL
                  CONSTRAINT of_ai_runs_action_check CHECK (action <> ''),
    kind          text,
    document_id   text,
    model         text,
    input_chars   int NOT NULL DEFAULT 0
                  CONSTRAINT of_ai_runs_input_chars_check CHECK (input_chars >= 0),
    output_chars  int NOT NULL DEFAULT 0
                  CONSTRAINT of_ai_runs_output_chars_check CHECK (output_chars >= 0),
    status        text NOT NULL
                  CONSTRAINT of_ai_runs_status_check CHECK (status IN ('ok', 'refused', 'failed')),
    error_code    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
-- The per-person rate limit (20 calls a minute): a person's newest runs.
CREATE INDEX IF NOT EXISTS of_ai_runs_user_idx
    ON office.of_ai_runs (tenant_id, bus_id, user_id, seq DESC);
-- The admin's view: a business's newest runs.
CREATE INDEX IF NOT EXISTS of_ai_runs_business_idx
    ON office.of_ai_runs (tenant_id, bus_id, seq DESC);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-office-templates', 'Office Templates', 'The business''s own templates: add, publish, rename, replace and delete', 'rt-subscribed-app-office')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- The verb asserted here so this file stands on its own (as 20261110-01 does for library|manage).
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('manage', 'Manage', false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('templates', 'rt-office-templates', 'manage', 'Manage the business''s templates: save a file as a template, upload, publish, rename, replace and delete')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-office-' || spec.resource_key || '-' || spec.action,
       'Office ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair, as 20261110-01 sets it (that file runs first, so it never sees this row on a first
-- deploy).
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'office',
       resource_key = substring(p.id FROM '^permission-office-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id IN ('permission-office-templates-manage')
   AND (p.app_prefix IS DISTINCT FROM 'office' OR p.action IS NULL);

-- No role grants: Office Admin holds office|templates|manage by being the role.

-- ========================================================== features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- ADVANCE --------------------------------------------------------------------
('office.ai',                 'app-office', 'AI Create and Edit',  2, 'Create a document, presentation or workbook from a prompt, and rewrite, summarise or translate in the editor'),
('office.business_templates', 'app-office', 'Business Templates',  2, 'Save a file as a template or upload one, and publish the business''s own templates to the gallery')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
BEGIN
    -- 1. The new permission exists with its pair.
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_permissions p
                    WHERE p.id = 'permission-office-templates-manage'
                      AND p.app_prefix = 'office' AND p.resource_key = 'templates' AND p.action = 'manage'
                      AND coalesce(p.target, '') = '' AND p.scope = 'any') THEN
        RAISE EXCEPTION 'office: office|templates|manage||any is missing or has no pair';
    END IF;
    -- 2. Only the Admin (by being the role) manages templates.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                 JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE p.app_prefix = 'office' AND p.resource_key = 'templates') THEN
        RAISE EXCEPTION 'a role holds office|templates|manage; only Office Admin may, by being the role';
    END IF;
    -- 3. Office Admin still holds no rows of its own app.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-office-admin' AND permission_id LIKE 'permission-office-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-office-admin holds Office permission rows';
    END IF;
    -- 4. Both features are ADVANCE.
    IF (SELECT count(*) FROM core_platform.cp_app_feature_catalog
         WHERE feature_key IN ('office.ai', 'office.business_templates')
           AND app_id = 'app-office' AND min_tier_rank = 2 AND is_active) <> 2 THEN
        RAISE EXCEPTION 'office: office.ai and office.business_templates must both be ADVANCE (rank 2)';
    END IF;
END $$;

COMMIT;
