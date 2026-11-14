-- Office R5: the business, inside Office (live data, scheduled reports, approve and sign, ask
-- your business, WhatsApp, local templates, offline, scan).
--
--   of_data_links      a Sheets range filled from a §A.1 dataset: which dataset and params, where
--                      (sheet, anchor cell), and when it was last refreshed. Values live in the file
--   of_schedules       a scheduled report: what (workbook of datasets, or a Docs file), when
--                      (cadence, time, timezone), to whom, in which format
--   of_schedule_runs   one row per run of a schedule (by the job or "Send now")
--   of_reviews         a review request on one frozen version of a file
--   of_review_steps    one row per reviewer of a review, with their decision
--   of_sign_envelopes  a signing request: the PDF made from one version, its state and the sealed
--                      result (completed_sha256 is what /verify looks up)
--   of_sign_signers    the people who sign, inside or outside the business; the link token and the
--                      6-digit code are stored only as hashes
--   of_sign_fields     where each signer signs: page and box in PDF points, ORIGIN BOTTOM-LEFT
--   of_sign_events     the envelope's audit trail: append-only (UPDATE and DELETE are refused while
--                      the envelope exists)
--   of_document_text   the extracted text of a file's version, for Ask your business (full-text
--                      search, 'simple' config, at most 60,000 characters)
--   of_link_sends      a link sent on WhatsApp (or another channel) and when it was first opened
--
-- Changes to earlier tables:
--   of_document_versions  + approved_review_id (the review that approved this version),
--                         + signed (the sealed PDF of a completed envelope) and signed_envelope_id;
--                         its reason may be 'sign'
--   of_document_shares    + reason ('review' when a share was given so a reviewer can read)
--
-- Views office.src_<app>_<name>: the ONLY way Office reads another app's records (contract §0).
-- Each carries tenant_id and bus_id; the column lists are documented above each view below.
-- office.src_core_permissions(tenant_id, bus_id, user_id, permission): the permissions a person
-- holds in a business, resolved the way Core Platform resolves them (see that view).
--
-- Permissions office|data|connect||any and office|reviews|manage||any go to Office Editor; Office
-- Admin is allowed by BEING the role and holds no office rows (20261110-01). Features office.data,
-- office.schedules, office.esign (ADVANCE); office.approvals, office.offline,
-- office.local_templates (BASIC). The tiers are not yet confirmed by the owner: they live here and
-- in kind.go only.
--
-- Every row carries tenant_id and bus_id; ids are text uuids. A file's data links, reviews, text
-- and link sends go with it (ON DELETE CASCADE) when it is purged; schedules and envelopes stay
-- (a schedule's file is set to NULL, an envelope keeps its record for /verify).
-- No grants on the tables: the app group's default privileges cover new tables (01-database.md
-- §8). The src_ views are owned by the migration role and read by Office's role; see the grants
-- block at the end.
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R5-business.md §0, §9, §10-D. Idempotent;
-- safe to re-run.

BEGIN;

