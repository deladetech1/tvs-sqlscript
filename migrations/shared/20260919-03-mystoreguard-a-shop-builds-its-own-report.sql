-- A shop builds its own report.
--
-- MyStoreGuard ships about sixty reports, and every one of them answers a
-- question somebody at Trovesuite thought of. A shop wanting "the customers in
-- Kumasi who bought a fridge and still owe me" has to read three screens and a
-- calculator, and the next shop wants something else again.
--
-- So a report becomes a row. A definition names one source of data (store
-- products, customers, loyalty members, sales, and so on), the columns wanted
-- off it, how to filter, group and sort them, and which charts to draw beside
-- the table. The backend owns the catalogue of sources and columns; a
-- definition can only ever name a key from that catalogue, never SQL, so
-- nothing a user types reaches a query as anything but a bound parameter.
--
-- Placement is where the report appears in the app. A shop thinks of a report
-- as belonging somewhere — with sales, with the store, with the warehouse —
-- and a report that lives in a drawer marked "reports" is a report nobody
-- opens. STANDALONE is for the ones that belong to no section.
--
-- Moves no stock, touches no money, and reads nothing it is not shown.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_custom_reports (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    -- The branch it was built at. A report is not locked to it — running one
    -- scopes to the locations the person running it can reach — but it is worth
    -- knowing where it came from.
    loc_id          text,

    name            text        NOT NULL,
    description     text,

    -- Where it shows up: SALES, STORE, WAREHOUSE, INVENTORY, CUSTOMERS,
    -- PURCHASES, FINANCE or STANDALONE. Deliberately not a CHECK constraint:
    -- the app adds sections faster than a migration can, and a placement the
    -- app does not recognise simply falls back to standalone rather than
    -- blocking a save.
    placement       text        NOT NULL DEFAULT 'STANDALONE',
    icon            text,

    -- The catalogue key of what this report reads: 'sales', 'store_products',
    -- 'customers', 'loyalty_members' and so on. Validated against the
    -- catalogue on every save and every run, so a key that stops existing
    -- fails loudly instead of quietly reporting on the wrong thing.
    source_key      text        NOT NULL,

    -- The definition. JSON because its shape is the catalogue's business, not
    -- the database's, and because a column list is read and written whole.
    --   columns   ["product_name", "qty_on_hand", ...]   catalogue keys, in order
    --   filters   [{"column": "...", "operator": "eq", "value": ...}, ...]
    --   group_by  ["category"]
    --   sort      {"column": "...", "direction": "desc"}
    --   charts    [{"type": "bar", "label": "...", "dimension": "...",
    --              "measure": "...", "limit": 10}, ...]
    columns         jsonb       NOT NULL DEFAULT '[]'::jsonb,
    filters         jsonb       NOT NULL DEFAULT '[]'::jsonb,
    group_by        jsonb       NOT NULL DEFAULT '[]'::jsonb,
    sort            jsonb       NOT NULL DEFAULT '{}'::jsonb,
    charts          jsonb       NOT NULL DEFAULT '[]'::jsonb,

    -- Whether a date range applies, and which column it runs on. A report on
    -- what is on the shelf right now has no date range; one on what sold does.
    date_column     text,
    default_days    integer,

    -- Off means only the person who built it sees it. On means everyone in the
    -- business does — which is the point of building one worth keeping.
    is_shared       boolean     NOT NULL DEFAULT true,

    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate           date        NOT NULL DEFAULT CURRENT_DATE,
    ctime           time        NOT NULL DEFAULT CURRENT_TIME,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_by      text,
    deleted_by      text
);

-- One name per business, so a list of reports is a list of distinct things.
-- Deleted rows are excluded: a name should become free again when a report is
-- thrown away.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_custom_reports_name
    ON mystoreguard.msg_custom_reports (tenant_id, org_id, bus_id, lower(name))
    WHERE delete_status = 'NOT_DELETED';

-- The read the app does constantly: every report for a section.
CREATE INDEX IF NOT EXISTS ix_msg_custom_reports_placement
    ON mystoreguard.msg_custom_reports (tenant_id, org_id, bus_id, placement)
    WHERE delete_status = 'NOT_DELETED';

-- Building, changing and throwing away a report is worth an audit trail like
-- any other change, and msg_activity_logs will not take a resource type it has
-- never heard of.
INSERT INTO core_platform.cp_resource_types
    (id, resource_type_name, parent_resource_id, delete_status, is_active, description)
VALUES ('rt-custom-report', 'Custom Reports', 'rt-subscribed-app-msg',
        'NOT_DELETED', true, 'Reports a shop builds for itself in Mystoreguard')
ON CONFLICT (id) DO NOTHING;
