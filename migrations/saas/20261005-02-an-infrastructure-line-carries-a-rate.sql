-- =====================================================================================
-- An infrastructure line carries the rate we charge it at.
--
-- ctl_silo_charges holds what a silo costs us (our_cost) and what we charge for it
-- (charge), both USD. It had no rate at all, so the Hosting cost screen could show a
-- client being charged USD 400 a month and never say what that is in the currency the
-- client actually pays in -- and billSiloLine, which copies the line onto their bill as a
-- platform charge, wrote a literal 12.0.
--
-- WHY ONLY ONE RATE, FOR THE CHARGE
-- our_cost deliberately does not get one. What a silo costs US is what Microsoft invoices
-- us, and that is not converted for anybody -- it is read side by side with the charge to
-- see whether a client is worth keeping. A second rate there would invite the question of
-- which one the margin is computed in, when the answer is that both figures are USD and
-- the margin is a subtraction. See [[trovesuite-silo-cost-is-typed-in]].
--
-- WHY NOT NULL WITH A DEFAULT
-- Same reasoning as the platform charge in shared/20261005-01: a charge billed to a
-- client always converts at something, "unknown" is not renderable, and a nullable column
-- is what let a hard-coded 12 live in three files.
--
-- WHY saas/
-- control_plane lives in exactly one database -- the pooled one -- which is the whole
-- point of the push design: a silo reports INTO it. A silo's own copy of control_plane is
-- never read. Same as 20261004-12, which created this table.
-- =====================================================================================

ALTER TABLE control_plane.ctl_silo_charges
    ADD COLUMN IF NOT EXISTS rate numeric(12,4) NOT NULL DEFAULT 12;

COMMENT ON COLUMN control_plane.ctl_silo_charges.rate IS
    'Local currency per USD for the CHARGE on this line -- what the client is asked for '
    'in their own currency is charge * rate. our_cost has no rate on purpose: that is '
    'what we are invoiced, in USD, and is never converted for anybody. Carried through '
    'to cp_platform_charges.rate when the line is put on their bill.';

-- ----------------------------------------------------------------------------- checks
DO $$
DECLARE n integer; probe text;
BEGIN
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_silo_charges'
       AND column_name = 'rate' AND is_nullable = 'NO' AND column_default IS NOT NULL;
    IF n <> 1 THEN
        RAISE EXCEPTION 'ctl_silo_charges.rate is missing, nullable, or has no default';
    END IF;

    -- our_cost must NOT have gained one. If a later change adds a second rate here, the
    -- margin stops being a subtraction and nobody will notice until a silo looks
    -- profitable that is not.
    SELECT count(*) INTO n FROM information_schema.columns
     WHERE table_schema = 'control_plane' AND table_name = 'ctl_silo_charges'
       AND column_name IN ('our_cost_rate', 'cost_rate');
    IF n > 0 THEN
        RAISE EXCEPTION 'a second rate was added for our_cost; the margin is a '
                        'subtraction of two USD figures and must stay one';
    END IF;

    -- A line added without naming rate gets the platform 12 rather than failing. Proved
    -- by doing it: with a NOT NULL in place, "has a default" and "an insert that omits
    -- it works" are different claims.
    INSERT INTO control_plane.ctl_silo_charges
        (id, silo_key, name, occurrence, charge, created_by)
    VALUES ('silocharge_probe_rate', 'probe-silo', 'Probe', 'MONTHLY', 1, 'migration')
    RETURNING rate::text INTO probe;
    IF probe IS NULL OR probe::numeric <> 12 THEN
        RAISE EXCEPTION 'a line added without a rate got %, not the platform 12', probe;
    END IF;
    DELETE FROM control_plane.ctl_silo_charges WHERE id = 'silocharge_probe_rate';

    SELECT count(*) INTO n FROM control_plane.ctl_silo_charges
     WHERE id = 'silocharge_probe_rate' OR silo_key = 'probe-silo';
    IF n > 0 THEN
        RAISE EXCEPTION 'the probe line survived, and would be read as a real silo';
    END IF;

    RAISE NOTICE 'an infrastructure line carries its charge rate';
END $$;