-- ======================================================================== data links
CREATE TABLE IF NOT EXISTS office.of_data_links (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    seq           bigint GENERATED ALWAYS AS IDENTITY,
    document_id   text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    dataset       text NOT NULL
                  CONSTRAINT of_data_links_dataset_check CHECK (dataset ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'),
    params        jsonb NOT NULL DEFAULT '{}'
                  CONSTRAINT of_data_links_params_check CHECK (jsonb_typeof(params) = 'object'),
    sheet         text NOT NULL DEFAULT '',
    anchor_cell   text NOT NULL DEFAULT 'A1'
                  CONSTRAINT of_data_links_anchor_cell_check CHECK (anchor_cell ~ '^[A-Z]{1,3}[1-9][0-9]{0,6}$'),
    row_count     int NOT NULL DEFAULT 0
                  CONSTRAINT of_data_links_row_count_check CHECK (row_count BETWEEN 0 AND 5000),
    refreshed_at  timestamptz NOT NULL DEFAULT now(),
    refreshed_by  text NOT NULL,
    created_by    text NOT NULL,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS of_data_links_document_idx
    ON office.of_data_links (document_id, seq);
CREATE INDEX IF NOT EXISTS of_data_links_business_idx
    ON office.of_data_links (tenant_id, bus_id, dataset);

-- ========================================================================= schedules
-- cadence: daily; weekly on cadence_dow (0 = Sunday .. 6 = Saturday); monthly on cadence_day
-- (1..31; a short month runs on its last day). run_time is local to timezone.
-- report_kind 'workbook' uses datasets: [{dataset, params, sheet}]; 'document' uses document_id.
-- last_status / of_schedule_runs.status: running | sent | failed | skipped.
CREATE TABLE IF NOT EXISTS office.of_schedules (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    seq                 bigint GENERATED ALWAYS AS IDENTITY,
    name                text NOT NULL
                        CONSTRAINT of_schedules_name_check CHECK (char_length(btrim(name)) BETWEEN 1 AND 200),
    owner_user_id       text NOT NULL,
    report_kind         text NOT NULL DEFAULT 'workbook'
                        CONSTRAINT of_schedules_report_kind_check CHECK (report_kind IN ('workbook', 'document')),
    datasets            jsonb NOT NULL DEFAULT '[]'
                        CONSTRAINT of_schedules_datasets_check CHECK (jsonb_typeof(datasets) = 'array'),
    document_id         text REFERENCES office.of_documents (id) ON DELETE SET NULL,
    cadence             text NOT NULL
                        CONSTRAINT of_schedules_cadence_check CHECK (cadence IN ('daily', 'weekly', 'monthly')),
    cadence_dow         smallint
                        CONSTRAINT of_schedules_cadence_dow_check CHECK (cadence_dow BETWEEN 0 AND 6),
    cadence_day         smallint
                        CONSTRAINT of_schedules_cadence_day_check CHECK (cadence_day BETWEEN 1 AND 31),
    run_time            time NOT NULL DEFAULT '07:00',
    timezone            text NOT NULL DEFAULT 'Africa/Accra'
                        CONSTRAINT of_schedules_timezone_check CHECK (timezone <> ''),
    recipient_user_ids  text[] NOT NULL DEFAULT '{}',
    recipient_emails    text[] NOT NULL DEFAULT '{}'
                        CONSTRAINT of_schedules_recipient_emails_check CHECK (cardinality(recipient_emails) <= 10),
    format              text NOT NULL DEFAULT 'xlsx'
                        CONSTRAINT of_schedules_format_check CHECK (format IN ('xlsx', 'pdf', 'both')),
    save_to_folder_id   text REFERENCES office.of_folders (id) ON DELETE SET NULL,
    enabled             boolean NOT NULL DEFAULT true,
    last_run_at         timestamptz,
    last_status         text
                        CONSTRAINT of_schedules_last_status_check CHECK (last_status IN ('running', 'sent', 'failed', 'skipped')),
    last_error_code     text,
    next_run_at         timestamptz,
    created_by          text NOT NULL,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    udatetime           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_schedules_cadence_args_check CHECK (
        (cadence = 'daily'   AND cadence_dow IS NULL     AND cadence_day IS NULL) OR
        (cadence = 'weekly'  AND cadence_dow IS NOT NULL AND cadence_day IS NULL) OR
        (cadence = 'monthly' AND cadence_dow IS NULL     AND cadence_day IS NOT NULL)),
    CONSTRAINT of_schedules_report_check CHECK (report_kind = 'workbook' OR document_id IS NOT NULL OR NOT enabled)
);
-- The job: due and enabled (claimed FOR UPDATE SKIP LOCKED).
CREATE INDEX IF NOT EXISTS of_schedules_due_idx
    ON office.of_schedules (next_run_at) WHERE enabled;
CREATE INDEX IF NOT EXISTS of_schedules_business_idx
    ON office.of_schedules (tenant_id, bus_id, seq DESC);

CREATE TABLE IF NOT EXISTS office.of_schedule_runs (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    seq                bigint GENERATED ALWAYS AS IDENTITY,
    schedule_id        text NOT NULL REFERENCES office.of_schedules (id) ON DELETE CASCADE,
    trigger            text NOT NULL DEFAULT 'schedule'
                       CONSTRAINT of_schedule_runs_trigger_check CHECK (trigger IN ('schedule', 'manual')),
    triggered_by       text,  -- the person for 'manual'; NULL for the job
    status             text NOT NULL DEFAULT 'running'
                       CONSTRAINT of_schedule_runs_status_check CHECK (status IN ('running', 'sent', 'failed', 'skipped')),
    error_code         text,
    error_message      text,
    row_count          int NOT NULL DEFAULT 0
                       CONSTRAINT of_schedule_runs_row_count_check CHECK (row_count >= 0),
    recipient_count    int NOT NULL DEFAULT 0
                       CONSTRAINT of_schedule_runs_recipient_count_check CHECK (recipient_count >= 0),
    size_bytes         bigint NOT NULL DEFAULT 0
                       CONSTRAINT of_schedule_runs_size_check CHECK (size_bytes >= 0),
    delivery           text
                       CONSTRAINT of_schedule_runs_delivery_check CHECK (delivery IN ('attachment', 'link')),
    blob_key           text,
    saved_document_id  text,  -- the dated copy in save_to_folder, if any (no FK: it may be purged)
    started_at         timestamptz NOT NULL DEFAULT now(),
    finished_at        timestamptz
);
CREATE INDEX IF NOT EXISTS of_schedule_runs_schedule_idx
    ON office.of_schedule_runs (schedule_id, seq DESC);

-- =========================================================================== reviews
CREATE TABLE IF NOT EXISTS office.of_reviews (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    seq               bigint GENERATED ALWAYS AS IDENTITY,
    document_id       text NOT NULL REFERENCES office.of_documents (id) ON DELETE CASCADE,
    version           int NOT NULL  -- the frozen of_document_versions.version_no
                      CONSTRAINT of_reviews_version_check CHECK (version >= 1),
    version_id        text REFERENCES office.of_document_versions (id) ON DELETE SET NULL,
    requested_by      text NOT NULL,
    message           text
                      CONSTRAINT of_reviews_message_check CHECK (char_length(message) <= 2000),
    mode              text NOT NULL DEFAULT 'all'
                      CONSTRAINT of_reviews_mode_check CHECK (mode IN ('all', 'any', 'sequence')),
    due_at            timestamptz,
    status            text NOT NULL DEFAULT 'in_review'
                      CONSTRAINT of_reviews_status_check CHECK (status IN ('in_review', 'approved', 'changes_requested', 'cancelled')),
    decided_at        timestamptz,
    cancelled_by      text,
    reminders_sent    int NOT NULL DEFAULT 0
                      CONSTRAINT of_reviews_reminders_sent_check CHECK (reminders_sent BETWEEN 0 AND 3),
    last_reminded_at  timestamptz,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_reviews_decided_check CHECK ((status = 'in_review') = (decided_at IS NULL))
);
-- One open review per file.
CREATE UNIQUE INDEX IF NOT EXISTS of_reviews_open_uq
    ON office.of_reviews (document_id) WHERE status = 'in_review';
CREATE INDEX IF NOT EXISTS of_reviews_document_idx
    ON office.of_reviews (document_id, seq DESC);
-- "Sent" (mine=sent) and the reminder job.
CREATE INDEX IF NOT EXISTS of_reviews_requester_idx
    ON office.of_reviews (tenant_id, bus_id, requested_by, seq DESC);
CREATE INDEX IF NOT EXISTS of_reviews_due_idx
    ON office.of_reviews (due_at) WHERE status = 'in_review' AND due_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS office.of_review_steps (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    review_id    text NOT NULL REFERENCES office.of_reviews (id) ON DELETE CASCADE,
    user_id      text NOT NULL,
    position     int NOT NULL
                 CONSTRAINT of_review_steps_position_check CHECK (position >= 1),
    decision     text NOT NULL DEFAULT 'pending'
                 CONSTRAINT of_review_steps_decision_check CHECK (decision IN ('pending', 'approved', 'changes_requested')),
    comment      text
                 CONSTRAINT of_review_steps_comment_len_check CHECK (char_length(comment) <= 4000),
    notified_at  timestamptz,  -- sequence mode notifies one reviewer at a time
    decided_at   timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_review_steps_reviewer_uq UNIQUE (review_id, user_id),
    CONSTRAINT of_review_steps_comment_check CHECK (decision <> 'changes_requested' OR btrim(coalesce(comment, '')) <> ''),
    CONSTRAINT of_review_steps_decided_check CHECK ((decision = 'pending') = (decided_at IS NULL))
);
CREATE INDEX IF NOT EXISTS of_review_steps_review_idx
    ON office.of_review_steps (review_id, position);
-- "Waiting for you" (mine=to_do).
CREATE INDEX IF NOT EXISTS of_review_steps_todo_idx
    ON office.of_review_steps (tenant_id, bus_id, user_id) WHERE decision = 'pending';

-- =========================================================================== signing
-- document_id is NULL once the file is purged: the envelope stays, so /verify still answers.
CREATE TABLE IF NOT EXISTS office.of_sign_envelopes (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    seq                 bigint GENERATED ALWAYS AS IDENTITY,
    document_id         text REFERENCES office.of_documents (id) ON DELETE SET NULL,
    title               text NOT NULL,  -- the file's title when the envelope was made
    version             int NOT NULL
                        CONSTRAINT of_sign_envelopes_version_check CHECK (version >= 1),
    version_id          text REFERENCES office.of_document_versions (id) ON DELETE SET NULL,
    source_pdf_blob     text,  -- NULL until the converter has made the PDF
    source_sha256       text
                        CONSTRAINT of_sign_envelopes_source_sha256_check CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    page_count          int
                        CONSTRAINT of_sign_envelopes_page_count_check CHECK (page_count >= 1),
    status              text NOT NULL DEFAULT 'draft'
                        CONSTRAINT of_sign_envelopes_status_check CHECK (status IN ('draft', 'sent', 'completed', 'declined', 'voided', 'expired')),
    message             text
                        CONSTRAINT of_sign_envelopes_message_check CHECK (char_length(message) <= 2000),
    expires_at          timestamptz NOT NULL DEFAULT now() + interval '30 days',
    sent_at             timestamptz,
    completed_at        timestamptz,
    completed_pdf_blob  text,
    completed_sha256    text
                        CONSTRAINT of_sign_envelopes_completed_sha256_check CHECK (completed_sha256 ~ '^[0-9a-f]{64}$'),
    signed_version_id   text,  -- the of_document_versions row of the sealed PDF (no FK: cycle)
    voided_at           timestamptz,
    voided_by           text,
    void_reason         text,
    created_by          text NOT NULL,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    udatetime           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT of_sign_envelopes_completed_check CHECK (
        status <> 'completed' OR (completed_pdf_blob IS NOT NULL AND completed_sha256 IS NOT NULL AND completed_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS of_sign_envelopes_business_idx
    ON office.of_sign_envelopes (tenant_id, bus_id, status, seq DESC);
CREATE INDEX IF NOT EXISTS of_sign_envelopes_document_idx
    ON office.of_sign_envelopes (document_id, seq DESC);
-- /verify (public, across every business): the sealed PDF's hash, and the original's.
CREATE INDEX IF NOT EXISTS of_sign_envelopes_completed_sha_idx
    ON office.of_sign_envelopes (completed_sha256) WHERE completed_sha256 IS NOT NULL;
-- The expiry sweep.
CREATE INDEX IF NOT EXISTS of_sign_envelopes_expiry_idx
    ON office.of_sign_envelopes (expires_at) WHERE status = 'sent';

CREATE TABLE IF NOT EXISTS office.of_sign_signers (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    seq              bigint GENERATED ALWAYS AS IDENTITY,
    envelope_id      text NOT NULL REFERENCES office.of_sign_envelopes (id) ON DELETE CASCADE,
    position         int NOT NULL DEFAULT 1
                     CONSTRAINT of_sign_signers_position_check CHECK (position >= 1),
    name             text NOT NULL
                     CONSTRAINT of_sign_signers_name_check CHECK (btrim(name) <> ''),
    email            text NOT NULL
                     CONSTRAINT of_sign_signers_email_check CHECK (email = lower(email) AND position('@' IN email) > 1),
    phone            text  -- E.164
                     CONSTRAINT of_sign_signers_phone_check CHECK (phone ~ '^\+[1-9][0-9]{6,14}$'),
    user_id          text,  -- set for someone in the business, NULL for an outside signer
    status           text NOT NULL DEFAULT 'waiting'
                     CONSTRAINT of_sign_signers_status_check CHECK (status IN ('waiting', 'notified', 'viewed', 'signed', 'declined')),
    token_hash       text  -- sha256 hex of the 32-byte link token; NULL until sent
                     CONSTRAINT of_sign_signers_token_hash_check CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    code_hash        text,  -- the current 6-digit code, hashed
    code_expires_at  timestamptz,
    code_attempts    int NOT NULL DEFAULT 0
                     CONSTRAINT of_sign_signers_code_attempts_check CHECK (code_attempts >= 0),
    code_sent_at     timestamptz,
    otp_channel      text
                     CONSTRAINT of_sign_signers_otp_channel_check CHECK (otp_channel IN ('email', 'sms', 'session')),
    verified_at      timestamptz,
    notified_at      timestamptz,
    viewed_at        timestamptz,
    signed_at        timestamptz,
    declined_at      timestamptz,
    decline_reason   text,
    consent_at       timestamptz,
    ip               text,
    user_agent       text,
    cdatetime        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS of_sign_signers_token_uq
    ON office.of_sign_signers (token_hash) WHERE token_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS of_sign_signers_envelope_idx
    ON office.of_sign_signers (envelope_id, position, seq);
CREATE INDEX IF NOT EXISTS of_sign_signers_user_idx
    ON office.of_sign_signers (tenant_id, bus_id, user_id) WHERE user_id IS NOT NULL;

-- x, y, w, h are PDF points with the ORIGIN AT THE BOTTOM-LEFT of the page (PDF user space).
-- value: a signature or initials is a PNG data URL string or {"typed": "...", "font": "..."};
-- date and text are strings; checkbox is true/false.
CREATE TABLE IF NOT EXISTS office.of_sign_fields (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    envelope_id  text NOT NULL REFERENCES office.of_sign_envelopes (id) ON DELETE CASCADE,
    signer_id    text NOT NULL REFERENCES office.of_sign_signers (id) ON DELETE CASCADE,
    kind         text NOT NULL
                 CONSTRAINT of_sign_fields_kind_check CHECK (kind IN ('signature', 'initials', 'date', 'text', 'checkbox')),
    page         int NOT NULL
                 CONSTRAINT of_sign_fields_page_check CHECK (page >= 1),
    x            numeric(9,2) NOT NULL CONSTRAINT of_sign_fields_x_check CHECK (x >= 0),
    y            numeric(9,2) NOT NULL CONSTRAINT of_sign_fields_y_check CHECK (y >= 0),
    w            numeric(9,2) NOT NULL CONSTRAINT of_sign_fields_w_check CHECK (w > 0),
    h            numeric(9,2) NOT NULL CONSTRAINT of_sign_fields_h_check CHECK (h > 0),
    required     boolean NOT NULL DEFAULT true,
    label        text,
    value        jsonb,
    filled_at    timestamptz,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS of_sign_fields_envelope_idx
    ON office.of_sign_fields (envelope_id, page, seq);
CREATE INDEX IF NOT EXISTS of_sign_fields_signer_idx
    ON office.of_sign_fields (signer_id);

CREATE TABLE IF NOT EXISTS office.of_sign_events (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    envelope_id  text NOT NULL REFERENCES office.of_sign_envelopes (id) ON DELETE CASCADE,
    at           timestamptz NOT NULL DEFAULT now(),
    actor        text NOT NULL,  -- a user id, or 'signer:<signer id>' for an outside signer
    event        text NOT NULL
                 CONSTRAINT of_sign_events_event_check CHECK (event ~ '^[a-z][a-z_]*$'),
    ip           text,
    ua           text,
    detail       jsonb NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS of_sign_events_envelope_idx
    ON office.of_sign_events (envelope_id, seq);

-- Append-only: no UPDATE ever; a DELETE only as the cascade of its envelope's deletion (by then
-- the envelope row is gone). TRUNCATE (tests) is not affected.
CREATE OR REPLACE FUNCTION office.of_sign_events_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'office.of_sign_events is append-only' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF EXISTS (SELECT 1 FROM office.of_sign_envelopes e WHERE e.id = OLD.envelope_id) THEN
        RAISE EXCEPTION 'office.of_sign_events is append-only' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN OLD;
END $$;
DROP TRIGGER IF EXISTS of_sign_events_append_only ON office.of_sign_events;
CREATE TRIGGER of_sign_events_append_only BEFORE UPDATE OR DELETE ON office.of_sign_events
    FOR EACH ROW EXECUTE FUNCTION office.of_sign_events_append_only();

-- ===================================================================== document text
CREATE TABLE IF NOT EXISTS office.of_document_text (
    document_id  text PRIMARY KEY REFERENCES office.of_documents (id) ON DELETE CASCADE,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    version      int NOT NULL  -- the of_documents.version that was indexed
                 CONSTRAINT of_document_text_version_check CHECK (version >= 1),
    title        text NOT NULL DEFAULT '',
    text         text NOT NULL DEFAULT ''
                 CONSTRAINT of_document_text_text_check CHECK (char_length(text) <= 60000),
    search       tsvector GENERATED ALWAYS AS (
                     setweight(to_tsvector('simple'::regconfig, coalesce(title, '')), 'A') ||
                     setweight(to_tsvector('simple'::regconfig, coalesce(text, '')), 'B')) STORED,
    indexed_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS of_document_text_search_idx
    ON office.of_document_text USING gin (search);
CREATE INDEX IF NOT EXISTS of_document_text_business_idx
    ON office.of_document_text (tenant_id, bus_id);

-- ======================================================================== link sends
-- kind: which link was sent; token: carried in the sent URL so its first open can be recorded.
CREATE TABLE IF NOT EXISTS office.of_link_sends (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    seq          bigint GENERATED ALWAYS AS IDENTITY,
    document_id  text REFERENCES office.of_documents (id) ON DELETE CASCADE,
    envelope_id  text REFERENCES office.of_sign_envelopes (id) ON DELETE CASCADE,
    kind         text NOT NULL
                 CONSTRAINT of_link_sends_kind_check CHECK (kind IN ('share', 'guest', 'signing', 'copy')),
    channel      text NOT NULL DEFAULT 'whatsapp'
                 CONSTRAINT of_link_sends_channel_check CHECK (channel IN ('whatsapp', 'email', 'sms', 'copy')),
    target       text NOT NULL DEFAULT '',  -- E.164 phone, an email, or '' (wa.me with no number)
    token        text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', ''),
    sent_by      text NOT NULL,
    sent_at      timestamptz NOT NULL DEFAULT now(),
    opened_at    timestamptz,  -- the first open
    open_count   int NOT NULL DEFAULT 0
                 CONSTRAINT of_link_sends_open_count_check CHECK (open_count >= 0),
    CONSTRAINT of_link_sends_token_uq UNIQUE (token),
    CONSTRAINT of_link_sends_subject_check CHECK (document_id IS NOT NULL OR envelope_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS of_link_sends_document_idx
    ON office.of_link_sends (document_id, seq DESC);
CREATE INDEX IF NOT EXISTS of_link_sends_envelope_idx
    ON office.of_link_sends (envelope_id, seq DESC) WHERE envelope_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS of_link_sends_business_idx
    ON office.of_link_sends (tenant_id, bus_id, sent_by, seq DESC);

-- ============================================== versions: approved, signed; shares: reason
ALTER TABLE office.of_document_versions ADD COLUMN IF NOT EXISTS approved_review_id text;
ALTER TABLE office.of_document_versions ADD COLUMN IF NOT EXISTS signed boolean NOT NULL DEFAULT false;
ALTER TABLE office.of_document_versions ADD COLUMN IF NOT EXISTS signed_envelope_id text;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'office.of_document_versions'::regclass
                    AND conname = 'of_document_versions_approved_review_fk') THEN
        ALTER TABLE office.of_document_versions ADD CONSTRAINT of_document_versions_approved_review_fk
            FOREIGN KEY (approved_review_id) REFERENCES office.of_reviews (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'office.of_document_versions'::regclass
                    AND conname = 'of_document_versions_signed_envelope_fk') THEN
        ALTER TABLE office.of_document_versions ADD CONSTRAINT of_document_versions_signed_envelope_fk
            FOREIGN KEY (signed_envelope_id) REFERENCES office.of_sign_envelopes (id) ON DELETE SET NULL;
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS of_document_versions_approved_idx
    ON office.of_document_versions (document_id, seq DESC) WHERE approved_review_id IS NOT NULL;

-- A sealed PDF is saved as a new version with reason 'sign' (rebuilt only when it differs).
DO $$
DECLARE
    want constant text := 'CHECK ((reason = ANY (ARRAY[''upload''::text, ''create''::text, ''save''::text, ''restore''::text, ''sign''::text])))';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                    WHERE c.conrelid = 'office.of_document_versions'::regclass
                      AND c.conname = 'of_document_versions_reason_check'
                      AND pg_get_constraintdef(c.oid) = want) THEN
        ALTER TABLE office.of_document_versions DROP CONSTRAINT IF EXISTS of_document_versions_reason_check;
        ALTER TABLE office.of_document_versions ADD CONSTRAINT of_document_versions_reason_check
            CHECK (reason IN ('upload', 'create', 'save', 'restore', 'sign'));
    END IF;
END $$;

-- NULL for an ordinary share; 'review' when Office gave a reviewer read access.
ALTER TABLE office.of_document_shares ADD COLUMN IF NOT EXISTS reason text;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'office.of_document_shares'::regclass
                    AND conname = 'of_document_shares_reason_check') THEN
        ALTER TABLE office.of_document_shares ADD CONSTRAINT of_document_shares_reason_check
            CHECK (reason IN ('review', 'signing'));
    END IF;
END $$;

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-office-data',    'Office Data',    'Business data from the suite''s other apps in Sheets, and scheduled reports', 'rt-subscribed-app-office'),
('rt-office-reviews', 'Office Reviews', 'Review, approval and signing requests on files', 'rt-subscribed-app-office')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

-- Verbs asserted here so this file stands on its own (connect is new; manage as 20261110-01).
INSERT INTO core_platform.cp_actions (action, label, is_read_only, viewer_default) VALUES
('connect', 'Connect', false, false),
('manage',  'Manage',  false, false)
ON CONFLICT (action) DO NOTHING;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('data',    'rt-office-data',    'connect', 'Insert and refresh business data from the suite''s other apps, and create scheduled reports'),
    ('reviews', 'rt-office-reviews', 'manage',  'Send a file for review or signing, and cancel a request')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-office-' || spec.resource_key || '-' || spec.action,
       'Office ' || initcap(spec.resource_key) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

-- The pair, as 20261110-01 sets it (that file runs first, so it never sees these rows on a first
-- deploy).
UPDATE core_platform.cp_permissions p
   SET app_prefix = 'office',
       resource_key = substring(p.id FROM '^permission-office-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id IN ('permission-office-data-connect', 'permission-office-reviews-manage')
   AND (p.app_prefix IS DISTINCT FROM 'office' OR p.action IS NULL);

-- To Office Editor. Office Admin holds them by being the role; the Viewer holds neither.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-office-editor', 'data', 'connect'),
        ('role-office-editor', 'reviews', 'manage')
  ) AS spec(role_id, resource_key, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'office' AND p.resource_key = spec.resource_key AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

-- ========================================================== features per tier
-- Not yet confirmed by the owner: change a tier here and in kind.go, nowhere else.
INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
-- ---- BASIC ----------------------------------------------------------------------
('office.approvals',       'app-office', 'Review and Approve',  1, 'Send a file to colleagues for review, and keep the approved version'),
('office.offline',         'app-office', 'Available Offline',   1, 'Open the editors instantly and read chosen files with no network'),
('office.local_templates', 'app-office', 'Local Templates',     1, 'Ready-made Ghanaian business templates: VAT invoice, SSNIT and PAYE schedules, contracts and more'),
-- ---- ADVANCE --------------------------------------------------------------------
('office.data',            'app-office', 'Business Data',       2, 'Insert live data from CRM, Invoicing, Expenses, Help Desk, Projects, HR and Supply Chain into Sheets, and refresh it'),
('office.schedules',       'app-office', 'Scheduled Reports',   2, 'Email a workbook of business data to people on a daily, weekly or monthly schedule'),
('office.esign',           'app-office', 'Electronic Signing',  2, 'Send a file for signature inside or outside the business, with a completion certificate')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id        = EXCLUDED.app_id,
    title         = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank,
    description   = EXCLUDED.description,
    is_active     = true;

-- @@VIEWS@@

COMMIT;
