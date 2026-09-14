-- Per-user read state for live, permission-scoped LoanDrift notifications.
CREATE TABLE IF NOT EXISTS loandrift.ld_notification_reads (
    tenant_id text NOT NULL,
    org_id text NOT NULL,
    bus_id text NOT NULL,
    loc_id text NOT NULL,
    user_id text NOT NULL,
    event_id text NOT NULL,
    read_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, org_id, bus_id, loc_id, user_id, event_id)
);
