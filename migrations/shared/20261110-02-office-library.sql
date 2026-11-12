-- Office R1: the one library of the suite, for every editor. R0's library (20261109-02/-04/-06)
-- with the prefix of_; one row of of_documents is a file of any editor (a document, a workbook or
-- a presentation). The editor is not stored: it follows from ext (R1-suite.md §2).
--
--   of_folders            folders, per owner; parent_id NULL is the root; soft-deleted
--   of_documents          a file: its title and ext, owner, visibility, the optimistic version
--                         (bumped on every content save and restore), the current version and its
--                         size; deleted_at puts it in the trash
--   of_document_versions  one row per stored version (blobs are immutable, one per version; a
--                         restore points a new row at an old blob). seq orders the history: the
--                         colima clock steps back, so never order by cdatetime
--   of_document_shares    explicit viewer/editor shares of one file (ADVANCE: office.sharing)
--   of_locks              the single editor's lock, one per file (TTL 120 s, heartbeat 30 s)
--   of_recent             what each user opened last
--   of_settings           one row per business: which editors are switched on (library|manage)
--
-- Every row carries tenant_id and bus_id; ids are text uuids. A file's versions, shares, lock
-- and recent rows go with it (ON DELETE CASCADE) when it is purged; a purged folder leaves what it
-- held at the root (ON DELETE SET NULL). CHECK lists are defined here, inline, except the stored
-- extensions: that list is provisional and lives in ONE marked block at the end of this file.
-- No grants: the app group's default privileges cover new tables (01-database.md §8).
-- Search uses lower(title) btree indexes: pg_trgm is not enabled anywhere in this repo's migrations.
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R1-suite.md §2-§3, on top of
-- docs/office-apps/contracts/R0.md §3-§4 and docs/docs-app/contracts/R0.md §4. Idempotent; safe
-- to re-run.

BEGIN;


