-- HMS: a business can be more than one kind at once (a resort that also runs a restaurant in
-- town, a landlord with a guest house), and the audit trail can be flagged for review.
--
--   hms_settings.business_types   every kind the business is; business_type stays the one its
--                                  screens are set to now (switched in the app)
--   hms_audit_flags               an entry someone marked for review, and why. The audit rows
--                                  themselves are never changed.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

ALTER TABLE hms.hms_settings ADD COLUMN IF NOT EXISTS business_types text[] NOT NULL DEFAULT '{}';
UPDATE hms.hms_settings SET business_types = ARRAY[business_type]
 WHERE business_type IS NOT NULL AND cardinality(business_types) = 0;

CREATE TABLE IF NOT EXISTS hms.hms_audit_flags (
    audit_id     text PRIMARY KEY REFERENCES hms.hms_audit_logs (id),
    tenant_id    text NOT NULL,
    bus_id       text,
    note         text,
    flagged_by   text,
    cdatetime    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hms_audit_actor_idx ON hms.hms_audit_logs (bus_id, actor_id, cdatetime DESC);

COMMIT;
