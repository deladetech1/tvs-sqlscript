-- 20260824-07-loandrift-fixed-assets.sql
-- Fixed asset register and depreciation for LoanDrift.
--
-- An asset is registered with what it cost, what it will be worth at the end
-- and how long it lasts; a nightly job charges depreciation for each period
-- that has elapsed and posts it to the journal (20260824-06), so the register,
-- the P&L and the balance sheet cannot disagree.
--
-- Each charge is its own row rather than only a running total on the asset, so
-- the schedule can be shown, a missed period can be caught up, and every charge
-- points at the journal entry that recorded it.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_fixed_assets (
    id                    text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text        NOT NULL,
    org_id                text        NOT NULL,
    bus_id                text        NOT NULL,
    loc_id                text        NOT NULL,

    asset_code            text,
    asset_name            text        NOT NULL,
    category              text,
    serial_number         text,
    supplier              text,
    location_note         text,

    acquisition_date      date        NOT NULL,
    acquisition_cost      numeric(20,6) NOT NULL DEFAULT 0,
    -- What the asset is expected to be worth once fully depreciated.
    -- Depreciation stops here rather than at zero.
    salvage_value         numeric(20,6) NOT NULL DEFAULT 0,
    useful_life_months    integer     NOT NULL DEFAULT 60,

    depreciation_method   text        NOT NULL DEFAULT 'STRAIGHT_LINE',
    -- Only meaningful for REDUCING_BALANCE; the straight-line rate is derived
    -- from the cost, the salvage value and the life.
    depreciation_rate     numeric(9,4),
    -- When depreciation starts, if that is not the acquisition date (an asset
    -- bought in December but commissioned in January).
    depreciation_start    date,

    accumulated_depreciation numeric(20,6) NOT NULL DEFAULT 0,
    net_book_value           numeric(20,6) NOT NULL DEFAULT 0,
    last_depreciated_on      date,

    -- The three accounts the postings hit. Left null, the service falls back to
    -- the seeded system accounts for the location.
    asset_account_id                      text,
    depreciation_expense_account_id       text,
    accumulated_depreciation_account_id   text,

    status                text        NOT NULL DEFAULT 'ACTIVE',
    disposal_date         date,
    disposal_proceeds     numeric(20,6),
    disposal_note         text,

    currency_id           text,
    description           text,
    is_active             boolean     NOT NULL DEFAULT true,
    delete_status         text        NOT NULL DEFAULT 'NOT_DELETED',
    cdate                 text,
    ctime                 text,
    cdatetime             timestamptz DEFAULT NOW(),
    created_by            text,
    updated_by            text,
    deleted_by            text,

    CONSTRAINT ck_ld_fixed_assets_method
        CHECK (depreciation_method IN ('STRAIGHT_LINE','REDUCING_BALANCE','NONE')),
    CONSTRAINT ck_ld_fixed_assets_status
        CHECK (status IN ('ACTIVE','FULLY_DEPRECIATED','DISPOSED','WRITTEN_OFF')),
    CONSTRAINT ck_ld_fixed_assets_delete_status
        CHECK (delete_status IN ('PENDING','DELETED','NOT_DELETED')),
    -- An asset cannot be worth less new than it will be at the end of its life.
    CONSTRAINT ck_ld_fixed_assets_salvage
        CHECK (salvage_value >= 0 AND salvage_value <= acquisition_cost),
    CONSTRAINT ck_ld_fixed_assets_life
        CHECK (useful_life_months > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_fixed_assets_code
    ON loandrift.ld_fixed_assets (tenant_id, org_id, bus_id, loc_id, asset_code)
    WHERE asset_code IS NOT NULL AND delete_status = 'NOT_DELETED';
CREATE INDEX IF NOT EXISTS idx_ld_fixed_assets_scope
    ON loandrift.ld_fixed_assets (tenant_id, org_id, bus_id, loc_id, status);
CREATE INDEX IF NOT EXISTS idx_ld_fixed_assets_category
    ON loandrift.ld_fixed_assets (tenant_id, org_id, bus_id, loc_id, category);

-- One row per asset per depreciation period.
CREATE TABLE IF NOT EXISTS loandrift.ld_asset_depreciation (
    id                    text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text        NOT NULL,
    org_id                text        NOT NULL,
    bus_id                text        NOT NULL,
    loc_id                text        NOT NULL,

    asset_id              text        NOT NULL,
    period_start          date        NOT NULL,
    period_end            date        NOT NULL,
    depreciation_amount   numeric(20,6) NOT NULL DEFAULT 0,
    accumulated_after     numeric(20,6) NOT NULL DEFAULT 0,
    net_book_value_after  numeric(20,6) NOT NULL DEFAULT 0,

    journal_entry_id      text,
    -- BATCH_JOB for the nightly catch-up, MANUAL when an accountant posts one.
    trigger               text        NOT NULL DEFAULT 'BATCH_JOB',

    cdate                 text,
    ctime                 text,
    cdatetime             timestamptz DEFAULT NOW(),
    created_by            text,

    CONSTRAINT ck_ld_asset_depreciation_trigger
        CHECK (trigger IN ('BATCH_JOB','MANUAL')),
    CONSTRAINT ck_ld_asset_depreciation_period
        CHECK (period_end >= period_start)
);

-- The catch-up job re-runs over periods it may already have charged; one row
-- per (asset, period) turns a repeat into a no-op rather than a double charge.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_asset_depreciation_period
    ON loandrift.ld_asset_depreciation (tenant_id, asset_id, period_start);
CREATE INDEX IF NOT EXISTS idx_ld_asset_depreciation_scope
    ON loandrift.ld_asset_depreciation (tenant_id, org_id, bus_id, loc_id, period_end DESC);

-- Audit trail, same shape as the other LoanDrift audit tables (20260802-01).
CREATE TABLE IF NOT EXISTS loandrift.ld_fixed_asset_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text        NOT NULL,
    bus_id                 text        NOT NULL,
    loc_id                 text,
    entity_id              text        NOT NULL,
    entity_name            text,
    action                 text        NOT NULL,
    old_data               jsonb,
    new_data               jsonb,
    description            text,
    performed_by           text,
    performed_by_fullname  text,
    performed_by_email     text,
    performed_by_contact   text,
    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ld_fixed_asset_audit_logs_scope
    ON loandrift.ld_fixed_asset_audit_logs (tenant_id, org_id, bus_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_ld_fixed_asset_audit_logs_entity
    ON loandrift.ld_fixed_asset_audit_logs (tenant_id, entity_id);
