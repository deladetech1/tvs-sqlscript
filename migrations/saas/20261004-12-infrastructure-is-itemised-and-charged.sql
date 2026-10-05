-- =====================================================================================
-- Infrastructure is itemised, and it is CHARGED.
--
-- WHAT 20261004-09 GOT WRONG
-- It recorded ONE figure per silo -- what that silo cost us -- with a free-text note
-- saying what the figure covered. Two things followed, and both were wrong.
--
-- First, it could not be itemised. The table is latest-wins per silo, so entering a
-- second line for the storage account REPLACED the server line rather than adding to
-- it: enter 410 for a server and then 60 for storage, and the screen says the silo costs
-- 60. The free-text "covers" field was an attempt to paper over exactly that, and it is
-- the thing the file itself warned about -- "a number nobody can account for is a number
-- nobody dares correct".
--
-- Second, it was only a cost. We pay for a client's database and storage, and then had
-- no way to bill them for it except by inflating their per-location software price --
-- which prices the wrong thing and tells the client nothing about what they are paying
-- for.
--
-- SO A LINE NOW CARRIES BOTH NUMBERS
-- What it costs us, and what we charge for it. The difference is the margin, per line
-- and per silo, which is the question the screen exists to answer; and the charged
-- amount is raised onto the client's bill through the one mechanism that already bills
-- and already locks an overdue account -- cp_platform_charges in the client's own
-- database. There is no second generator and no second lock.
--
-- WHY NOT JUST USE cp_platform_charges FOR BOTH
-- Because what we PAY must not live in the client's database. cp_platform_charges is in
-- core_platform, which the client's own app reads; control_plane is ours and no tenant
-- app can read it. Putting our cost there would publish our margin to anybody who could
-- read their own invoice.
--
-- WHY MUTABLE, WHEN 20261004-09 WAS APPEND-ONLY
-- The append-only argument was that an invoice must be reprintable after a price
-- changes. That is true and already handled: cp_billings_logs records what was actually
-- raised, with the amount and the rate frozen onto it. The cost side is an estimate we
-- maintain, not a record of a transaction, and versioning it bought history nobody
-- reads at the price of an itemised screen nobody could build.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS control_plane.ctl_silo_charges (
    id        text NOT NULL
              DEFAULT ('silochg_' || replace(gen_random_uuid()::text, '-', '')),

    -- The silo this line belongs to, as ctl_tenant_routes.silo_key names it. No
    -- foreign key: a line may be recorded before the route exists -- the
    -- infrastructure is built before the client is stood up -- and must survive the
    -- route being retired, or the history goes exactly when somebody asks for it.
    silo_key  text NOT NULL,

    -- What this line is. Shown to us AND, when it is charged, to the client on their
    -- invoice -- so it is written for them: "Dedicated database", not a server SKU.
    name      text NOT NULL,
    description text,

    occurrence text NOT NULL DEFAULT 'MONTHLY',

    -- WHAT IT COSTS US. NULL means not recorded, which is different from zero --
    -- zero is a line running on capacity already paid for, and the screen must be
    -- able to say which.
    our_cost  numeric(18,2),

    -- WHAT WE CHARGE THE CLIENT. NULL means we are absorbing it; zero means we
    -- itemise it on their bill at no charge, which is a thing somebody does
    -- deliberately. Both are real answers and a single number could not give both.
    charge    numeric(18,2),

    currency  text NOT NULL DEFAULT 'USD',

    -- The cp_platform_charges row in the CLIENT's database that bills this line.
    -- Written when a charge is set, so changing the amount here finds the row to
    -- change rather than adding a second one. Not a foreign key -- it is in another
    -- database.
    platform_charge_id text,

    is_active boolean NOT NULL DEFAULT true,

    created_by text,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    updated_by text,
    udatetime  timestamptz,

    delete_status text NOT NULL DEFAULT 'NOT_DELETED',

    CONSTRAINT pk_ctl_silo_charges PRIMARY KEY (id),
    CONSTRAINT ck_ctl_silo_charges_name CHECK (length(btrim(name)) > 0),
    CONSTRAINT ck_ctl_silo_charges_cost CHECK (our_cost IS NULL OR our_cost >= 0),
    CONSTRAINT ck_ctl_silo_charges_charge CHECK (charge IS NULL OR charge >= 0),
    CONSTRAINT ck_ctl_silo_charges_currency CHECK (currency ~ '^[A-Z]{3}$'),
    -- The same seven the client's bill accepts. A line that cannot be billed on its
    -- own frequency would have to be re-entered by hand every period.
    CONSTRAINT ck_ctl_silo_charges_occurrence CHECK (
        occurrence IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY',
                       'YEARLY', 'ONE_OFF')
    ),
    -- A line that is neither a cost nor a charge is a note, and this is not a
    -- notebook. One of them has to be a number.
    CONSTRAINT ck_ctl_silo_charges_has_a_figure CHECK (
        our_cost IS NOT NULL OR charge IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS ix_ctl_silo_charges_silo
    ON control_plane.ctl_silo_charges (silo_key, is_active);

COMMENT ON TABLE control_plane.ctl_silo_charges IS
    'One line per piece of a silo''s infrastructure: what it costs us, what we charge '
    'for it, and how often. Replaces the single figure in ctl_silo_costs, which was '
    'latest-wins per silo and so could not be itemised at all.';
COMMENT ON COLUMN control_plane.ctl_silo_charges.our_cost IS
    'What we pay. NULL = not recorded, which is NOT the same as 0 -- zero means it runs '
    'on capacity already paid for, and the screen must be able to say which.';
COMMENT ON COLUMN control_plane.ctl_silo_charges.charge IS
    'What the client pays, raised onto their bill through cp_platform_charges. NULL = we '
    'absorb it; 0 = itemised on their bill at no charge.';

-- ------------------------------------------------- carry the old figures across
-- One line per existing cost row, named from whatever the old free-text note said so
-- nothing anybody typed is lost. Charged nothing: the old table had no notion of
-- charging, and inventing a price here would put money on a client's invoice that
-- nobody agreed.
INSERT INTO control_plane.ctl_silo_charges
    (silo_key, name, description, occurrence, our_cost, currency, created_by, cdatetime)
SELECT c.silo_key,
       COALESCE(NULLIF(btrim(c.covers), ''), 'Infrastructure'),
       CASE WHEN NULLIF(btrim(c.covers), '') IS NULL THEN NULL
            ELSE 'Carried over from the single per-silo cost figure' END,
       'MONTHLY',
       c.monthly_cost,
       c.currency,
       c.recorded_by,
       c.observed_at
  FROM control_plane.ctl_silo_costs_current c
 WHERE NOT EXISTS (
     SELECT 1 FROM control_plane.ctl_silo_charges s
      WHERE s.silo_key = c.silo_key
   )
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------- the itemised view
-- Replaces ctl_silo_margin, which read the one-figure table. Same name kept: the
-- console reads it, and a rename would be a second change to make for no gain.
--
-- DROPPED AND RECREATED, not replaced. CREATE OR REPLACE VIEW may only ADD columns at
-- the end -- the shape here is different, so it refuses with
--
--     cannot change name of view column "monthly_cost" to "tier"
--
-- which is the same wall 20261004-07 hit on the ledger views. There it was worked around
-- by appending; here the whole shape has changed and appending is not available.
--
-- Dropping a view takes its grants with it, so the GRANT block below is what puts them
-- back -- and it has to stay BELOW this, which is why the order of this file matters.
-- 20261004-09 also grants on this view and runs earlier; its grant is applied to the
-- view this drops, and is replaced by the one below on the same deploy.
--
-- No CASCADE. If something else has come to depend on this view, the deploy should stop
-- and say so rather than quietly deleting it.
--
-- Sums the lines. A silo with no lines at all still appears -- that is the row
-- somebody most needs to see, because a silo whose cost is unknown is
-- indistinguishable on a cost-driven list from a silo that does not exist.
DROP VIEW IF EXISTS control_plane.ctl_silo_margin;

CREATE VIEW control_plane.ctl_silo_margin AS
WITH silos AS (
    SELECT DISTINCT r.silo_key, r.tier, r.db_server_fqdn
      FROM control_plane.ctl_tenant_routes r
     WHERE r.silo_key IS NOT NULL
       AND r.status = 'ACTIVE'
       AND r.tier IN ('SILO_SHARED', 'SILO_DEDICATED')
), lines AS (
    SELECT silo_key,
           count(*)                                          AS line_count,
           -- Monthly equivalents, so a yearly line and a monthly one can be added
           -- together at all. NEVER what is billed: the bill raises the real amount
           -- on the real date.
           sum(CASE occurrence
                   WHEN 'DAILY'       THEN COALESCE(our_cost, 0) * 365 / 12
                   WHEN 'WEEKLY'      THEN COALESCE(our_cost, 0) * 52 / 12
                   WHEN 'MONTHLY'     THEN COALESCE(our_cost, 0)
                   WHEN 'QUARTERLY'   THEN COALESCE(our_cost, 0) / 3
                   WHEN 'HALF_YEARLY' THEN COALESCE(our_cost, 0) / 6
                   WHEN 'YEARLY'      THEN COALESCE(our_cost, 0) / 12
                   ELSE 0  -- a one-off is not monthly revenue or monthly cost
               END)                                          AS monthly_cost,
           sum(CASE occurrence
                   WHEN 'DAILY'       THEN COALESCE(charge, 0) * 365 / 12
                   WHEN 'WEEKLY'      THEN COALESCE(charge, 0) * 52 / 12
                   WHEN 'MONTHLY'     THEN COALESCE(charge, 0)
                   WHEN 'QUARTERLY'   THEN COALESCE(charge, 0) / 3
                   WHEN 'HALF_YEARLY' THEN COALESCE(charge, 0) / 6
                   WHEN 'YEARLY'      THEN COALESCE(charge, 0) / 12
                   ELSE 0
               END)                                          AS monthly_charge,
           count(*) FILTER (WHERE our_cost IS NULL)          AS cost_unknown_lines,
           count(*) FILTER (WHERE charge IS NULL)             AS unbilled_lines
      FROM control_plane.ctl_silo_charges
     WHERE is_active AND delete_status = 'NOT_DELETED'
     GROUP BY silo_key
), software AS (
    SELECT silo_key,
           count(*)::bigint    AS tenants,
           sum(mrr)::numeric   AS mrr,
           CASE WHEN count(DISTINCT currency) = 1 THEN max(currency) END AS currency
      FROM control_plane.ctl_billing_customers_current
     WHERE silo_key IS NOT NULL
     GROUP BY silo_key
)
SELECT s.silo_key,
       s.tier,
       s.db_server_fqdn,
       -- HOW MANY SILOS SHARE THIS SERVER.
       --
       -- The trap this answers: on a SHARED server the Microsoft bill covers every
       -- silo on it, so two silos each recording the whole server cost would show us
       -- spending twice what we are charged. Nothing can divide it automatically --
       -- that needs the server's bill, which is a different input -- but the screen
       -- can say "1 of 3" and let somebody see their numbers do not add up.
       -- NULL when the route does not say which server the silo is on, which is
       -- NOT the same as one. A count of 0 came back for such a route and read as
       -- "nothing shares this" -- a false reassurance, when the truth is that we
       -- cannot tell. The screen says "server not recorded" instead.
       CASE WHEN s.db_server_fqdn IS NULL THEN NULL
            ELSE (SELECT count(DISTINCT r2.silo_key)
                    FROM control_plane.ctl_tenant_routes r2
                   WHERE r2.db_server_fqdn = s.db_server_fqdn
                     AND r2.silo_key IS NOT NULL
                     AND r2.status = 'ACTIVE')
       END::bigint                                        AS silos_on_server,
       COALESCE(l.line_count, 0)::bigint                  AS line_count,
       COALESCE(l.monthly_cost, 0)::numeric(18,2)         AS monthly_cost,
       COALESCE(l.monthly_charge, 0)::numeric(18,2)       AS monthly_charge,
       COALESCE(l.cost_unknown_lines, 0)::bigint          AS cost_unknown_lines,
       COALESCE(l.unbilled_lines, 0)::bigint              AS unbilled_lines,
       COALESCE(sw.tenants, 0)                            AS tenants,
       COALESCE(sw.mrr, 0)::numeric(18,2)                 AS mrr,
       sw.currency                                        AS mrr_currency,
       -- What this silo earns us all in -- their software plus what we charge for
       -- their infrastructure -- less what it costs us.
       --
       -- NULL when the software revenue is in a different currency from the lines:
       -- a figure subtracted across two currencies is worse than a blank.
       CASE WHEN l.line_count IS NULL THEN NULL
            WHEN sw.mrr IS NOT NULL AND sw.currency IS DISTINCT FROM 'USD' THEN NULL
            ELSE (COALESCE(sw.mrr, 0) + COALESCE(l.monthly_charge, 0)
                  - COALESCE(l.monthly_cost, 0))::numeric(18,2)
       END                                                AS margin
  FROM silos s
  LEFT JOIN lines l    ON l.silo_key = s.silo_key
  LEFT JOIN software sw ON sw.silo_key = s.silo_key
 ORDER BY (l.line_count IS NULL) DESC, margin NULLS FIRST, s.silo_key;

COMMENT ON VIEW control_plane.ctl_silo_margin IS
    'Per silo: what its infrastructure costs us, what we charge for it, the software '
    'revenue beside it, and the difference. silos_on_server is the shared-server trap: '
    'one Microsoft bill covers every silo on a shared server, so two silos each '
    'recording the whole cost would double-count it.';

-- ----------------------------------------------------------------- grants
DO $$
DECLARE grp text; r text; n integer := 0;
BEGIN
    -- No application group may see what our infrastructure costs. control_plane
    -- grants SELECT on new tables to every app group by default.
    FOR grp IN
        SELECT rolname FROM pg_roles
         WHERE rolname ~ '^tvs_app_[a-z0-9_]+$' AND NOT rolcanlogin
    LOOP
        EXECUTE format('REVOKE ALL ON control_plane.ctl_silo_charges FROM %I', grp);
        EXECUTE format('REVOKE ALL ON control_plane.ctl_silo_margin FROM %I', grp);
    END LOOP;

    -- The console reads and writes it. Same pattern as the ledger: on dev the console
    -- connects as coreplatform_dev, and there is no deladetech_* login -- looking for
    -- one matched nothing and granted no access at all. [a-z0-9]+ excludes the
    -- underscore, so the per-silo logins do not match.
    FOR r IN
        SELECT rolname FROM pg_roles
         WHERE rolcanlogin AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$'
    LOOP
        EXECUTE format(
            'GRANT SELECT, INSERT, UPDATE ON control_plane.ctl_silo_charges TO %I', r);
        EXECUTE format('GRANT SELECT ON control_plane.ctl_silo_margin TO %I', r);
        n := n + 1;
    END LOOP;
    IF n = 0 AND EXISTS (SELECT 1 FROM pg_roles WHERE rolcanlogin
                          AND rolname ~ '^(coreplatform|deladetech)_') THEN
        RAISE EXCEPTION 'console logins exist but none matched the grant pattern';
    END IF;
END $$;

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer;
BEGIN
    IF to_regclass('control_plane.ctl_silo_charges') IS NULL THEN
        RAISE EXCEPTION 'ctl_silo_charges was not created';
    END IF;

    -- UPDATE is granted here, unlike the ledger: the cost side is an estimate we
    -- maintain. What was actually BILLED is on cp_billings_logs and is not touched.
    SELECT count(*) INTO n FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_silo_charges'
       AND privilege_type = 'UPDATE'
       AND grantee ~ '^(coreplatform|deladetech)_[a-z0-9]+$';
    IF n = 0 AND EXISTS (SELECT 1 FROM pg_roles WHERE rolcanlogin
                          AND rolname ~ '^(coreplatform|deladetech)_[a-z0-9]+$') THEN
        RAISE EXCEPTION 'the console cannot change a cost line it is meant to maintain';
    END IF;

    SELECT count(*) INTO n FROM information_schema.role_table_grants
     WHERE table_schema = 'control_plane'
       AND table_name IN ('ctl_silo_charges', 'ctl_silo_margin')
       AND grantee LIKE 'tvs_app%';
    IF n > 0 THEN
        RAISE EXCEPTION 'an application group can see what our infrastructure costs';
    END IF;

    -- A line with neither figure is a note, and this is not a notebook.
    BEGIN
        INSERT INTO control_plane.ctl_silo_charges (silo_key, name) VALUES ('probe', 'x');
        RAISE EXCEPTION 'a line with no cost and no charge was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Zero is allowed on both sides, and means something different from NULL.
    INSERT INTO control_plane.ctl_silo_charges (silo_key, name, our_cost, charge)
    VALUES ('probe', 'Included in the server we already pay for', 0, 0);
    DELETE FROM control_plane.ctl_silo_charges WHERE silo_key = 'probe';

    PERFORM count(*) FROM control_plane.ctl_silo_margin;

    RAISE NOTICE 'infrastructure is itemised, and chargeable';
END $$;
