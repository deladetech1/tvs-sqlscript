-- Where in the world an address is.
--
-- Two things wanted the same missing fact: showing a country beside an IP so a
-- reader can tell "our Accra office" from "somewhere in eastern Europe", and
-- refusing sign-in from countries a tenant never operates in.
--
-- There was no IP-to-country data anywhere in the suite, which is why country
-- rules were left out when the rest of access control shipped. This adds the
-- table; the backend fills it from the five regional registries and refreshes
-- it monthly, because the allocations change and a snapshot baked into a
-- migration would be wrong within weeks and wrong silently.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. The ranges.
-- =====================================================================
-- Around a quarter of a million rows once loaded, from ARIN, RIPE, APNIC,
-- LACNIC and AFRINIC. Small by database standards and static between monthly
-- refreshes, so it is a plain table rather than anything clever.
--
-- Only the two-letter code is stored. The name is a fixed lookup the
-- application owns — storing it per row would repeat "United States" a hundred
-- thousand times and make renaming a country a data migration.
CREATE TABLE IF NOT EXISTS core_platform.cp_ip_country_ranges (
    network      cidr        NOT NULL,
    country_code char(2)     NOT NULL,
    -- Which registry said so. Useful when two disagree, which happens at the
    -- edges of transfers between regions.
    source       text,
    CONSTRAINT pk_cp_ip_country_ranges PRIMARY KEY (network)
);

-- The lookup is "which range contains this address", which is a containment
-- query — GiST with inet_ops is the index that answers it. A btree on network
-- would only help equality, which is never what is asked.
CREATE INDEX IF NOT EXISTS ix_cp_ip_country_ranges_gist
    ON core_platform.cp_ip_country_ranges USING gist (network inet_ops);

CREATE INDEX IF NOT EXISTS ix_cp_ip_country_ranges_code
    ON core_platform.cp_ip_country_ranges (country_code);


-- When the data was last rebuilt, and from what.
--
-- Its own table rather than a column somewhere, because the honest answer to
-- "what country is this address in" depends on how old the answer is, and a
-- screen that shows a country should be able to say when it last checked.
CREATE TABLE IF NOT EXISTS core_platform.cp_ip_country_refresh (
    id           integer     PRIMARY KEY DEFAULT 1,
    refreshed_at timestamptz,
    range_count  integer     NOT NULL DEFAULT 0,
    source       text,
    last_error   text,
    -- Set while a rebuild is running, cleared when it finishes.
    --
    -- Not a lock: the swap is already atomic, so two concurrent rebuilds
    -- cannot corrupt anything. This stops them WASTING — each one downloads
    -- five files and holds a few hundred thousand rows in memory, and the
    -- second one's work is thrown away by definition. A second caller gets an
    -- immediate "already running" instead of a ninety-second wait for a
    -- result somebody else is already producing.
    --
    -- A timestamp rather than a boolean so a crashed rebuild cannot wedge the
    -- feature: the marker is ignored once it is older than the job could be.
    started_at   timestamptz,
    -- One row, always. A history of refreshes is what the logs are for.
    CONSTRAINT ck_cp_ip_country_refresh_single CHECK (id = 1)
);

-- CREATE TABLE IF NOT EXISTS adds nothing to a table that already exists, so
-- the column needs its own guard for environments that ran an earlier copy of
-- this file. Shared migrations re-run on every deploy; this is what makes the
-- second run a no-op rather than an error.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_ip_country_refresh'
           AND column_name = 'started_at'
    ) THEN
        ALTER TABLE core_platform.cp_ip_country_refresh
            ADD COLUMN started_at timestamptz;
    END IF;
END $$;

