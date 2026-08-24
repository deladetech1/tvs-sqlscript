-- =====================================================================
-- Custom fields: extra questions a shop wants on its own records
-- ---------------------------------------------------------------------
-- Every business tracks something the product does not model — a customer's
-- TIN, a product's shelf, the rep who won an order. Today that goes in the
-- description box and stops being data.
--
-- Two tables. Definitions say what a field IS and which module it appears on;
-- values hold what was entered against one record. Keeping them apart means a
-- field can be renamed or retired without touching what people already typed,
-- and a module gains fields without a migration.
--
-- Values are stored as text whatever the field's type. The type governs the
-- input shown and how the value is read back; storing a date as a date column
-- would mean a column per type and a union to read them. Text keeps one table,
-- and the definition is always at hand to interpret it.
--
-- Runs after the EF migrations on every deploy. Idempotent; safe to re-run.
-- =====================================================================

CREATE TABLE IF NOT EXISTS mystoreguard.msg_custom_fields (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,

    -- Which modules the field appears on: 'customers', 'products', 'sales'…
    -- A list, because the same question is often asked in several places — a
    -- "Region" on customers and on sales is one field with one set of answers
    -- to report on, not two that happen to share a name. Text values rather
    -- than an enum so a new module needs code, not a migration.
    modules       text[]      NOT NULL DEFAULT '{}',

    label         text        NOT NULL,
    -- Stable machine name, derived from the label when first created. The label
    -- can be reworded afterwards without orphaning the values already entered.
    field_key     text        NOT NULL,

    field_type    text        NOT NULL DEFAULT 'TEXT',
    is_required   boolean     NOT NULL DEFAULT false,
    -- Choices for SELECT. Empty for every other type.
    options       text[]      NOT NULL DEFAULT '{}',
    help_text     text,

    -- Order shown on the form. Ties are broken by label so the list is stable.
    sort_order    integer     NOT NULL DEFAULT 0,
    -- Retired rather than deleted: switching a field off hides it from forms
    -- while the answers already given stay readable on old records.
    is_active     boolean     NOT NULL DEFAULT true,

    delete_status text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate         date,
    ctime         time,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    udatetime     timestamptz,
    created_by    text,
    updated_by    text,

    CONSTRAINT ck_msg_custom_fields_type
        CHECK (field_type IN ('TEXT', 'TEXTAREA', 'NUMBER', 'DATE', 'SELECT', 'BOOLEAN'))
);

-- One field per name per business, not per module: a field that spans modules
-- is ONE field, so a second definition sharing its key would be a duplicate
-- wherever they overlapped and would split its answers in the report.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_custom_fields_key
    ON mystoreguard.msg_custom_fields (tenant_id, org_id, bus_id, field_key)
    WHERE delete_status = 'NOT_DELETED';

-- "Which fields belong on this form" runs on every form open, and against an
-- array that means a containment test, which needs GIN to stay off a scan.
CREATE INDEX IF NOT EXISTS idx_msg_custom_fields_modules
    ON mystoreguard.msg_custom_fields USING GIN (modules);

CREATE INDEX IF NOT EXISTS idx_msg_custom_fields_scope
    ON mystoreguard.msg_custom_fields (tenant_id, org_id, bus_id, is_active);


CREATE TABLE IF NOT EXISTS mystoreguard.msg_custom_field_values (
    id          text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id   text        NOT NULL,
    org_id      text        NOT NULL,
    bus_id      text        NOT NULL,

    field_id    text        NOT NULL,
    -- Which module this answer was given on, and against which record. Both are
    -- needed because one field can span modules: the same field answered on a
    -- customer and on a sale are different answers, and record ids are only
    -- unique within their own module.
    module      text        NOT NULL,
    record_id   text        NOT NULL,

    value       text,

    cdate       date,
    ctime       time,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    udatetime   timestamptz,
    created_by  text,
    updated_by  text,

    CONSTRAINT fk_msg_custom_field_values_field
        FOREIGN KEY (field_id)
        REFERENCES mystoreguard.msg_custom_fields (id)
        ON DELETE CASCADE
);

-- One answer per field per record.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_custom_field_values_record
    ON mystoreguard.msg_custom_field_values (tenant_id, org_id, bus_id, field_id, module, record_id);

-- The report groups answers by field, optionally narrowed to one module.
CREATE INDEX IF NOT EXISTS idx_msg_custom_field_values_field
    ON mystoreguard.msg_custom_field_values (tenant_id, org_id, bus_id, field_id, module);

-- Reading a record's answers is the query that runs on every form open.
CREATE INDEX IF NOT EXISTS idx_msg_custom_field_values_record
    ON mystoreguard.msg_custom_field_values (tenant_id, org_id, bus_id, module, record_id);
