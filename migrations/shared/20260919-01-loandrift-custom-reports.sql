-- Custom report builder: saved report definitions.
--
-- A definition is the user's choice of source, columns, filters, grouping and
-- sorting, stored as JSON. It holds only *ids* from the server-side catalog
-- (see cr_catalog.py) - never SQL - so a stored definition cannot be a
-- injection vector on replay.
CREATE TABLE IF NOT EXISTS loandrift.ld_custom_reports (
    tenant_id       text NOT NULL,
    id              text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id          text NOT NULL,
    bus_id          text NOT NULL,
    loc_id          text NOT NULL,
    name            text NOT NULL,
    description     text,
    definition      jsonb NOT NULL,
    is_shared       boolean NOT NULL DEFAULT false,
    cdate           text,
    ctime           text,
    cdatetime       timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by      text,
    updated_by      text,
    deleted_by      text,
    delete_status   text NOT NULL DEFAULT 'NOT_DELETED',
    is_active       boolean NOT NULL DEFAULT true,
    CONSTRAINT pk_ld_custom_reports PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_custom_reports_delete_status
        CHECK (delete_status IN ('NOT_DELETED', 'DELETED', 'PENDING_DELETION'))
);

-- The list query filters by the full location scope and the author, and orders
-- by recency.
CREATE INDEX IF NOT EXISTS ix_ld_custom_reports_scope
    ON loandrift.ld_custom_reports (tenant_id, org_id, bus_id, loc_id, cdatetime DESC);

CREATE INDEX IF NOT EXISTS ix_ld_custom_reports_created_by
    ON loandrift.ld_custom_reports (created_by, tenant_id);

COMMENT ON TABLE loandrift.ld_custom_reports IS
    'User-built report definitions for the custom report builder.';
COMMENT ON COLUMN loandrift.ld_custom_reports.definition IS
    'Catalog field ids only - source, columns, filters, group_by, aggregations, sort, limit.';
COMMENT ON COLUMN loandrift.ld_custom_reports.is_shared IS
    'When true, everyone at this location can run it; only the author can edit it.';
