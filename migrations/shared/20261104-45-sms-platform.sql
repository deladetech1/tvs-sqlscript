-- MyEduGuard: the platform -- bulk import, the public API and webhooks, and the school's own look.
--
--   sms_import_batches       each spreadsheet brought in: what it was (students, staff, opening
--                            balances, subjects, marks), how many rows went in, and why any did not
--   sms_api_keys             keys other systems read the school's data with: named, limited to
--                            what they may read, shown once and kept only as a hash
--   sms_webhooks             addresses told when something happens (a student enrolled, a payment
--   sms_webhook_deliveries   taken, a report published), each delivery signed, retried and logged
--   sms_profiles.brand       the school's colours and its own web address for the portal
--
-- Idempotent; safe to re-run.

BEGIN;

ALTER TABLE sms.sms_profiles ADD COLUMN IF NOT EXISTS brand jsonb NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS sms.sms_import_batches (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    kind        text NOT NULL,
    file_name   text,
    rows        integer NOT NULL DEFAULT 0,
    added       integer NOT NULL DEFAULT 0,
    failed      integer NOT NULL DEFAULT 0,
    errors      jsonb NOT NULL DEFAULT '[]',
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_import_batches', 'sms_import_batches_kind_check', $q$'marks'$q$, $q$CHECK (kind IN ('students', 'staff', 'balances', 'subjects', 'classes', 'marks'))$q$);
CREATE INDEX IF NOT EXISTS sms_import_batches_profile_idx ON sms.sms_import_batches (profile_id, cdatetime DESC);

CREATE TABLE IF NOT EXISTS sms.sms_api_keys (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    profile_id    text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name          text NOT NULL,
    prefix        text NOT NULL UNIQUE,
    key_hash      text NOT NULL,
    scopes        text[] NOT NULL DEFAULT '{}',
    created_by    text,
    last_used_at  timestamptz,
    revoked_at    timestamptz,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sms.sms_webhooks (
    id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    profile_id  text NOT NULL REFERENCES sms.sms_profiles(id) ON DELETE CASCADE,
    name        text NOT NULL,
    url         text NOT NULL,
    secret      text NOT NULL,
    events      text[] NOT NULL DEFAULT '{}',
    active      boolean NOT NULL DEFAULT true,
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_webhooks_profile_idx ON sms.sms_webhooks (profile_id) WHERE active;

CREATE TABLE IF NOT EXISTS sms.sms_webhook_deliveries (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    webhook_id     text NOT NULL REFERENCES sms.sms_webhooks(id) ON DELETE CASCADE,
    event          text NOT NULL,
    payload        jsonb NOT NULL,
    status         text NOT NULL DEFAULT 'pending',
    attempts       integer NOT NULL DEFAULT 0,
    response_code  integer,
    last_error     text,
    next_at        timestamptz NOT NULL DEFAULT now(),
    delivered_at   timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now()
);
SELECT sms.widen_check('sms.sms_webhook_deliveries', 'sms_webhook_deliveries_status_check', $q$'failed'$q$, $q$CHECK (status IN ('pending', 'delivered', 'failed'))$q$);
CREATE INDEX IF NOT EXISTS sms_webhook_deliveries_due_idx ON sms.sms_webhook_deliveries (next_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS sms_webhook_deliveries_hook_idx ON sms.sms_webhook_deliveries (webhook_id, cdatetime DESC);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('sms.data-import',   'app-sms', 'Data Import & Migration',      1, 'Bulk Excel and CSV import with validation'),
('sms.public-api',    'app-sms', 'Public API',                   2, 'Read the school''s data from other systems with API keys'),
('sms.webhooks',      'app-sms', 'Webhooks',                     2, 'Other systems told the moment something happens'),
('sms.white-label',   'app-sms', 'White Labelling',              3, 'The school''s own colours and web address for its portal and pages'),
('sms.workflows',     'app-sms', 'System Settings & Workflows',  1, 'Numbering, approvals and notifications in one place'),
('sms.help-centre',   'app-sms', 'Help Centre & Onboarding',     1, 'In-app guides and the setup checklist'),
('sms.integrations',  'app-sms', 'Integrations Marketplace',     1, 'Payments, messaging, video, LMS, devices and accounting connected')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
