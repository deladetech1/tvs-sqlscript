-- Projects: editing a page together, live (Google Docs style).
--
-- The browsers merge (Yjs, a CRDT); the server only keeps and relays what they send, so it
-- works across any number of API replicas:
--
--   * prj_doc_yupdates: each change a browser made to a page, in order (seq). A page's state is
--     all of them merged; a browser now and then folds them into one (a snapshot) to keep the
--     list short. epoch: the generation of the page's shared state -- restoring a version starts
--     a new one, and every open browser reloads.
--   * prj_docs.collab_epoch / collab_claimed_at: the current generation, and who is putting an
--     existing page's content into a new, empty one (one browser at a time, for 15 seconds).
--   * prj_doc_presence: who has the page open right now and where their cursor is (the browser's
--     own awareness message), seen in the last few seconds.
--
-- The page's JSON (prj_docs.content) is still saved, by whoever made each change: search,
-- export, versions, the client portal and public links read that, not the updates.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS collab_epoch integer NOT NULL DEFAULT 0;
ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS collab_claimed_at timestamptz;
ALTER TABLE projects.prj_docs ADD COLUMN IF NOT EXISTS collab_claimed_by text;

CREATE TABLE IF NOT EXISTS projects.prj_doc_yupdates (
    seq        bigserial PRIMARY KEY,
    doc_id     text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    tenant_id  text NOT NULL,
    epoch      integer NOT NULL,
    data       bytea NOT NULL,
    snapshot   boolean NOT NULL DEFAULT false,
    client     text NOT NULL DEFAULT '',
    cdatetime  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prj_doc_yupdates_doc_idx ON projects.prj_doc_yupdates (doc_id, epoch, seq);

CREATE TABLE IF NOT EXISTS projects.prj_doc_presence (
    doc_id     text NOT NULL REFERENCES projects.prj_docs (id) ON DELETE CASCADE,
    client     text NOT NULL,
    tenant_id  text NOT NULL,
    user_id    text NOT NULL,
    data       bytea NOT NULL,
    seen_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (doc_id, client)
);

-- Changes are numbered by a sequence (the first in this schema): whoever may write the table
-- may number its rows. Table grants come from default privileges; sequences may not.
DO $$
DECLARE r text;
BEGIN
    FOR r IN SELECT DISTINCT grantee FROM information_schema.role_table_grants
              WHERE table_schema = 'projects' AND table_name = 'prj_doc_yupdates' AND privilege_type = 'INSERT'
                AND grantee <> current_user
    LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE projects.prj_doc_yupdates_seq_seq TO %I', r);
    END LOOP;
END $$;

COMMIT;
