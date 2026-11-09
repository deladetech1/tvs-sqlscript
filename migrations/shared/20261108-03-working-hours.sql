-- Core Platform: working hours -- a business's, and optionally a person's own.
--
-- Apps use them for anything that should happen "during work": when reminders and summaries
-- go out, when customers are messaged, what counts as late. One answer for every app:
--
--   core_platform.cp_effective_working_hours(tenant, bus, user) -> (timezone, days, source)
--     source 'user'     the person's own hours (an override, set on their profile), else
--            'business' the business's hours (Organization > business > Working hours), else
--            'default'  Monday-Friday 08:00-17:00.
--     The time zone falls back the same way, then to the organisation's (cp_timezone_settings),
--     then UTC.
--   core_platform.cp_is_working_time(tenant, bus, user, at) -> boolean
--
-- days is {"mon": {"start": "08:00", "end": "17:00"}, ..., "sun": null}: a day missing or null
-- is not a working day; end after start, same day.
--
-- cp_working_hours holds both: scope 'business' (bus_id set) or 'user' (user_id set; one per
-- person in the organisation, whichever business they are working in).
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS core_platform.cp_working_hours (
    tenant_id   text        NOT NULL,
    id          text        NOT NULL,
    scope       text        NOT NULL CHECK (scope IN ('business', 'user')),
    bus_id      text,
    user_id     text,
    timezone    text,
    days        jsonb       NOT NULL,
    created_by  text,
    updated_by  text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    CHECK ((scope = 'business' AND bus_id IS NOT NULL AND user_id IS NULL)
        OR (scope = 'user' AND user_id IS NOT NULL AND bus_id IS NULL)),
    CHECK (jsonb_typeof(days) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_working_hours_business
    ON core_platform.cp_working_hours (tenant_id, bus_id) WHERE scope = 'business';
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_working_hours_user
    ON core_platform.cp_working_hours (tenant_id, user_id) WHERE scope = 'user';

CREATE OR REPLACE FUNCTION core_platform.cp_default_working_days() RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $f$
    SELECT '{"mon":{"start":"08:00","end":"17:00"},"tue":{"start":"08:00","end":"17:00"},"wed":{"start":"08:00","end":"17:00"},"thu":{"start":"08:00","end":"17:00"},"fri":{"start":"08:00","end":"17:00"},"sat":null,"sun":null}'::jsonb
$f$;

CREATE OR REPLACE FUNCTION core_platform.cp_effective_working_hours(p_tenant text, p_bus text, p_user text)
RETURNS TABLE (timezone text, days jsonb, source text)
LANGUAGE sql STABLE AS $f$
    WITH u AS (SELECT w.timezone, w.days FROM core_platform.cp_working_hours w
                WHERE w.tenant_id = p_tenant AND w.scope = 'user' AND w.user_id = p_user),
         b AS (SELECT w.timezone, w.days FROM core_platform.cp_working_hours w
                WHERE w.tenant_id = p_tenant AND w.scope = 'business' AND w.bus_id = p_bus),
         o AS (SELECT t.timezone FROM core_platform.cp_timezone_settings t
                WHERE t.tenant_id = p_tenant AND coalesce(t.is_active, true) ORDER BY t.cdatetime DESC NULLS LAST LIMIT 1)
    SELECT coalesce((SELECT u.timezone FROM u), (SELECT b.timezone FROM b), (SELECT o.timezone FROM o), 'UTC'),
           coalesce((SELECT u.days FROM u), (SELECT b.days FROM b), core_platform.cp_default_working_days()),
           CASE WHEN EXISTS (SELECT 1 FROM u) THEN 'user' WHEN EXISTS (SELECT 1 FROM b) THEN 'business' ELSE 'default' END
$f$;

CREATE OR REPLACE FUNCTION core_platform.cp_is_working_time(p_tenant text, p_bus text, p_user text, p_at timestamptz)
RETURNS boolean
LANGUAGE plpgsql STABLE AS $f$
DECLARE
    h record;
    local_ts timestamp;
    d jsonb;
BEGIN
    SELECT * INTO h FROM core_platform.cp_effective_working_hours(p_tenant, p_bus, p_user);
    BEGIN
        local_ts := p_at AT TIME ZONE h.timezone;
    EXCEPTION WHEN invalid_parameter_value THEN
        local_ts := p_at AT TIME ZONE 'UTC';
    END;
    d := h.days -> (ARRAY['mon','tue','wed','thu','fri','sat','sun'])[extract(isodow FROM local_ts)::int];
    IF d IS NULL OR jsonb_typeof(d) <> 'object' THEN
        RETURN false;
    END IF;
    RETURN local_ts::time >= (d->>'start')::time AND local_ts::time < (d->>'end')::time;
END;
$f$;

COMMIT;
