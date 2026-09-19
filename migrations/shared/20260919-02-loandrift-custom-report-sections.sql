-- Custom reports gain a home and a picture.
--
-- `section` decides which heading a saved report appears under on the reports
-- screen. It holds either a built-in section id ('loans', 'financial', …) or
-- the id of a row in ld_report_sections, so a tenant can file reports under
-- their own headings without the built-in ones being editable.
--
-- `chart` is the optional visualisation: type, which column runs along the
-- x axis, and which columns are plotted. Null means table only.
ALTER TABLE loandrift.ld_custom_reports
    ADD COLUMN IF NOT EXISTS section text NOT NULL DEFAULT 'loans',
    ADD COLUMN IF NOT EXISTS chart jsonb;

COMMENT ON COLUMN loandrift.ld_custom_reports.section IS
    'Built-in section id or ld_report_sections.id - the heading this report files under.';
COMMENT ON COLUMN loandrift.ld_custom_reports.chart IS
    'Optional chart: {type, x, y[], stacked}. Null renders the table alone.';

CREATE INDEX IF NOT EXISTS ix_ld_custom_reports_section
    ON loandrift.ld_custom_reports (tenant_id, org_id, bus_id, loc_id, section);

-- Tenant-defined report sections, alongside the built-in ones.
CREATE TABLE IF NOT EXISTS loandrift.ld_report_sections (
    tenant_id       text NOT NULL,
    id              text NOT NULL DEFAULT gen_random_uuid()::text,
    org_id          text NOT NULL,
    bus_id          text NOT NULL,
    loc_id          text NOT NULL,
    name            text NOT NULL,
    description     text,
    sort_order      integer NOT NULL DEFAULT 0,
    cdate           text,
    ctime           text,
    cdatetime       timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by      text,
    updated_by      text,
    deleted_by      text,
    delete_status   text NOT NULL DEFAULT 'NOT_DELETED',
    is_active       boolean NOT NULL DEFAULT true,
    CONSTRAINT pk_ld_report_sections PRIMARY KEY (id, tenant_id),
    CONSTRAINT ck_ld_report_sections_delete_status
        CHECK (delete_status IN ('NOT_DELETED', 'DELETED', 'PENDING_DELETION')),
    CONSTRAINT ck_ld_report_sections_name CHECK (length(btrim(name)) BETWEEN 1 AND 60)
);

-- Two sections with the same name at one location would be indistinguishable in
-- the picker, so the live ones are unique per location, case-insensitively.
CREATE UNIQUE INDEX IF NOT EXISTS ux_ld_report_sections_name
    ON loandrift.ld_report_sections (tenant_id, org_id, bus_id, loc_id, lower(btrim(name)))
    WHERE delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_ld_report_sections_scope
    ON loandrift.ld_report_sections (tenant_id, org_id, bus_id, loc_id, sort_order, cdatetime);

COMMENT ON TABLE loandrift.ld_report_sections IS
    'Tenant-defined headings for the reports screen, used alongside the built-in sections.';
