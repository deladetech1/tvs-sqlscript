-- =====================================================================
-- Who moved a subscription's period, and by how much
-- ---------------------------------------------------------------------
-- cp_app_subscriptions.current_period_end decides whether a tenant may use
-- the platform at all. Until now nothing recorded a change to it.
--
-- That is not hypothetical. On dev, every one of a tenant's eight
-- subscriptions was found sitting exactly one year past where the billing
-- cadence put it — while next_charge_date, which every code path writes in
-- the same statement, still held the correct date thirty days out. No code
-- can make those two disagree, so the year was granted by hand, and there is
-- no way to find out by whom or when. Harmless on dev. The same edit on
-- production is a free year that no screen in the product would ever show.
--
-- Why a trigger and not application logging
-- -----------------------------------------
-- Because application logging would not have caught the thing that prompted
-- this. The API already writes a security event when somebody extends an
-- enterprise subscription through the proper endpoint; what left no trace was
-- a direct UPDATE. A trigger sees the API, the timer job, a migration and a
-- psql session alike, which is the only version of this worth having.
--
-- Naming who
-- ----------
-- Two different claims, and they are recorded separately because they can
-- disagree:
--
--   performed_by      what the writer SAYS — cp_app_subscriptions.updated_by,
--                     but ONLY when this same statement set it. A direct edit
--                     leaves the column alone, so the value sitting there is
--                     whoever touched the row last, possibly months ago; a
--                     first version of this recorded it anyway and cheerfully
--                     attributed a by-hand 365-day grant to the API user that
--                     had done the legitimate renewal before it. Blaming the
--                     wrong party is worse than admitting nobody claimed it,
--                     so an unchanged value is recorded as null and preserved
--                     in `description` instead, where it reads as context
--                     rather than as an accusation.
--   db_user /         who actually connected. The API and the timer job share
--   application_name  a login, so this does not name a person — but it does
--                     separate "the platform did this" from "a human with a
--                     psql prompt did this", which is the distinction that
--                     matters here.
--
-- Neither is trustworthy alone. Together they are enough to ask the right
-- question of the right person.
--
-- days_delta is stored rather than derived on read: it is the figure anybody
-- reviewing this actually wants ("+365 days"), and computing it in a report
-- means every reader re-implements the same subtraction.
--
-- Same shape as the other *_audit_logs tables, so the audit-log reader and the
-- retention purge pick it up unchanged — the purge walks every table in a
-- schema named in core_platform.cp_app_schemas and deletes by tenant_id +
-- cdatetime, and core_platform is registered, so both columns are here and
-- nothing else is needed.
--
-- Idempotent; safe to re-run on every deploy.
-- =====================================================================

