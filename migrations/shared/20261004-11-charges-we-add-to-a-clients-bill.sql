-- =====================================================================================
-- Charges WE add to a client's bill: the database, the storage account, the container.
--
-- WHY THE BILL NEEDED THIS
-- Everything a client is billed for came from a subscription: price per location per
-- month, times locations, from cp_app_tier_configs. That covers the software and nothing
-- else. A silo client also costs us a database, a storage account and backups, and the
-- only way to recover that was to inflate their per-location price -- which prices the
-- wrong thing (it moves when they open a branch) and tells the client nothing about what
-- they are paying for.
--
-- So: named charges, with their own frequency, that appear on the client's bill beside
-- their subscriptions and are paid the same way.
--
-- WHY IN core_platform AND NOT control_plane
-- The client has to SEE these and pay them, and their billing screens read their own
-- database. control_plane is ours -- the console can read it and no tenant app can --
-- which is right for what a silo costs US (control_plane.ctl_silo_costs) and wrong for
-- what we are charging THEM. The two are deliberately separate: our cost is not their
-- price, and conflating them would publish our margin.
--
-- WHY A DEFINITION AND A GENERATED LINE, NOT ONE ROW
-- A charge recurs. Writing the amount straight onto a bill would mean re-entering it
-- every month and losing the record of what was agreed; writing only the definition
-- would mean an invoice that cannot be reprinted, because next month's rate is not last
-- month's. So this table is the AGREEMENT, and cp_billings_logs holds what was actually
-- raised -- the same split the subscriptions already use, where the tier config is the
-- agreement and a billing log row is the charge.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS core_platform.cp_platform_charges (
    id          text NOT NULL
                DEFAULT ('pcharge_' || replace(gen_random_uuid()::text, '-', '')),
    tenant_id   text NOT NULL,

    -- What the client sees on their bill. Theirs to read, so it is written for
    -- them: "Dedicated database" rather than "silo-itech-pg-flex-b2s".
    name        text NOT NULL,
    description text,

    -- How often it is raised. Spelled out rather than stored as a number of days,
    -- because "monthly" is not 30 days -- a charge raised every 30 days drifts
    -- through the calendar and eventually bills twice in one month, which is the
    -- kind of thing a customer notices before we do.
    occurrence  text NOT NULL,

    -- USD, like every other price on this platform, and the rate it converts at.
    -- Both stored: the rate moves, and an invoice already raised must not.
    amount      numeric(18,2) NOT NULL,
    currency    text NOT NULL DEFAULT 'USD',
    rate        numeric(12,4),

    -- NOT per location. That is the whole point -- a database costs what it costs
    -- whether the client has one branch or nine, and multiplying it by locations
    -- is what the subscription price already does badly.
    --
    -- Optionally attached to a business/app so an invoice can group it sensibly;
    -- NULL means it belongs to the organisation as a whole, which is what a
    -- database charge is.
    business_id text,
    app_id      text,

    is_active   boolean NOT NULL DEFAULT true,

    -- When it next falls due, and when it was last raised. The generator reads the
    -- first and writes both, so a charge cannot be raised twice for one period even
    -- if the generator runs twice -- which it does, because every deploy restarts it.
    next_due_at    timestamptz NOT NULL DEFAULT now(),
    last_billed_at timestamptz,

    -- Who agreed it and when. A charge on somebody's invoice that nobody can
    -- account for is the one kind of billing question that cannot be answered.
    created_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_by  text,
    udatetime   timestamptz,

    delete_status text NOT NULL DEFAULT 'NOT_DELETED',

    CONSTRAINT pk_cp_platform_charges PRIMARY KEY (id),
    -- Free is a real agreement -- a charge waived for a month -- so zero is allowed.
    -- Below zero is not: a bill that pays the customer is never what anybody meant.
    CONSTRAINT ck_cp_platform_charges_amount CHECK (amount >= 0),
    CONSTRAINT ck_cp_platform_charges_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_cp_platform_charges_rate CHECK (rate IS NULL OR rate > 0),
    CONSTRAINT ck_cp_platform_charges_name CHECK (length(btrim(name)) > 0),
    CONSTRAINT ck_cp_platform_charges_occurrence CHECK (
        occurrence IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY',
                       'YEARLY', 'ONE_OFF')
    )
);

-- What the generator asks for on every run: the charges that are due.
CREATE INDEX IF NOT EXISTS ix_cp_platform_charges_due
    ON core_platform.cp_platform_charges (next_due_at)
 WHERE is_active AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_cp_platform_charges_tenant
    ON core_platform.cp_platform_charges (tenant_id, is_active);

COMMENT ON TABLE core_platform.cp_platform_charges IS
    'Charges we add to a client''s bill beyond their subscriptions -- the database, the '
    'storage account, the container. The AGREEMENT; cp_billings_logs holds what was '
    'actually raised. Not per location: a database costs what it costs.';
COMMENT ON COLUMN core_platform.cp_platform_charges.occurrence IS
    'DAILY, WEEKLY, MONTHLY, QUARTERLY, HALF_YEARLY, YEARLY or ONE_OFF. Spelled out '
    'rather than a number of days, because a charge raised every 30 days drifts through '
    'the calendar and eventually bills twice in one month.';
COMMENT ON COLUMN core_platform.cp_platform_charges.next_due_at IS
    'When it next falls due. The generator advances this by one occurrence after '
    'raising, so running twice cannot bill twice -- and every deploy restarts it.';

