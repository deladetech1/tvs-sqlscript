-- Projects: comments on the words of a page.
--
--   * prj_doc_comments: a comment on a passage of a page -- the passage itself (quote) and
--     which time it appears (occurrence, from 0), so the page shows it highlighted without the
--     comment ever changing the page (anyone who can read a page may comment while someone else
--     is editing it). A reply has parent_id; a thread is resolved on its first comment. When
--     the passage is edited away the thread stays, marked as no longer found in the page.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_doc_comments (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    doc_id         text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    parent_id      text REFERENCES projects.prj_doc_comments (id) ON DELETE CASCADE,
    quote          text NOT NULL DEFAULT '',
    occurrence     integer NOT NULL DEFAULT 0 CHECK (occurrence >= 0),
    body           text NOT NULL CHECK (btrim(body) <> ''),
    mentions       text[] NOT NULL DEFAULT '{}',
    author_id      text NOT NULL,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    edited_at      timestamptz,
    resolved_at    timestamptz,
    resolved_by    text,
    delete_status  text NOT NULL DEFAULT 'NOT_DELETED',
    CHECK (parent_id IS NOT NULL OR btrim(quote) <> '')
);
CREATE INDEX IF NOT EXISTS prj_doc_comments_doc_idx ON projects.prj_doc_comments (doc_id, cdatetime) WHERE delete_status = 'NOT_DELETED';

COMMIT;