CREATE TABLE IF NOT EXISTS core_platform.cp_app_subscription_period_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    entity_id              text        NOT NULL,   -- cp_app_subscriptions.id
    business_id            text,
    app_id                 text,
    action                 text        NOT NULL,   -- PERIOD_EXTENDED | PERIOD_SHORTENED | PERIOD_SET | STATUS_CHANGED

    old_period_start       timestamptz,
    new_period_start       timestamptz,
    old_period_end         timestamptz,
    new_period_end         timestamptz,
    old_next_charge_date   timestamptz,
    new_next_charge_date   timestamptz,
    old_status             text,
    new_status             text,
    --: Whole days the period END moved. Positive is time granted. Null when
    --: there was no end date before, because "granted 400 days" and "set for
    --: the first time" are different events and should not read alike.
    days_delta             integer,

    old_data               jsonb,
    new_data               jsonb,
    description            text,

    --: What the writer claims (cp_app_subscriptions.updated_by).
    performed_by           text,
    --: Who actually connected, and as what. A direct edit has no
    --: performed_by to speak of but always has these.
    db_user                text,
    application_name       text,

    cdate                  text,
    ctime                  text,
    cdatetime              timestamptz DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cp_app_sub_period_audit_scope
    ON core_platform.cp_app_subscription_period_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_app_sub_period_audit_entity
    ON core_platform.cp_app_subscription_period_audit_logs (tenant_id, entity_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_app_sub_period_audit_action
    ON core_platform.cp_app_subscription_period_audit_logs (tenant_id, action, cdatetime DESC);
-- The review query this exists for: "show me every grant of more than a
-- month, newest first." Partial, so it stays small however much ordinary
-- renewal traffic goes through the table.
CREATE INDEX IF NOT EXISTS idx_cp_app_sub_period_audit_large_grants
    ON core_platform.cp_app_subscription_period_audit_logs (tenant_id, cdatetime DESC)
    WHERE days_delta > 31;


CREATE OR REPLACE FUNCTION core_platform.cp_audit_app_subscription_period()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
DECLARE
    v_delta  integer;
    v_action text;
    v_actor  text;
    v_note   text;
BEGIN
    -- Only the fields that decide access and money. An ordinary UPDATE that
    -- touches a description must not write an audit row; a table that logs
    -- everything is a table nobody reads.
    IF NEW.current_period_end IS NOT DISTINCT FROM OLD.current_period_end
       AND NEW.current_period_start IS NOT DISTINCT FROM OLD.current_period_start
       AND NEW.next_charge_date IS NOT DISTINCT FROM OLD.next_charge_date
       AND NEW.status IS NOT DISTINCT FROM OLD.status
    THEN
        RETURN NEW;
    END IF;

    IF OLD.current_period_end IS NULL OR NEW.current_period_end IS NULL THEN
        v_delta := NULL;
    ELSE
        v_delta := (NEW.current_period_end::date - OLD.current_period_end::date);
    END IF;

    -- Only trust updated_by when THIS statement set it. Left untouched, it
    -- names whoever last wrote the row through the API, which for a direct
    -- edit is the one person who definitely did not do this.
    IF NEW.updated_by IS DISTINCT FROM OLD.updated_by THEN
        v_actor := NEW.updated_by;
        v_note  := NULL;
    ELSE
        v_actor := NULL;
        v_note  := CASE
            WHEN NEW.updated_by IS NULL THEN
                'No updated_by was set by this statement.'
            ELSE
                'No updated_by was set by this statement; the column still '
                || 'holds ' || NEW.updated_by || ' from an earlier write.'
        END;
    END IF;

    v_action := CASE
        WHEN OLD.current_period_end IS NULL AND NEW.current_period_end IS NOT NULL
            THEN 'PERIOD_SET'
        WHEN v_delta IS NULL OR v_delta = 0 THEN 'STATUS_CHANGED'
        WHEN v_delta > 0 THEN 'PERIOD_EXTENDED'
        ELSE 'PERIOD_SHORTENED'
    END;

    INSERT INTO core_platform.cp_app_subscription_period_audit_logs (
        tenant_id, entity_id, business_id, app_id, action,
        old_period_start, new_period_start,
        old_period_end, new_period_end,
        old_next_charge_date, new_next_charge_date,
        old_status, new_status, days_delta,
        old_data, new_data, description,
        performed_by, db_user, application_name,
        cdate, ctime, cdatetime
    ) VALUES (
        NEW.tenant_id, NEW.id, NEW.business_id, NEW.app_id, v_action,
        OLD.current_period_start, NEW.current_period_start,
        OLD.current_period_end, NEW.current_period_end,
        OLD.next_charge_date, NEW.next_charge_date,
        OLD.status, NEW.status, v_delta,
        jsonb_build_object(
            'current_period_start', OLD.current_period_start,
            'current_period_end',   OLD.current_period_end,
            'next_charge_date',     OLD.next_charge_date,
            'status',               OLD.status,
            'is_enterprise',        OLD.is_enterprise),
        jsonb_build_object(
            'current_period_start', NEW.current_period_start,
            'current_period_end',   NEW.current_period_end,
            'next_charge_date',     NEW.next_charge_date,
            'status',               NEW.status,
            'is_enterprise',        NEW.is_enterprise),
        v_note,
        v_actor,
        session_user,
        -- Empty rather than null when unset, so the column reads uniformly.
        COALESCE(current_setting('application_name', true), ''),
        to_char(now(), 'YYYY-MM-DD'),
        to_char(now(), 'HH24:MI:SS'),
        now()
    );

    RETURN NEW;
END;
$fn$;


-- AFTER, so a failure to write the audit row cannot roll back a payment that
-- has already been taken at the gateway. It is still inside the same
-- transaction, so the two commit together in the ordinary case; what this
-- buys is that the ordering of blame is right if it ever does not.
DROP TRIGGER IF EXISTS trg_cp_app_subscription_period_audit
    ON core_platform.cp_app_subscriptions;
CREATE TRIGGER trg_cp_app_subscription_period_audit
    AFTER UPDATE ON core_platform.cp_app_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION core_platform.cp_audit_app_subscription_period();
