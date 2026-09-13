-- Structured names are entered by staff: do not guess how legacy full names split.
-- Keep fullname for existing reports, loan screens and search.
ALTER TABLE loandrift.ld_clients
    ADD COLUMN IF NOT EXISTS first_name text,
    ADD COLUMN IF NOT EXISTS middle_names text,
    ADD COLUMN IF NOT EXISTS surname text,
    ADD COLUMN IF NOT EXISTS profile_photo_path text;

-- Files may be staged before a client is saved, then attached in its transaction.
ALTER TABLE loandrift.ld_client_documents_paths
    ALTER COLUMN client_id DROP NOT NULL,
    ALTER COLUMN loan_id DROP NOT NULL;