INSERT INTO core_platform.cp_ip_country_refresh (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;


-- The answer, as one function so every caller agrees.
--
-- Most specific wins. Ranges overlap — a registry allocates a /8 to a country
-- and a /24 inside it is later transferred elsewhere — and the longer prefix
-- is the more recent, more specific truth.
--
-- plpgsql rather than plain SQL for one reason: the argument is text, and
-- `text::inet` RAISES on anything that is not an address. Callers pass values
-- out of audit payloads and request headers, where "unknown" and "" and
-- truncated addresses all occur. A plain-SQL version would abort the whole
-- surrounding query — a report of twenty-five sign-ins returning nothing
-- because one row from two years ago has a bad address in it. An address we
-- cannot read is simply an address with no country.
CREATE OR REPLACE FUNCTION core_platform.cp_country_of_ip(p_ip text)
RETURNS char(2) AS $$
DECLARE
    v_addr inet;
    v_code char(2);
BEGIN
    IF p_ip IS NULL OR btrim(p_ip) = '' THEN
        RETURN NULL;
    END IF;

    BEGIN
        v_addr := btrim(p_ip)::inet;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;

    SELECT country_code INTO v_code
      FROM core_platform.cp_ip_country_ranges
     WHERE network >>= v_addr
     ORDER BY masklen(network) DESC
     LIMIT 1;

    RETURN v_code;
END;
$$ LANGUAGE plpgsql STABLE;


-- =====================================================================
-- 2. Rules that name a country.
-- =====================================================================
-- Added to cp_ip_rules rather than a table of their own: "who may sign in from
-- where" is one question with one answer, and two tables would mean two reads
-- on the sign-in path and two places for the allow/block precedence to drift.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_ip_rules' AND column_name = 'kind'
    ) THEN
        ALTER TABLE core_platform.cp_ip_rules
            ADD COLUMN kind         text    NOT NULL DEFAULT 'NETWORK',
            ADD COLUMN country_code char(2);

        -- A country rule has no network, so the column stops being required.
        ALTER TABLE core_platform.cp_ip_rules ALTER COLUMN network DROP NOT NULL;

        ALTER TABLE core_platform.cp_ip_rules
            ADD CONSTRAINT ck_cp_ip_rules_kind
                CHECK (kind IN ('NETWORK', 'COUNTRY'));

        -- Exactly one of the two, matching the kind. Without this a row could
        -- carry both and the evaluator would have to pick, which is a decision
        -- nobody should be making at read time.
        ALTER TABLE core_platform.cp_ip_rules
            ADD CONSTRAINT ck_cp_ip_rules_target
                CHECK (
                    (kind = 'NETWORK' AND network IS NOT NULL AND country_code IS NULL)
                 OR (kind = 'COUNTRY' AND country_code IS NOT NULL AND network IS NULL)
                );
    END IF;
END $$;

-- The old unique index covered (tenant_id, network) and still does — a NULL
-- network no longer collides, because Postgres treats NULLs as distinct in a
-- unique index. Country rules need their own.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_ip_rules_tenant_country
    ON core_platform.cp_ip_rules (tenant_id, country_code)
    WHERE country_code IS NOT NULL;


-- =====================================================================
-- 3. Country on the things that show an address.
-- =====================================================================
-- Resolved at WRITE time and stored, unlike the name on an event, which is
-- looked up from an id that cannot change. A range CAN be reallocated to a
-- different country, and an event should keep saying where the address was
-- when it happened rather than quietly re-writing history at every refresh.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_security_events' AND column_name = 'country_code'
    ) THEN
        ALTER TABLE core_platform.cp_security_events
            ADD COLUMN country_code char(2);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_user_sessions' AND column_name = 'country_code'
    ) THEN
        ALTER TABLE core_platform.cp_user_sessions
            ADD COLUMN country_code char(2);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_sign_in_sources' AND column_name = 'country_code'
    ) THEN
        ALTER TABLE core_platform.cp_sign_in_sources
            ADD COLUMN country_code char(2);
    END IF;
END $$;

-- Not added to the tamper-evident payload, deliberately. The hash covers what
-- the platform observed; the country is something we looked up afterwards from
-- a dataset that changes, and including it would make every refresh capable of
-- breaking the chain for rows nobody touched.
