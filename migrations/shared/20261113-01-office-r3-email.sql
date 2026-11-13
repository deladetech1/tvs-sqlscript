-- Office R3: email (sharing, invites, requests, comments) and the fourth editor, PDF.
--
--   of_outbox              email Office has to send; written in the change's own transaction and
--                          sent later by the job (5 tries, then dead). Unique per tenant on
--                          dedupe_key, so a retried save never sends twice
--   of_notification_prefs  each person's email settings (no row reads as: everything on, instant)
--   of_guests              an outside person invited to ONE file (R3: viewer; commenter is R3b)
--   of_guest_codes         the 6-digit sign-in codes of a guest, stored only as a hash
--   of_access_requests     "Request access": one open request per person and file
--   of_comments            comments and replies, anchored by the editor (anchor jsonb), stored by
--                          Office and not in the file; seq orders them (never cdatetime)
--   of_comment_mentions    who a comment @mentions
--
-- Changes to R1/R2 tables: of_settings gains the guest switches (off by default) and its
-- enabled_editors may include 'pdf' (the default stays docs, sheets, slides); a share may be a
-- commenter. The stored formats (the ext CHECKs) admit 'pdf': that list lives in ONE place, the
-- marked block at the end of 20261110-02, which rebuilds both CHECKs on every deploy; this file
-- only asserts that 'pdf' is admitted (invariant 4).
--
-- Permissions office|comments|create||any and office|documents|export||any go to the roles that
-- hold office|documents|update (Office Editor; Office Admin is allowed by BEING the role and holds
-- no office rows). Features office.comments (BASIC), office.guests (ADVANCE), office.pdf (BASIC).
--
-- Every row carries tenant_id and bus_id; ids are text uuids. A file's guests, codes, requests,
-- comments and mentions go with it (ON DELETE CASCADE) when it is purged; outbox rows do not (they
-- are the record of what was sent and carry no FK).
-- No grants: the app group's default privileges cover new tables (01-database.md §8).
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R3-email.md §2-§7b, §9. Idempotent; safe
-- to re-run.

BEGIN;

-- ============================================================================ outbox
CREATE TABLE IF NOT EXISTS office.of_outbox (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    seq              bigint GENERATED ALWAYS AS IDENTITY,
    kind             text NOT NULL
                     CONSTRAINT of_outbox_kind_check CHECK (kind <> ''),
    to_email         text NOT NULL
                     CONSTRAINT of_outbox_to_email_check CHECK (position('@' IN to_email) > 1),
    to_name          text NOT NULL DEFAULT '',
    to_user_id       text,
    subject          text NOT NULL,
    text_body        text NOT NULL,
    html_body        text NOT NULL,
    reply_to         text,
    attachment_key   text,
    attachment_name  text,
    document_id      text,
    dedupe_key       text NOT NULL
                     CONSTRAINT of_outbox_dedupe_key_check CHECK (dedupe_key <> ''),
    status           text NOT NULL DEFAULT 'pending'
                     CONSTRAINT of_outbox_status_check CHECK (status IN ('pending', 'held', 'sent', 'dead', 'skipped')),
    attempts         int NOT NULL DEFAULT 0
                     CONSTRAINT of_outbox_attempts_check CHECK (attempts >= 0),
    next_at          timestamptz NOT NULL DEFAULT now(),
    last_error       text,
    sent_at          timestamptz,
    reference        text,
    initiated_by     text NOT NULL,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_outbox_dedupe_uq UNIQUE (tenant_id, dedupe_key),
    CONSTRAINT of_outbox_attachment_check CHECK ((attachment_key IS NULL) = (attachment_name IS NULL))
);
-- The job: what is due.
CREATE INDEX IF NOT EXISTS of_outbox_status_next_idx
    ON office.of_outbox (status, next_at);
-- The digest: held rows per person.
CREATE INDEX IF NOT EXISTS of_outbox_held_user_idx
    ON office.of_outbox (tenant_id, bus_id, to_user_id, seq) WHERE status = 'held';

-- ============================================================== notification prefs
CREATE TABLE IF NOT EXISTS office.of_notification_prefs (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    user_id      text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    shares       boolean NOT NULL DEFAULT true,
    mentions     boolean NOT NULL DEFAULT true,
    replies      boolean NOT NULL DEFAULT true,
    requests     boolean NOT NULL DEFAULT true,
    mode         text NOT NULL DEFAULT 'instant'
                 CONSTRAINT of_notification_prefs_mode_check CHECK (mode IN ('instant', 'digest', 'off')),
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_notification_prefs_pkey PRIMARY KEY (tenant_id, bus_id, user_id)
);