-- =========================================================================== folders
CREATE TABLE IF NOT EXISTS office.of_folders (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    parent_id      text REFERENCES office.of_folders (id) ON DELETE SET NULL,
    name           text NOT NULL
                   CONSTRAINT of_folders_name_check CHECK (char_length(btrim(name)) BETWEEN 1 AND 200),
    owner_user_id  text NOT NULL,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    mdatetime      timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    CONSTRAINT of_folders_not_own_parent CHECK (parent_id IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX IF NOT EXISTS of_folders_live_name_uq
    ON office.of_folders (tenant_id, bus_id, owner_user_id, coalesce(parent_id, ''), lower(name))
 WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_folders_parent_idx
    ON office.of_folders (tenant_id, bus_id, parent_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_folders_owner_idx
    ON office.of_folders (tenant_id, bus_id, owner_user_id);

-- ========================================================================= documents
CREATE TABLE IF NOT EXISTS office.of_documents (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    folder_id           text REFERENCES office.of_folders (id) ON DELETE SET NULL,
    title               text NOT NULL
                        CONSTRAINT of_documents_title_check CHECK (char_length(btrim(title)) BETWEEN 1 AND 255),
    ext                 text NOT NULL DEFAULT 'docx',  -- CHECK: the formats block at the end
    owner_user_id       text NOT NULL,
    visibility          text NOT NULL DEFAULT 'private'
                        CONSTRAINT of_documents_visibility_check CHECK (visibility IN ('private', 'business')),
    version             int NOT NULL DEFAULT 1
                        CONSTRAINT of_documents_version_check CHECK (version >= 1),
    current_version_id  text,
    size_bytes          bigint NOT NULL DEFAULT 0
                        CONSTRAINT of_documents_size_check CHECK (size_bytes >= 0),
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    mdatetime           timestamptz NOT NULL DEFAULT now(),
    modified_by         text,
    deleted_at          timestamptz,
    deleted_by          text
);
-- Listing: a folder (or the root), by owner, by business-wide recency, and the trash.
CREATE INDEX IF NOT EXISTS of_documents_folder_idx
    ON office.of_documents (tenant_id, bus_id, folder_id, mdatetime DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_documents_owner_idx
    ON office.of_documents (tenant_id, bus_id, owner_user_id, mdatetime DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_documents_mdatetime_idx
    ON office.of_documents (tenant_id, bus_id, mdatetime DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_documents_traof_idx
    ON office.of_documents (tenant_id, bus_id, deleted_at DESC) WHERE deleted_at IS NOT NULL;
-- Search and sort by title: prefix search (lower(title) LIKE 'q%') and ordering.
CREATE INDEX IF NOT EXISTS of_documents_title_prefix_idx
    ON office.of_documents (tenant_id, bus_id, lower(title) text_pattern_ops) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS of_documents_title_sort_idx
    ON office.of_documents (tenant_id, bus_id, lower(title)) WHERE deleted_at IS NULL;

-- ========================================================================== versions
CREATE TABLE IF NOT EXISTS office.of_document_versions (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    seq              bigint GENERATED BY DEFAULT AS IDENTITY,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    document_id      text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    version_no       int NOT NULL
                     CONSTRAINT of_document_versions_version_no_check CHECK (version_no >= 1),
    blob_key         text NOT NULL,
    size_bytes       bigint NOT NULL
                     CONSTRAINT of_document_versions_size_check CHECK (size_bytes >= 0),
    sha256           text NOT NULL
                     CONSTRAINT of_document_versions_sha256_check CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    ext              text NOT NULL,  -- CHECK: the formats block at the end
    created_by       text NOT NULL,
    created_by_name  text,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    reason           text NOT NULL
                     CONSTRAINT of_document_versions_reason_check CHECK (reason IN ('upload', 'create', 'save', 'restore'))
);
CREATE UNIQUE INDEX IF NOT EXISTS of_document_versions_number_uq
    ON office.of_document_versions (document_id, version_no);
CREATE INDEX IF NOT EXISTS of_document_versions_document_seq_idx
    ON office.of_document_versions (document_id, seq DESC);
-- The quota is the sum of every stored version's bytes per business.
CREATE INDEX IF NOT EXISTS of_document_versions_business_idx
    ON office.of_document_versions (tenant_id, bus_id);
-- Blobs are shared by a restore: the sweep asks whether any row still points at one.
CREATE INDEX IF NOT EXISTS of_document_versions_blob_idx
    ON office.of_document_versions (blob_key);

-- The file's current version. Deferred, so a document and its first version may be written in
-- either order in one transaction.
ALTER TABLE office.of_documents DROP CONSTRAINT IF EXISTS of_documents_current_version_fk;
ALTER TABLE office.of_documents ADD CONSTRAINT of_documents_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES office.of_document_versions (id)
    DEFERRABLE INITIALLY DEFERRED;

-- ============================================================================ shares
CREATE TABLE IF NOT EXISTS office.of_document_shares (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    document_id  text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    user_id      text NOT NULL,
    role         text NOT NULL
                 CONSTRAINT of_document_shares_role_check CHECK (role IN ('viewer', 'editor')),
    granted_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_document_shares_pkey PRIMARY KEY (document_id, user_id)
);
-- "Shared with me".
CREATE INDEX IF NOT EXISTS of_document_shares_user_idx
    ON office.of_document_shares (tenant_id, bus_id, user_id);

-- ============================================================================= locks
CREATE TABLE IF NOT EXISTS office.of_locks (
    document_id   text PRIMARY KEY REFERENCES office.of_documents (id) ON DELETE CASCADE,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    user_id       text NOT NULL,
    user_name     text,
    session_id    text NOT NULL,
    acquired_at   timestamptz NOT NULL DEFAULT now(),
    heartbeat_at  timestamptz NOT NULL DEFAULT now(),
    expires_at    timestamptz NOT NULL
);
-- The sweep deletes expired locks.
CREATE INDEX IF NOT EXISTS of_locks_expires_idx ON office.of_locks (expires_at);
CREATE INDEX IF NOT EXISTS of_locks_business_idx ON office.of_locks (tenant_id, bus_id);

-- ============================================================================ recent
CREATE TABLE IF NOT EXISTS office.of_recent (
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    user_id      text NOT NULL,
    document_id  text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    opened_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_recent_pkey PRIMARY KEY (tenant_id, bus_id, user_id, document_id)
);
CREATE INDEX IF NOT EXISTS of_recent_user_idx
    ON office.of_recent (tenant_id, bus_id, user_id, opened_at DESC);
CREATE INDEX IF NOT EXISTS of_recent_document_idx
    ON office.of_recent (document_id);


-- ========================================================================== settings
-- Which editors a business has switched on. Every tier includes all three; this is the business's
-- own choice, changed by Office Admin (library|manage) through PUT /office/v1/settings. No row
-- reads as the default: all three on. The list may be empty. The backend refuses create, upload,
-- copy, the lock (read mode instead) and a content save for a file whose editor is off; listing,
-- reading, download, versions, trash and purge still work, so nobody loses their files.
CREATE TABLE IF NOT EXISTS office.of_settings (
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    enabled_editors  text[] NOT NULL DEFAULT '{docs,sheets,slides}'
                     CONSTRAINT of_settings_enabled_editors_check
                     CHECK (enabled_editors <@ ARRAY['docs', 'sheets', 'slides']::text[]),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    mdatetime        timestamptz NOT NULL DEFAULT now(),
    modified_by      text,
    CONSTRAINT of_settings_pkey PRIMARY KEY (tenant_id, bus_id)
);

-- =====================================================================================
-- >>> PROVISIONAL: THE STORED FORMATS. The one place Office's extension lists live. <<<
-- R1-suite.md §2: each editor owns its formats, and of_documents.ext / of_document_versions.ext
-- accept their union. The editor slices may trim a list: edit only the ARRAYs on the marked lines.
-- No ext may belong to two editors (the editor is derived from ext): the block refuses that, as
-- the backend refuses to start. Both CHECKs are rebuilt from the union on the next deploy when
-- they differ from it, and left alone when they match, so this block is idempotent and a re-run
-- costs nothing. A list that drops an extension stored rows still use fails the deploy (ADD
-- CONSTRAINT validates). The column default ('docx', the format of a blank Docs file) must stay
-- in the docs list; each editor's "New" format (docx, xlsx, pptx, pdf) must stay in its own list.
-- R3 (20261113-01) added the fourth editor, PDF, and its list here: this block rebuilds the CHECKs
-- on every deploy, so a list kept anywhere else would be undone by it.
DO $$
DECLARE
    docs_exts   constant text[] := ARRAY['docx', 'doc', 'odt', 'rtf', 'txt', 'md', 'html', 'dotx', 'ott'];  -- <<< PROVISIONAL LIST: docs
    sheets_exts constant text[] := ARRAY['xlsx', 'xlsm', 'csv', 'tsv', 'ods', 'xls'];                        -- <<< PROVISIONAL LIST: sheets
    slides_exts constant text[] := ARRAY['pptx', 'potx', 'ppsx', 'deckcraft'];                                -- <<< PROVISIONAL LIST: slides
    pdf_exts    constant text[] := ARRAY['pdf'];                                                              -- <<< PROVISIONAL LIST: pdf (R3 §7b, 20261113-01)
    exts        constant text[] := docs_exts || sheets_exts || slides_exts || pdf_exts;
    dup  text;
    t    record;
BEGIN
    IF NOT ('docx' = ANY (docs_exts) AND 'xlsx' = ANY (sheets_exts) AND 'pptx' = ANY (slides_exts) AND 'pdf' = ANY (pdf_exts)) THEN
        RAISE EXCEPTION 'office: each editor''s stored formats must include its "New" format (docx, xlsx, pptx, pdf)';
    END IF;
    SELECT e INTO dup FROM unnest(exts) AS e GROUP BY e HAVING count(*) > 1 LIMIT 1;
    IF dup IS NOT NULL THEN
        RAISE EXCEPTION 'office: the format % is listed twice; an ext belongs to exactly one editor', dup;
    END IF;
    FOR t IN SELECT * FROM (VALUES ('office.of_documents',         'of_documents_ext_check'),
                                   ('office.of_document_versions', 'of_document_versions_ext_check')) AS v(tbl, con)
    LOOP
        -- PostgreSQL renders the CHECK as  ((ext = ANY ('{a,b}'::text[])));  read the list back.
        IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                        WHERE c.conrelid = t.tbl::regclass AND c.conname = t.con AND c.contype = 'c'
                          AND pg_get_constraintdef(c.oid) ~ '^CHECK \(\(ext = ANY \(''\{[^'']*\}''::text\[\]\)\)\)$'
                          AND substring(pg_get_constraintdef(c.oid) FROM '''(\{[^'']*\})''')::text[] = exts) THEN
            EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', t.tbl, t.con);
            EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I CHECK (ext = ANY (%L::text[]))', t.tbl, t.con, exts);
        END IF;
    END LOOP;
END $$;

COMMIT;
