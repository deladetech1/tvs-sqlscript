-- SCM: the control tower -- what needs a person's attention, and why.
--
--   scm_exceptions   one row per condition the API detects for a business: a stockout risk, a
--                    purchase order overdue, demand nobody allocated, a lot about to expire.
--                    Each row explains itself: detail holds the data used, the expected impact
--                    and a recommendation. Open and acknowledged rows are unique per
--                    fingerprint, so a rescan updates a condition instead of repeating it, and
--                    a condition that cleared is resolved rather than deleted.
--
-- Status lists are CHECK constraints owned by this file. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS scm.scm_exceptions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    kind            text NOT NULL,
    severity        text NOT NULL,
    status          text NOT NULL DEFAULT 'open',
    subject_type    text NOT NULL,
    subject_id      text NOT NULL,
    title           text NOT NULL,
    -- {reason, data_used: {...}, expected_impact, recommendation}
    detail          jsonb NOT NULL DEFAULT '{}',
    impact_amount   numeric(14,2),
    due_at          timestamptz,
    assigned_to     text,
    detected_at     timestamptz NOT NULL DEFAULT now(),
    resolved_at     timestamptz,
    resolved_by     text,
    fingerprint     text NOT NULL,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text
);
ALTER TABLE scm.scm_exceptions DROP CONSTRAINT IF EXISTS scm_exceptions_kind_check;
ALTER TABLE scm.scm_exceptions ADD CONSTRAINT scm_exceptions_kind_check CHECK (kind IN
    ('stockout_risk', 'below_safety_stock', 'po_overdue', 'po_confirmation_overdue',
     'so_unallocated', 'so_late', 'receipt_variance', 'lot_expiring'));
ALTER TABLE scm.scm_exceptions DROP CONSTRAINT IF EXISTS scm_exceptions_severity_check;
ALTER TABLE scm.scm_exceptions ADD CONSTRAINT scm_exceptions_severity_check CHECK (severity IN ('critical', 'high', 'medium', 'low'));
ALTER TABLE scm.scm_exceptions DROP CONSTRAINT IF EXISTS scm_exceptions_status_check;
ALTER TABLE scm.scm_exceptions ADD CONSTRAINT scm_exceptions_status_check CHECK (status IN ('open', 'acknowledged', 'resolved', 'dismissed'));
-- One live row per condition: a rescan upserts on the fingerprint while the row is open or
-- acknowledged; once resolved or dismissed the same condition may be detected again.
CREATE UNIQUE INDEX IF NOT EXISTS scm_exceptions_fingerprint_uq
    ON scm.scm_exceptions (bus_id, fingerprint) WHERE status IN ('open', 'acknowledged');
CREATE INDEX IF NOT EXISTS scm_exceptions_board_idx
    ON scm.scm_exceptions (bus_id, status, severity, due_at);
CREATE INDEX IF NOT EXISTS scm_exceptions_subject_idx
    ON scm.scm_exceptions (bus_id, subject_type, subject_id);

COMMIT;
