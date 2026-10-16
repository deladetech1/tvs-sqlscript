-- Projects: diagrams in pages, drawn with draw.io.
--
--   * prj_diagrams: a diagram block in a page -- draw.io's own XML (what it reopens with) and an
--     SVG picture of it (what the page shows). Kept out of the page's content so a big diagram
--     never weighs down the page's saves and versions; the page names it by id. It is seen by
--     whoever sees its page (and, shared, by a portal client or public link reader).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS projects.prj_diagrams (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    doc_id      text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    xml         text NOT NULL DEFAULT '',
    svg         text NOT NULL DEFAULT '',
    created_by  text,
    updated_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_diagrams_doc_idx ON projects.prj_diagrams (doc_id);

COMMIT;