-- ============================================================================ guests
CREATE TABLE IF NOT EXISTS office.of_guests (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    seq           bigint GENERATED ALWAYS AS IDENTITY,
    document_id   text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    email         text NOT NULL
                  CONSTRAINT of_guests_email_check CHECK (email = lower(email) AND position('@' IN email) > 1),
    role          text NOT NULL DEFAULT 'viewer'
                  CONSTRAINT of_guests_role_check CHECK (role IN ('viewer', 'commenter')),
    invited_by    text NOT NULL,
    expires_at    timestamptz NOT NULL,
    revoked_at    timestamptz,
    last_seen_at  timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
-- One live invite per address and file.
CREATE UNIQUE INDEX IF NOT EXISTS of_guests_live_uq
    ON office.of_guests (document_id, email) WHERE revoked_at IS NULL;
-- Admin › Sharing (every live guest) and the per-business daily invite limit.
CREATE INDEX IF NOT EXISTS of_guests_business_idx
    ON office.of_guests (tenant_id, bus_id, seq DESC);

CREATE TABLE IF NOT EXISTS office.of_guest_codes (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    seq         bigint GENERATED ALWAYS AS IDENTITY,
    guest_id    text NOT NULL REFERENCES office.of_guests (id) ON DELETE CASCADE,
    code_hash   text NOT NULL,
    expires_at  timestamptz NOT NULL,
    attempts    int NOT NULL DEFAULT 0
                CONSTRAINT of_guest_codes_attempts_check CHECK (attempts >= 0),
    used_at     timestamptz,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
-- The newest code of a guest, and the per-email hourly limit.
CREATE INDEX IF NOT EXISTS of_guest_codes_guest_idx
    ON office.of_guest_codes (guest_id, seq DESC);

-- =================================================================== access requests
CREATE TABLE IF NOT EXISTS office.of_access_requests (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    document_id  text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    user_id      text NOT NULL,
    role         text NOT NULL
                 CONSTRAINT of_access_requests_role_check CHECK (role IN ('viewer', 'commenter', 'editor')),
    message      text,
    status       text NOT NULL DEFAULT 'open'
                 CONSTRAINT of_access_requests_status_check CHECK (status IN ('open', 'granted', 'declined', 'expired')),
    decided_by   text,
    decided_at   timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
-- One open request per person and file.
CREATE UNIQUE INDEX IF NOT EXISTS of_access_requests_open_uq
    ON office.of_access_requests (document_id, user_id) WHERE status = 'open';
-- The expiry sweep (open requests older than 30 days).
CREATE INDEX IF NOT EXISTS of_access_requests_open_idx
    ON office.of_access_requests (tenant_id, bus_id, cdatetime) WHERE status = 'open';

-- ========================================================================== comments
CREATE TABLE IF NOT EXISTS office.of_comments (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    document_id  text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    thread_id    text NOT NULL,  -- = id for a thread's first comment
    parent_id    text,
    author_id    text NOT NULL,
    body         text NOT NULL
                 CONSTRAINT of_comments_body_check CHECK (char_length(body) BETWEEN 1 AND 10000),
    anchor       jsonb,
    version_id   text,
    resolved_at  timestamptz,
    resolved_by  text,
    assignee_id  text,
    edited_at    timestamptz,
    deleted_at   timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS of_comments_document_seq_idx
    ON office.of_comments (document_id, seq);
-- A thread's participants (reply emails).
CREATE INDEX IF NOT EXISTS of_comments_thread_idx
    ON office.of_comments (thread_id, seq);

CREATE TABLE IF NOT EXISTS office.of_comment_mentions (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    seq         bigint GENERATED ALWAYS AS IDENTITY,
    comment_id  text NOT NULL REFERENCES office.of_comments (id) ON DELETE CASCADE,
    user_id     text NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_comment_mentions_pkey PRIMARY KEY (comment_id, user_id)
);
CREATE INDEX IF NOT EXISTS of_comment_mentions_user_idx
    ON office.of_comment_mentions (tenant_id, bus_id, user_id);

-- ==================================================== settings: guests and the PDF editor
-- Guest sharing is off until an Office Admin turns it on (Admin › Sharing). guest_domains empty
-- means any domain; guests may not download unless guest_download.
ALTER TABLE office.of_settings ADD COLUMN IF NOT EXISTS guest_sharing  boolean NOT NULL DEFAULT false;
ALTER TABLE office.of_settings ADD COLUMN IF NOT EXISTS guest_domains  text[]  NOT NULL DEFAULT '{}';
ALTER TABLE office.of_settings ADD COLUMN IF NOT EXISTS guest_download boolean NOT NULL DEFAULT false;

-- Rebuilt only when it differs from the one wanted, so a re-run costs nothing.
DO $$
DECLARE
    want constant text := 'CHECK ((enabled_editors <@ ARRAY[''docs''::text, ''sheets''::text, ''slides''::text, ''pdf''::text]))';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                    WHERE c.conrelid = 'office.of_settings'::regclass
                      AND c.conname = 'of_settings_enabled_editors_check'
                      AND pg_get_constraintdef(c.oid) = want) THEN
        ALTER TABLE office.of_settings DROP CONSTRAINT IF EXISTS of_settings_enabled_editors_check;
        ALTER TABLE office.of_settings ADD CONSTRAINT of_settings_enabled_editors_check
            CHECK (enabled_editors <@ ARRAY['docs', 'sheets', 'slides', 'pdf']::text[]);
    END IF;
END $$;
-- The default stays the three R1 editors: a business switches PDF on itself.
ALTER TABLE office.of_settings ALTER COLUMN enabled_editors SET DEFAULT '{docs,sheets,slides}';

-- ================================================================ shares: commenter
DO $$
DECLARE
    want constant text := 'CHECK ((role = ANY (ARRAY[''viewer''::text, ''commenter''::text, ''editor''::text])))';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                    WHERE c.conrelid = 'office.of_document_shares'::regclass
                      AND c.conname = 'of_document_shares_role_check'
                      AND pg_get_constraintdef(c.oid) = want) THEN
        ALTER TABLE office.of_document_shares DROP CONSTRAINT IF EXISTS of_document_shares_role_check;
        ALTER TABLE office.of_document_shares ADD CONSTRAINT of_document_shares_role_check
            CHECK (role IN ('viewer', 'commenter', 'editor'));
    END IF;
END $$;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-office-comments', 'Office Comments', 'Comments and replies on the files one can read', 'rt-subscribed-app-office')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs asserted here so this file stands on its own (export is read-only, as every app seeds it).
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('create', 'Create', false, false),
('export', 'Export', true,  false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('comments',  'rt-office-comments',  'create', 'Comment on, reply to and @mention in the files one can read'),
    ('documents', 'rt-office-documents', 'export', 'Download a file as PDF and send a copy by email')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-office-' || spec.resource_key || '-' || spec.action,
       'Office ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair, as 20261110-01 sets it (that file runs first, so it never sees these two rows on a
-- first deploy).
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'office',
       resource_key = substring(p.id FROM '^permission-office-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id IN ('permission-office-comments-create', 'permission-office-documents-export')
   AND (p.app_prefix IS DISTINCT FROM 'office' OR p.action IS NULL);

-- Granted as office|documents|update is: to Office Editor. Office Admin holds them by being the role.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-office-editor', 'comments', 'create'),
        ('role-office-editor', 'documents', 'export')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'office' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC ----------------------------------------------------------------------
('office.comments', 'app-office', 'Comments',      1, 'Comment on a file, reply, resolve and @mention people, with email notifications'),
('office.pdf',      'app-office', 'PDF Editor',    1, 'Open, annotate, fill in and organise PDF files in the browser, and download any file as PDF'),
-- ---- ADVANCE --------------------------------------------------------------------
('office.guests',   'app-office', 'Guest Sharing', 2, 'Share one file with someone outside the business: read-only, by email code, with an expiry')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- ===================================================================== invariants
DO $$
DECLARE
    tbl text;
BEGIN
    -- 1. Both new permissions have their pair and reach Office Editor.
    IF (SELECT count(*) FROM core_platform.cp_role_permissions rp
          JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
         WHERE rp.role_id = 'role-office-editor' AND p.app_prefix = 'office'
           AND (p.resource_key, p.action) IN (('comments', 'create'), ('documents', 'export'))) <> 2 THEN
        RAISE EXCEPTION 'office: Office Editor must hold office|comments|create and office|documents|export';
    END IF;
    -- 2. Office Admin still holds no rows of its own app.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-office-admin' AND permission_id LIKE 'permission-office-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-office-admin holds Office permission rows';
    END IF;
    -- 3. Commenting changes something, so the Viewer never holds it.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                 JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-office-viewer' AND p.app_prefix = 'office' AND p.resource_key = 'comments') THEN
        RAISE EXCEPTION 'role-office-viewer holds an Office comments permission';
    END IF;
    -- 4. Both stored-format CHECKs admit pdf (the list lives in 20261110-02's formats block).
    FOREACH tbl IN ARRAY ARRAY['of_documents', 'of_document_versions'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                        WHERE c.conrelid = ('office.' || tbl)::regclass AND c.conname = tbl || '_ext_check'
                          AND 'pdf' = ANY (substring(pg_get_constraintdef(c.oid) FROM '''(\{[^'']*\})''')::text[])) THEN
            RAISE EXCEPTION 'office: %.ext does not admit pdf; add it to the formats block of 20261110-02', tbl;
        END IF;
    END LOOP;
END $$;

COMMIT;
