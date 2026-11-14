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

-- ======================================================================= link events
-- office.tasks_requested on office-projects: one event per action item of minutes ("Create tasks
-- in Projects"), in the platform/linkbox envelope; Projects' inbox (projects.prj_link_inbox)
-- creates the task as requested_by, with that person's own Projects permissions. Office reads how
-- it went from office.src_projects_requests. This file owns the catalogue row (a newer file that
-- changes the schema adds a version).
DO $$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'office-r5: no event catalogue here; skipping office.tasks_requested';
        RETURN;
    END IF;
    WITH envelope AS (
        SELECT jsonb_build_object(
            '$schema', 'https://json-schema.org/draft/2020-12/schema',
            'type', 'object',
            'required', jsonb_build_array('v', 'link', 'idempotency_key', 'data'),
            'properties', jsonb_build_object(
                'v', jsonb_build_object('type', 'integer', 'minimum', 1),
                'link', jsonb_build_object('type', 'string'),
                'idempotency_key', jsonb_build_object('type', 'string', 'minLength', 1, 'maxLength', 200),
                'sent_at', jsonb_build_object('type', 'string', 'format', 'date-time'),
                'sent_by', jsonb_build_object('type', 'string'))) AS e
    ), kinds (kind, version, link_key, source_app, target_app, phase, description, data) AS (
        SELECT * FROM (VALUES
        ('office.tasks_requested', 1, 'office-projects', 'app-office', 'app-projects', 1,
         'An action item from meeting minutes in Office: Projects creates the task in the chosen project as the person who asked.',
         '{"type":"object","required":["request_id","project_id","requested_by","title"],"properties":{
            "request_id":{"type":"string"},"project_id":{"type":"string"},"requested_by":{"type":"string"},
            "title":{"type":"string","minLength":1,"maxLength":500},"description":{"type":"string"},
            "assignee_user_id":{"type":"string"},"owner_name":{"type":"string"},
            "due_date":{"type":"string","format":"date"},"document_id":{"type":"string"},"link":{"type":"string"}}}'::jsonb)
        ) v
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, k.version, k.link_key, k.source_app, k.target_app, k.phase, k.description,
           jsonb_set(e.e, '{properties,data}', k.data) || jsonb_build_object('title', k.kind || ' v' || k.version), now()
      FROM kinds k CROSS JOIN envelope e
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $$;

-- ===================================================================== the src_ views
-- Read-only views over the other apps' tables, each created only where that app's tables exist
-- (a database without the app has no view, and Office answers SOURCE_NOT_CONNECTED for it).
-- Every view has tenant_id and bus_id; ZelosHR is per organisation, so its views carry org_id
-- AND one row per business of that organisation (bus_id from core_platform.cp_businesses).
-- Money is (amount, currency): currency is the ISO code. No grants: like helpdesk.src_zeloshr_*
-- (20261109-73), the views are made by the migration role in the app group's schema, and the
-- group's default privileges cover them.
--
-- office.src_crm_deals                 (crm.crm_deals; live deals only)
--   tenant_id, bus_id, deal_id, title, pipeline_id, pipeline_name, stage_id, stage_name,
--   stage_position, stage_kind, status (open|won|lost), amount, currency, probability,
--   expected_close_date, closed_at, owner_user_id, owner_name, company_id, company_name,
--   contact_id, contact_name, created_at, updated_at
-- office.src_invoicing_invoices        (invoicing.inv_invoices; kind 'invoice', not drafts)
--   tenant_id, bus_id, invoice_id, number, status (open|paid|void), customer_id, customer_name,
--   title, reference, issue_date, due_date, currency, subtotal, tax_total, total, amount_paid,
--   balance, days_overdue (0 unless open with a balance and past due), paid_at, voided_at,
--   created_at
-- office.src_invoicing_payments        (invoicing.inv_payments; received, not voided)
--   tenant_id, bus_id, payment_id, invoice_id, customer_id, kind (payment|refund), amount,
--   currency, paid_on, method, reference
-- office.src_invoicing_customers       (core_platform.cp_parties; the business's customers)
--   tenant_id, bus_id, customer_id, name, email, phone, currency, archived
-- office.src_expenses_claims           (expenses.exp_claims; not drafts)
--   tenant_id, bus_id, claim_id, number, title, claimant_id, claimant_name, status
--   (submitted|approved|returned|rejected|paid|cancelled), currency, total, paid_total,
--   submitted_at, approved_at, paid_at, created_at
-- office.src_expenses_lines            (expenses.exp_expenses with category and claim)
--   tenant_id, bus_id, expense_id, claim_id, claim_number, claim_status (NULL: not on a claim),
--   user_id, category_id, category_name, kind (receipt|mileage|per_diem), spent_on, merchant,
--   amount, currency, amount_base, base_currency, billable
-- office.src_helpdesk_tickets          (helpdesk.hd_tickets; never confidential HR cases,
--                                       deleted or merged tickets)
--   tenant_id, bus_id, ticket_id, number, subject, ticket_type, priority, status_category,
--   is_open, department_id, department_name, team_id, team_name, assignee_user_id,
--   assignee_name, source, created_at, due_at, first_responded_at, resolved_at, closed_at,
--   age_days, is_restricted
-- office.src_helpdesk_sla              (helpdesk.hd_sla_clocks of those tickets)
--   tenant_id, bus_id, ticket_id, metric (first_response|next_response|resolution), state
--   (running|paused|met|breached|cancelled), target_minutes, started_at, due_at, breached_at,
--   stopped_at, priority, team_id, team_name, is_restricted
-- office.src_projects_projects         (projects.prj_projects; live, not templates)
--   tenant_id, bus_id, project_id, key, name, status (active|archived), lead_user_id, lead_name,
--   project_open, workspace_open, member_ids, workspace_member_ids, task_count, done_count,
--   open_count, overdue_count, percent_done, due_date, currency, budget_amount, budget_hours
--   Who may see a project (Projects' visibleSQL, as data, as helpdesk.src_projects_projects):
--   (project_open OR user = ANY(member_ids)) AND (workspace_open OR user = ANY(workspace_member_ids))
-- office.src_projects_worklogs         (projects.prj_worklogs)
--   tenant_id, bus_id, worklog_id, project_id, project_name, task_id, task_title, user_id,
--   user_name, work_date, minutes, hours, billable. Join src_projects_projects for visibility.
-- office.src_projects_requests         (projects.prj_link_inbox; office.tasks_requested)
--   tenant_id, bus_id, request_id, status, last_error, attempts, task_id, task_key, received_at,
--   handled_at
-- office.src_zeloshr_people            (zeloshr.zhr_employees; NO pay, bank, tax, SSNIT, ID or
--                                       contact data, ever)
--   tenant_id, bus_id, org_id, employee_id, user_id, full_name, job_title, department_id,
--   department_name, branch_id, branch_name, employment_type, employment_status, start_date,
--   left_on, is_current
-- office.src_zeloshr_leave_balances    (zeloshr.zhr_leave_balances)
--   tenant_id, bus_id, org_id, employee_id, full_name, department_name, leave_type,
--   entitled_days, used_days, remaining_days, is_current
-- office.src_scm_stock                 (scm.scm_stock_balances summed per item and warehouse)
--   tenant_id, bus_id, product_id, sku, item_name, category, unit, warehouse_id, warehouse_code,
--   warehouse_name, on_hand, reserved, available, reorder_point, reorder_qty, safety_stock,
--   below_reorder

-- ---------------------------------------------------------------------------- CRM
DO $$
BEGIN
    IF to_regclass('crm.crm_deals') IS NULL OR to_regclass('crm.crm_pipeline_stages') IS NULL THEN
        RAISE NOTICE 'office-r5: no CRM here; no office.src_crm_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_crm_deals AS
    SELECT d.tenant_id, d.bus_id, d.id AS deal_id, d.title, d.pipeline_id, p.name AS pipeline_name,
           d.stage_id, s.name AS stage_name, s.position AS stage_position, s.kind AS stage_kind,
           d.status, coalesce(d.amount, 0) AS amount, coalesce(cur.code, d.currency_id) AS currency,
           coalesce(d.probability, s.probability) AS probability, d.expected_close_date, d.closed_at,
           d.owner_user_id, ou.fullname AS owner_name, d.company_id, co.name AS company_name,
           d.contact_id, coalesce(nullif(btrim(ct.full_name), ''), btrim(concat_ws(' ', ct.first_name, ct.last_name))) AS contact_name,
           d.cdatetime AS created_at, d.updated_at
      FROM crm.crm_deals d
      LEFT JOIN crm.crm_pipelines p ON p.id = d.pipeline_id AND p.tenant_id = d.tenant_id
      LEFT JOIN crm.crm_pipeline_stages s ON s.id = d.stage_id AND s.tenant_id = d.tenant_id
      LEFT JOIN core_platform.cp_currencies cur ON cur.id = d.currency_id
      LEFT JOIN core_platform.cp_users ou ON ou.id = d.owner_user_id AND ou.tenant_id = d.tenant_id
      LEFT JOIN crm.crm_companies co ON co.id = d.company_id AND co.tenant_id = d.tenant_id
      LEFT JOIN crm.crm_contacts ct ON ct.id = d.contact_id AND ct.tenant_id = d.tenant_id
     WHERE coalesce(d.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND coalesce(d.is_active, true)
    $v$;
END $$;

-- ---------------------------------------------------------------------- Invoicing
DO $$
BEGIN
    IF to_regclass('invoicing.inv_invoices') IS NULL OR to_regclass('invoicing.inv_payments') IS NULL THEN
        RAISE NOTICE 'office-r5: no Invoicing here; no office.src_invoicing_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_invoicing_invoices AS
    SELECT i.tenant_id, i.bus_id, i.id AS invoice_id, i.number, i.status, i.customer_id,
           coalesce(nullif(btrim(pt.name), ''), i.customer_snapshot ->> 'name') AS customer_name,
           i.title, i.reference, i.issue_date, i.due_date, btrim(i.currency) AS currency,
           coalesce(i.subtotal, 0) AS subtotal, coalesce(i.tax_total, 0) AS tax_total, coalesce(i.total, 0) AS total,
           coalesce(i.amount_paid, 0) AS amount_paid, coalesce(i.balance, 0) AS balance,
           CASE WHEN i.status = 'open' AND coalesce(i.balance, 0) > 0 AND i.due_date < current_date
                THEN current_date - i.due_date ELSE 0 END AS days_overdue,
           i.paid_at, i.voided_at, i.cdatetime AS created_at
      FROM invoicing.inv_invoices i
      LEFT JOIN core_platform.cp_parties pt ON pt.id = i.customer_id AND pt.tenant_id = i.tenant_id
     WHERE i.kind = 'invoice' AND i.status <> 'draft'
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_invoicing_payments AS
    SELECT p.tenant_id, p.bus_id, p.id AS payment_id, p.invoice_id, p.customer_id, p.kind,
           p.amount, btrim(p.currency) AS currency, p.paid_on, p.method, p.reference
      FROM invoicing.inv_payments p
     WHERE p.status = 'received' AND p.voided_at IS NULL
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_invoicing_customers AS
    SELECT pt.tenant_id, pt.bus_id, pt.id AS customer_id, pt.name, pt.email, pt.phone,
           btrim(pt.currency) AS currency, pt.archived_at IS NOT NULL AS archived
      FROM core_platform.cp_parties pt
     WHERE pt.is_customer AND pt.deleted_at IS NULL
    $v$;
END $$;

-- ----------------------------------------------------------------------- Expenses
DO $$
BEGIN
    IF to_regclass('expenses.exp_claims') IS NULL OR to_regclass('expenses.exp_expenses') IS NULL THEN
        RAISE NOTICE 'office-r5: no Expenses here; no office.src_expenses_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_expenses_claims AS
    SELECT c.tenant_id, c.bus_id, c.id AS claim_id, c.number, c.title, c.claimant_id,
           coalesce(nullif(btrim(c.claimant_name), ''), u.fullname) AS claimant_name, c.status,
           btrim(c.currency) AS currency, coalesce(c.total, 0) AS total, coalesce(c.paid_total, 0) AS paid_total,
           c.submitted_at, c.approved_at, c.paid_at, c.cdatetime AS created_at
      FROM expenses.exp_claims c
      LEFT JOIN core_platform.cp_users u ON u.id = c.claimant_id AND u.tenant_id = c.tenant_id
     WHERE c.status <> 'draft'
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_expenses_lines AS
    SELECT e.tenant_id, e.bus_id, e.id AS expense_id, e.claim_id, c.number AS claim_number, c.status AS claim_status,
           e.user_id, e.category_id, cat.name AS category_name, e.kind, e.spent_on, e.merchant,
           e.amount, btrim(e.currency) AS currency, coalesce(e.amount_base, e.amount) AS amount_base,
           btrim(coalesce(st.base_currency, e.currency)) AS base_currency, coalesce(e.billable, false) AS billable
      FROM expenses.exp_expenses e
      LEFT JOIN expenses.exp_categories cat ON cat.id = e.category_id
      LEFT JOIN expenses.exp_claims c ON c.id = e.claim_id
      LEFT JOIN expenses.exp_settings st ON st.tenant_id = e.tenant_id AND st.bus_id = e.bus_id
    $v$;
END $$;

-- ---------------------------------------------------------------------- Help Desk
DO $$
BEGIN
    IF to_regclass('helpdesk.hd_tickets') IS NULL OR to_regclass('helpdesk.hd_sla_clocks') IS NULL
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'helpdesk' AND table_name = 'hd_tickets'
                       AND column_name = 'confidentiality') THEN
        RAISE NOTICE 'office-r5: no Help Desk (with HR confidentiality) here; no office.src_helpdesk_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_helpdesk_tickets AS
    SELECT t.tenant_id, t.bus_id, t.id AS ticket_id, t.number, t.subject, t.ticket_type, t.priority,
           t.status_category, t.status_category NOT IN ('resolved', 'closed', 'cancelled') AS is_open,
           t.department_id, d.name AS department_name, t.team_id, tm.name AS team_name,
           t.assignee_user_id, au.fullname AS assignee_name, t.source, t.cdatetime AS created_at, t.due_at,
           t.first_responded_at, t.resolved_at, t.closed_at,
           (current_date - (t.cdatetime AT TIME ZONE 'UTC')::date) AS age_days, coalesce(t.is_restricted, false) AS is_restricted
      FROM helpdesk.hd_tickets t
      LEFT JOIN helpdesk.hd_departments d ON d.id = t.department_id AND d.tenant_id = t.tenant_id
      LEFT JOIN helpdesk.hd_teams tm ON tm.id = t.team_id AND tm.tenant_id = t.tenant_id
      LEFT JOIN core_platform.cp_users au ON au.id = t.assignee_user_id AND au.tenant_id = t.tenant_id
     WHERE t.deleted_at IS NULL AND t.merged_into_id IS NULL AND t.confidentiality = 'none'
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_helpdesk_sla AS
    SELECT c.tenant_id, c.bus_id, c.ticket_id, c.metric, c.state, c.target_minutes, c.started_at, c.due_at,
           c.breached_at, c.stopped_at, t.priority, t.team_id, tm.name AS team_name, coalesce(t.is_restricted, false) AS is_restricted
      FROM helpdesk.hd_sla_clocks c
      JOIN helpdesk.hd_tickets t ON t.id = c.ticket_id AND t.tenant_id = c.tenant_id
      LEFT JOIN helpdesk.hd_teams tm ON tm.id = t.team_id AND tm.tenant_id = t.tenant_id
     WHERE t.deleted_at IS NULL AND t.merged_into_id IS NULL AND t.confidentiality = 'none'
    $v$;
END $$;

-- ----------------------------------------------------------------------- Projects
DO $$
BEGIN
    IF to_regclass('projects.prj_projects') IS NULL OR to_regclass('projects.prj_tasks') IS NULL
       OR to_regclass('projects.prj_workspaces') IS NULL OR to_regclass('projects.prj_worklogs') IS NULL THEN
        RAISE NOTICE 'office-r5: no Projects here; no office.src_projects_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_projects_projects AS
    SELECT p.tenant_id, p.bus_id, p.id AS project_id, p.key, p.name, p.status, p.lead_user_id, lu.fullname AS lead_name,
           p.visibility = 'business' AS project_open, w.visibility = 'business' AS workspace_open,
           array_remove(array_append(coalesce((SELECT array_agg(m.user_id) FROM projects.prj_members m WHERE m.project_id = p.id), '{}'), p.lead_user_id), NULL) AS member_ids,
           array_remove(array_append(coalesce((SELECT array_agg(wm.user_id) FROM projects.prj_workspace_members wm WHERE wm.workspace_id = w.id), '{}'), w.owner_user_id), NULL) AS workspace_member_ids,
           coalesce(tc.task_count, 0) AS task_count, coalesce(tc.done_count, 0) AS done_count,
           coalesce(tc.task_count, 0) - coalesce(tc.done_count, 0) AS open_count, coalesce(tc.overdue_count, 0) AS overdue_count,
           CASE WHEN coalesce(tc.task_count, 0) = 0 THEN 0
                ELSE round(100.0 * tc.done_count / tc.task_count, 1) END AS percent_done,
           coalesce((SELECT max(ms.due_date) FROM projects.prj_milestones ms
                      WHERE ms.project_id = p.id AND coalesce(ms.delete_status, 'NOT_DELETED') = 'NOT_DELETED'), tc.last_due) AS due_date,
           p.currency, p.budget_amount, p.budget_hours
      FROM projects.prj_projects p
      JOIN projects.prj_workspaces w ON w.id = p.workspace_id AND w.delete_status = 'NOT_DELETED'
      LEFT JOIN core_platform.cp_users lu ON lu.id = p.lead_user_id AND lu.tenant_id = p.tenant_id
      LEFT JOIN LATERAL (
            SELECT count(*)::int AS task_count,
                   count(*) FILTER (WHERE st.category = 'done')::int AS done_count,
                   count(*) FILTER (WHERE st.category <> 'done' AND t.due_date < current_date)::int AS overdue_count,
                   max(t.due_date) AS last_due
              FROM projects.prj_tasks t
              JOIN projects.prj_statuses st ON st.id = t.status_id
             WHERE t.project_id = p.id AND t.delete_status = 'NOT_DELETED') tc ON true
     WHERE p.delete_status = 'NOT_DELETED' AND NOT coalesce(p.is_template, false)
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_projects_worklogs AS
    SELECT p.tenant_id, p.bus_id, wl.id AS worklog_id, wl.project_id, p.name AS project_name, wl.task_id, t.title AS task_title,
           wl.user_id, u.fullname AS user_name, wl.work_date, wl.minutes, round(wl.minutes / 60.0, 2) AS hours,
           coalesce(wl.billable, false) AS billable
      FROM projects.prj_worklogs wl
      JOIN projects.prj_projects p ON p.id = wl.project_id AND p.tenant_id = wl.tenant_id AND p.delete_status = 'NOT_DELETED'
      LEFT JOIN projects.prj_tasks t ON t.id = wl.task_id
      LEFT JOIN core_platform.cp_users u ON u.id = wl.user_id AND u.tenant_id = wl.tenant_id
    $v$;
    IF to_regclass('projects.prj_link_inbox') IS NOT NULL THEN
        -- How each "Create tasks in Projects" request went (idempotency key = Office's request id).
        EXECUTE $v$
        CREATE OR REPLACE VIEW office.src_projects_requests AS
        SELECT i.tenant_id, i.bus_id, i.idempotency_key AS request_id, i.status, i.last_error, i.attempts,
               i.result ->> 'task_id' AS task_id, i.result ->> 'task_key' AS task_key, i.received_at, i.handled_at
          FROM projects.prj_link_inbox i
         WHERE i.kind = 'office.tasks_requested' AND i.source_app = 'app-office'
        $v$;
    END IF;
END $$;

-- ------------------------------------------------------------------------ ZelosHR
-- NEVER pay, bank, mobile money, tax, SSNIT, national ID, address, phone or date of birth: the
-- columns below are the whole list (invariant 6 checks it).
DO $$
BEGIN
    IF to_regclass('zeloshr.zhr_employees') IS NULL OR to_regclass('zeloshr.zhr_leave_balances') IS NULL
       OR to_regclass('zeloshr.zhr_departments') IS NULL THEN
        RAISE NOTICE 'office-r5: no ZelosHR here; no office.src_zeloshr_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_zeloshr_people AS
    SELECT e.tenant_id, b.id AS bus_id, e.org_id, e.id::text AS employee_id, e.user_id::text AS user_id,
           coalesce(nullif(btrim(e.full_name), ''), nullif(btrim(concat_ws(' ', e.first_name, e.last_name)), ''), cu.fullname) AS full_name,
           e.job_title, e.department_id::text AS department_id, d.name AS department_name,
           e.branch_id::text AS branch_id, br.name::text AS branch_name, e.employment_type, e.employment_status,
           coalesce(e.employment_start_date, e.start_date) AS start_date,
           (SELECT max(oc.last_working_day) FROM zeloshr.zhr_offboarding_cases oc
             WHERE oc.employee_id = e.id AND oc.tenant_id = e.tenant_id AND coalesce(oc.state, '') NOT ILIKE 'cancel%') AS left_on,
           (lower(coalesce(e.lifecycle_state, '')) NOT IN ('resigned', 'terminated', 'retired', 'inactive')
            AND lower(coalesce(e.employment_status, '')) NOT IN ('resigned', 'terminated', 'retired', 'inactive')) AS is_current
      FROM zeloshr.zhr_employees e
      JOIN core_platform.cp_businesses b ON b.tenant_id = e.tenant_id AND b.org_id = e.org_id
           AND coalesce(b.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
      LEFT JOIN core_platform.cp_users cu ON cu.id = e.user_id AND cu.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_departments d ON d.id = e.department_id AND d.tenant_id = e.tenant_id
      LEFT JOIN zeloshr.zhr_branches br ON br.id = e.branch_id AND br.tenant_id = e.tenant_id
     WHERE NOT coalesce(e.is_deleted, false) AND NOT coalesce(e.is_draft, false)
    $v$;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_zeloshr_leave_balances AS
    SELECT p.tenant_id, p.bus_id, p.org_id, p.employee_id, p.full_name, p.department_name,
           coalesce(t.name, lb.leave_type)::text AS leave_type, lb.entitled_days, lb.used_days, lb.remaining_days, p.is_current
      FROM zeloshr.zhr_leave_balances lb
      JOIN office.src_zeloshr_people p ON p.employee_id = lb.employee_id::text AND p.tenant_id = lb.tenant_id
      LEFT JOIN zeloshr.zhr_leave_types t ON t.id = lb.leave_type_id AND t.tenant_id = lb.tenant_id
    $v$;
END $$;

-- ---------------------------------------------------------------------------- SCM
DO $$
BEGIN
    IF to_regclass('scm.scm_stock_balances') IS NULL OR to_regclass('scm.scm_warehouses') IS NULL
       OR to_regclass('scm.scm_item_settings') IS NULL OR to_regclass('core_platform.cp_products') IS NULL THEN
        RAISE NOTICE 'office-r5: no Supply Chain here; no office.src_scm_* views';
        RETURN;
    END IF;
    EXECUTE $v$
    CREATE OR REPLACE VIEW office.src_scm_stock AS
    SELECT sb.tenant_id, sb.bus_id, sb.product_id, pr.sku, pr.name AS item_name, pr.category, pr.unit,
           sb.warehouse_id, w.code AS warehouse_code, w.name AS warehouse_name,
           sb.on_hand, sb.reserved, sb.on_hand - sb.reserved AS available,
           s.reorder_point, s.reorder_qty, s.safety_stock,
           (s.reorder_point IS NOT NULL AND sb.on_hand <= s.reorder_point) AS below_reorder
      FROM (SELECT b.tenant_id, b.bus_id, b.product_id, b.warehouse_id,
                   sum(b.on_hand) AS on_hand, sum(coalesce(b.reserved, 0)) AS reserved
              FROM scm.scm_stock_balances b
             GROUP BY b.tenant_id, b.bus_id, b.product_id, b.warehouse_id) sb
      JOIN core_platform.cp_products pr ON pr.id = sb.product_id AND pr.tenant_id = sb.tenant_id
      JOIN scm.scm_warehouses w ON w.id = sb.warehouse_id AND w.tenant_id = sb.tenant_id
      LEFT JOIN scm.scm_item_settings s ON s.product_id = sb.product_id AND s.tenant_id = sb.tenant_id AND s.bus_id = sb.bus_id
    $v$;
END $$;

-- ============================================================ office.src_core_permissions
-- (tenant_id, bus_id, user_id, permission): every permission key a person holds in a business,
-- resolved as Core resolves them (tvs-package-go auth: Authorizer.roles, permissionKeys,
-- HasAny / appAdminAllows). Office asks it for a source app's read permission:
--     SELECT EXISTS (SELECT 1 FROM office.src_core_permissions
--                     WHERE tenant_id = $1 AND bus_id = $2 AND user_id = $3 AND permission = $4)
--
--   * Roles: the person's own and their groups' tenant assignments (cp_assign_roles, not system,
--     live), plus system assignments (tenant 'system-tenant-id', is_system) made to the person or
--     to a system group they are in. Roles are tenant-wide, so a role holds in every live business
--     of the tenant.
--   * A role's permissions are its cp_role_permissions rows of the system tenant for a system role
--     (of the person's tenant otherwise), and of the other tenant when it has none there. Each row
--     answers its permission_id and its pair key app|resource|action|target|scope (scope '' = any).
--   * role-owner holds every permission. role-admin holds every permission of every app and of
--     Core Platform, role-cp-admin every Core Platform one (prefix '' or 'cp'), and
--     role-subscribed-app-<app>-admin every one of <app>: as pair keys, and never a write on
--     'logs' or 'audit' (a write = an action that cp_actions does not mark read-only).
--   * A person who is inactive or deleted (cp_users) holds nothing.
-- Plan and subscription are not here: Office checks entitlement (the business subscribes to the
-- source app) on its own.
CREATE OR REPLACE VIEW office.src_core_permissions AS
WITH tgroups AS NOT MATERIALIZED (
    SELECT ug.tenant_id, ug.user_id, ug.group_id
      FROM core_platform.cp_user_groups ug
     WHERE ug.delete_status = 'NOT_DELETED' AND ug.is_active AND (ug.is_system = false OR ug.is_system IS NULL)
), held AS NOT MATERIALIZED (
    SELECT ar.tenant_id, ar.user_id, ar.role_id
      FROM core_platform.cp_assign_roles ar
     WHERE ar.delete_status = 'NOT_DELETED' AND ar.is_active AND (ar.is_system = false OR ar.is_system IS NULL)
       AND ar.user_id IS NOT NULL AND ar.role_id IS NOT NULL AND ar.role_id <> ''
    UNION
    SELECT g.tenant_id, g.user_id, ar.role_id
      FROM tgroups g
      JOIN core_platform.cp_assign_roles ar ON ar.tenant_id = g.tenant_id AND ar.group_id = g.group_id
     WHERE ar.delete_status = 'NOT_DELETED' AND ar.is_active AND (ar.is_system = false OR ar.is_system IS NULL)
       AND ar.role_id IS NOT NULL AND ar.role_id <> ''
    UNION
    SELECT u.tenant_id, u.id, sar.role_id
      FROM core_platform.cp_assign_roles sar
      JOIN core_platform.cp_users u ON u.id = sar.user_id
     WHERE sar.tenant_id = 'system-tenant-id' AND sar.is_system AND sar.delete_status = 'NOT_DELETED' AND sar.is_active
       AND sar.role_id IS NOT NULL AND sar.role_id <> ''
    UNION
    SELECT u.tenant_id, u.id, sar.role_id
      FROM core_platform.cp_assign_roles sar
      JOIN core_platform.cp_user_groups sug ON sug.group_id = sar.group_id AND sug.is_system
           AND sug.is_active AND sug.delete_status = 'NOT_DELETED'
      JOIN core_platform.cp_users u ON u.id = sug.user_id
     WHERE sar.tenant_id = 'system-tenant-id' AND sar.is_system AND sar.delete_status = 'NOT_DELETED' AND sar.is_active
       AND sar.role_id IS NOT NULL AND sar.role_id <> ''
), live AS NOT MATERIALIZED (
    SELECT h.tenant_id, h.user_id, h.role_id,
           CASE WHEN r.id IS NOT NULL THEN 'system-tenant-id' ELSE h.tenant_id END AS primary_tenant,
           CASE WHEN r.id IS NOT NULL THEN h.tenant_id ELSE 'system-tenant-id' END AS fallback_tenant
      FROM held h
      JOIN core_platform.cp_users u ON u.id = h.user_id AND u.tenant_id = h.tenant_id
           AND coalesce(u.is_active, true) AND coalesce(u.delete_status, 'NOT_DELETED') = 'NOT_DELETED'
      LEFT JOIN core_platform.cp_roles r ON r.id = h.role_id AND r.is_system AND r.delete_status = 'NOT_DELETED'
), keys AS NOT MATERIALIZED (
    -- the role's own rows
    SELECT l.tenant_id, l.user_id, k.permission
      FROM live l
      JOIN core_platform.cp_role_permissions rp ON rp.role_id = l.role_id AND rp.delete_status = 'NOT_DELETED'
           AND (rp.tenant_id = l.primary_tenant
                OR (rp.tenant_id = l.fallback_tenant
                    AND NOT EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp2
                                     WHERE rp2.role_id = l.role_id AND rp2.tenant_id = l.primary_tenant
                                       AND rp2.delete_status = 'NOT_DELETED')))
      CROSS JOIN LATERAL (VALUES
            (nullif(rp.permission_id, '')),
            (CASE WHEN coalesce(rp.resource_key, '') <> ''
                  THEN concat_ws('|', coalesce(rp.app_prefix, ''), rp.resource_key, coalesce(rp.action, ''),
                                 coalesce(rp.target, ''), coalesce(nullif(rp.scope, ''), 'any')) END)) AS k(permission)
     WHERE k.permission IS NOT NULL
    UNION
    -- Owner, Admin, Core Platform Admin and the app admins, by being the role
    SELECT l.tenant_id, l.user_id,
           concat_ws('|', coalesce(p.app_prefix, ''), p.resource_key, coalesce(p.action, ''),
                     coalesce(p.target, ''), coalesce(nullif(p.scope, ''), 'any'))
      FROM live l
      JOIN core_platform.cp_permissions p ON p.delete_status = 'NOT_DELETED' AND coalesce(p.is_active, true)
           AND coalesce(p.resource_key, '') <> ''
     WHERE l.role_id = 'role-owner'
        OR ((l.role_id = 'role-admin'
             OR (l.role_id = 'role-cp-admin' AND coalesce(p.app_prefix, '') IN ('', 'cp'))
             OR (l.role_id ~ '^role-subscribed-app-[a-z0-9-]+-admin$'
                 AND coalesce(p.app_prefix, '') NOT IN ('', 'cp')
                 AND l.role_id = 'role-subscribed-app-' || p.app_prefix || '-admin'))
            AND NOT (p.resource_key IN ('logs', 'audit')
                     AND NOT EXISTS (SELECT 1 FROM core_platform.cp_actions a WHERE a.action = p.action AND a.is_read_only)))
)
SELECT k.tenant_id, b.id AS bus_id, k.user_id, k.permission
  FROM keys k
  JOIN core_platform.cp_businesses b ON b.tenant_id = k.tenant_id
       AND coalesce(b.delete_status, 'NOT_DELETED') = 'NOT_DELETED' AND coalesce(b.is_active, true);

-- ===================================================================== invariants
DO $$
DECLARE
    tbl text;
    v   record;
BEGIN
    -- 1. Both new permissions have their pair and reach Office Editor.
    IF (SELECT count(*) FROM core_platform.cp_permissions p
         WHERE p.id IN ('permission-office-data-connect', 'permission-office-reviews-manage')
           AND p.app_prefix = 'office' AND (p.resource_key, p.action) IN (('data', 'connect'), ('reviews', 'manage'))
           AND coalesce(p.target, '') = '' AND p.scope = 'any') <> 2 THEN
        RAISE EXCEPTION 'office: office|data|connect||any or office|reviews|manage||any is missing or has no pair';
    END IF;
    IF (SELECT count(*) FROM core_platform.cp_role_permissions rp
          JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
         WHERE rp.role_id = 'role-office-editor' AND p.app_prefix = 'office'
           AND (p.resource_key, p.action) IN (('data', 'connect'), ('reviews', 'manage'))) <> 2 THEN
        RAISE EXCEPTION 'office: Office Editor must hold office|data|connect and office|reviews|manage';
    END IF;
    -- 2. Office Admin still holds no rows of its own app.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions
                WHERE role_id = 'role-subscribed-app-office-admin' AND permission_id LIKE 'permission-office-%') THEN
        RAISE EXCEPTION 'role-subscribed-app-office-admin holds Office permission rows';
    END IF;
    -- 3. The Viewer holds neither.
    IF EXISTS (SELECT 1 FROM core_platform.cp_role_permissions rp
                 JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
                WHERE rp.role_id = 'role-office-viewer' AND p.app_prefix = 'office' AND p.resource_key IN ('data', 'reviews')) THEN
        RAISE EXCEPTION 'role-office-viewer holds office|data or office|reviews';
    END IF;
    -- 4. The tiers.
    IF (SELECT count(*) FROM core_platform.cp_app_feature_catalog
         WHERE app_id = 'app-office' AND is_active
           AND ((feature_key IN ('office.data', 'office.schedules', 'office.esign') AND min_tier_rank = 2)
             OR (feature_key IN ('office.approvals', 'office.offline', 'office.local_templates') AND min_tier_rank = 1))) <> 6 THEN
        RAISE EXCEPTION 'office: R5 features must be office.data, office.schedules, office.esign ADVANCE (2) and office.approvals, office.offline, office.local_templates BASIC (1)';
    END IF;
    -- 5. Every R5 table exists with tenant_id and bus_id.
    FOREACH tbl IN ARRAY ARRAY['data_links', 'schedules', 'schedule_runs', 'reviews', 'review_steps', 'sign_envelopes',
                               'sign_signers', 'sign_fields', 'sign_events', 'document_text', 'link_sends'] LOOP
        IF (SELECT count(*) FROM information_schema.columns
             WHERE table_schema = 'office' AND table_name = 'of_' || tbl AND column_name IN ('tenant_id', 'bus_id')
               AND is_nullable = 'NO') <> 2 THEN
            RAISE EXCEPTION 'office: office.of_% is missing or has no NOT NULL tenant_id and bus_id', tbl;
        END IF;
    END LOOP;
    -- 6. Office never sees pay, bank, tax or identity data from ZelosHR.
    FOR v IN SELECT c.table_name, c.column_name FROM information_schema.columns c
              WHERE c.table_schema = 'office' AND c.table_name LIKE 'src\_zeloshr\_%'
                AND c.column_name ~ '(salary|pay|bank|account|mobile_money|momo|ssnit|tin|tax|ghana_card|id_number|national|phone|address|birth|gps|kin|cost|wage|allowance)' LOOP
        RAISE EXCEPTION 'office: office.% exposes %; Office never reads pay, bank or identity data', v.table_name, v.column_name;
    END LOOP;
    -- 7. Every src_ view carries tenant_id and bus_id.
    FOR v IN SELECT t.table_name FROM information_schema.views t
              WHERE t.table_schema = 'office' AND t.table_name LIKE 'src\_%'
                AND (SELECT count(*) FROM information_schema.columns c
                      WHERE c.table_schema = 'office' AND c.table_name = t.table_name AND c.column_name IN ('tenant_id', 'bus_id')) <> 2 LOOP
        RAISE EXCEPTION 'office: office.% has no tenant_id and bus_id', v.table_name;
    END LOOP;
    -- 8. The permissions view answers (tenant_id, bus_id, user_id, permission).
    IF (SELECT array_agg(column_name::text ORDER BY ordinal_position) FROM information_schema.columns
         WHERE table_schema = 'office' AND table_name = 'src_core_permissions')
       IS DISTINCT FROM ARRAY['tenant_id', 'bus_id', 'user_id', 'permission'] THEN
        RAISE EXCEPTION 'office: office.src_core_permissions must be (tenant_id, bus_id, user_id, permission)';
    END IF;
    -- 9. Versions record approval and signing; a sealed PDF may be saved as a version.
    IF (SELECT count(*) FROM information_schema.columns
         WHERE table_schema = 'office' AND table_name = 'of_document_versions'
           AND column_name IN ('approved_review_id', 'signed', 'signed_envelope_id')) <> 3 THEN
        RAISE EXCEPTION 'office: of_document_versions lacks approved_review_id, signed or signed_envelope_id';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = 'office.of_document_versions'::regclass
                    AND c.conname = 'of_document_versions_reason_check' AND pg_get_constraintdef(c.oid) LIKE '%''sign''%') THEN
        RAISE EXCEPTION 'office: of_document_versions.reason does not admit sign';
    END IF;
END $$;

COMMIT;