-- ------------------------------------------------- the billing line it becomes
-- cp_billings_logs already carries a line_type: SUBSCRIPTION for the ordinary case and
-- RETENTION_ADDON for the extended-log add-on. PLATFORM_CHARGE joins them, so every
-- screen that groups a bill by line type picks these up without being taught about
-- them, and -- the point of the exercise -- the outstanding figure and the lockout that
-- reads it already count them.
--
-- A column rather than a constraint: line_type has never been constrained, and adding a
-- CHECK to it now would break the first app that invents a line type of its own, in a
-- table every app writes to.
ALTER TABLE core_platform.cp_billings_logs
    ADD COLUMN IF NOT EXISTS platform_charge_id text;

-- ------------------------------------- a bill line need not be about a location
-- organization_id, business_id, location_id and app_id -- and their _name twins -- are
-- all NOT NULL, because every line there has so far been a SUBSCRIPTION line, and a
-- subscription is per (business, app) deployed to a location.
--
-- A platform charge is not. A dedicated database costs what it costs whether the client
-- has one branch or nine, and there is no location it belongs to. They are foreign keys
-- to real rows, so a placeholder is not available either -- the choice is between
-- attaching the charge to an arbitrary branch, which the invoice would then display, and
-- letting the columns say nothing.
--
-- They say nothing. The client's bill query LEFT JOINs all of them and selects
-- `description` beside them, so a line with no location reads as a line with no
-- location.
--
-- THIS ALSO FIXES A CONTRADICTION THAT WAS ALREADY THERE. Three of those foreign keys
-- are ON DELETE SET NULL against NOT NULL columns:
--
--     FOREIGN KEY (business_id, tenant_id) REFERENCES cp_businesses(id, tenant_id)
--         ON DELETE SET NULL
--
-- so deleting a business would try to NULL a NOT NULL column and fail. The intent was
-- plainly that these are nullable; only the declaration disagreed.
--
-- app_id's key is ON DELETE RESTRICT, where NOT NULL was consistent -- but a charge for
-- a storage account is not about an app either, so it joins them. A nullable foreign key
-- is still a foreign key: NULL means no reference, not a dangling one.
ALTER TABLE core_platform.cp_billings_logs
    ALTER COLUMN organization_id   DROP NOT NULL,
    ALTER COLUMN organization_name DROP NOT NULL,
    ALTER COLUMN business_id       DROP NOT NULL,
    ALTER COLUMN business_name     DROP NOT NULL,
    ALTER COLUMN location_id       DROP NOT NULL,
    ALTER COLUMN location_name     DROP NOT NULL,
    ALTER COLUMN app_id            DROP NOT NULL,
    ALTER COLUMN app_name          DROP NOT NULL;

COMMENT ON COLUMN core_platform.cp_billings_logs.platform_charge_id IS
    'The cp_platform_charges row this line was raised from, for a PLATFORM_CHARGE line. '
    'Lets a client ask what a charge on their invoice was for, and lets the generator '
    'see it has already raised this period.';

CREATE INDEX IF NOT EXISTS ix_cp_billings_logs_platform_charge
    ON core_platform.cp_billings_logs (platform_charge_id, month)
 WHERE platform_charge_id IS NOT NULL;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('core_platform.cp_platform_charges') IS NULL THEN
        RAISE EXCEPTION 'cp_platform_charges was not created';
    END IF;

    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_billings_logs'
       AND column_name = 'platform_charge_id';
    IF n <> 1 THEN
        RAISE EXCEPTION 'cp_billings_logs did not gain platform_charge_id';
    END IF;

    -- A charge with no location must be storable, or none of this works.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_billings_logs'
       AND column_name IN ('organization_id', 'organization_name', 'business_id',
                           'business_name', 'location_id', 'location_name',
                           'app_id', 'app_name')
       AND is_nullable = 'NO';
    IF n > 0 THEN
        RAISE EXCEPTION '% bill-line column(s) still demand a location or an app, '
                        'so a charge for a database cannot be raised', n;
    END IF;

    -- price and line_type must STAY not-null: a line with no amount or no type is
    -- not a bill line, and the outstanding sum would read it as zero.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'core_platform' AND table_name = 'cp_billings_logs'
       AND column_name IN ('price', 'line_type', 'tenant_id')
       AND is_nullable = 'YES';
    IF n > 0 THEN
        RAISE EXCEPTION 'price, line_type or tenant_id became nullable';
    END IF;

    -- A nameless charge on an invoice is unanswerable, so it must be impossible.
    BEGIN
        INSERT INTO core_platform.cp_platform_charges
            (tenant_id, name, occurrence, amount)
        VALUES ('probe', '   ', 'MONTHLY', 10);
        RAISE EXCEPTION 'a charge with a blank name was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- An occurrence nobody can compute a next date from would stall the generator.
    BEGIN
        INSERT INTO core_platform.cp_platform_charges
            (tenant_id, name, occurrence, amount)
        VALUES ('probe', 'Database', 'FORTNIGHTLY', 10);
        RAISE EXCEPTION 'an unknown occurrence was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Zero allowed, negative refused.
    INSERT INTO core_platform.cp_platform_charges
        (tenant_id, name, occurrence, amount)
    VALUES ('probe', 'Waived this month', 'MONTHLY', 0);
    BEGIN
        INSERT INTO core_platform.cp_platform_charges
            (tenant_id, name, occurrence, amount)
        VALUES ('probe', 'Database', 'MONTHLY', -1);
        RAISE EXCEPTION 'a negative charge was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    DELETE FROM core_platform.cp_platform_charges WHERE tenant_id = 'probe';
    SELECT count(*) INTO n FROM core_platform.cp_platform_charges
     WHERE tenant_id = 'probe';
    IF n > 0 THEN
        RAISE EXCEPTION '% probe charge(s) survived', n;
    END IF;

    RAISE NOTICE 'a client''s bill can carry charges beyond their subscriptions';
END $$;
