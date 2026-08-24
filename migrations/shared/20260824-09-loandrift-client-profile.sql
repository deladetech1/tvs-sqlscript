-- 20260824-09-loandrift-client-profile.sql
-- A profile photo on the client, and client-level supporting documents.
--
-- The identity fields a client is described by — date of birth, ID type and
-- number, occupation — already live on ld_clients; they were simply only
-- reachable through the loan capture screen, so the same person captured twice
-- could be described two different ways. Moving them into the client's own
-- add/edit form needs no new columns.
--
-- Two things do:
--
--   * a profile photo, which the client has and a loan does not; and
--   * documents attached to the client rather than to one loan. A Ghana Card
--     scan belongs to the person, not to whichever loan happened to be open
--     when it was uploaded, and re-uploading it per loan is how the same
--     document ends up in the system four times.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE loandrift.ld_clients
    ADD COLUMN IF NOT EXISTS profile_photo_path text;

-- Loan documents point at one loan. Client documents do not, so loan_id becomes
-- nullable and a document is either the client's or a particular loan's.
ALTER TABLE loandrift.ld_client_documents_paths
    ALTER COLUMN loan_id DROP NOT NULL;

-- What the document is, so the ID scan can be told from a bank statement
-- without opening it. Free text rather than an enum: what counts as supporting
-- evidence differs by lender and should not need a migration to extend.
ALTER TABLE loandrift.ld_client_documents_paths
    ADD COLUMN IF NOT EXISTS document_type text;

CREATE INDEX IF NOT EXISTS idx_ld_client_documents_paths_client
    ON loandrift.ld_client_documents_paths (tenant_id, org_id, bus_id, loc_id, client_id)
    WHERE delete_status = 'NOT_DELETED';
