-- Audit and activity rows drop the password hashes and MFA secrets they were given (2026-10-22).
--
-- Core Platform audited user changes from SELECT * cp_users rows, so the bcrypt
-- login_password hash was stored in the old_data/new_data of
-- core_platform.cp_user_audit_logs and core_platform.cp_activity_logs (found on dev
-- and prod). The writers now redact (tvs-coreplatform-bk caede4c); this removes the
-- copies already stored.
--
-- What it touches, and nothing else:
--   * every base table whose name contains audit_log or activity_log, in any schema,
--     found from the catalog (so silos and new apps are covered);
--   * only their json/jsonb columns;
--   * only rows where one of the keys below, at ANY depth, holds a real value (not
--     null, not '', not the writers' '[REDACTED]' marker);
--   * in those rows it removes exactly those keys, at any depth. Every other key and
--     column is left as it was.
--
-- Idempotent: once a row has no such key it is never selected again, and rows the
-- redacting writers produce ('[REDACTED]') are not selected at all, so re-running on
-- every deploy is a no-op. Ends by asserting the invariant: no updatable audit row
-- still holds one of these values. A table the migrator cannot UPDATE is reported with
-- a WARNING instead of failing the deploy.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.tvs_secret_keys() RETURNS text[] LANGUAGE sql IMMUTABLE AS $f$
    SELECT ARRAY[
        'login_password', 'loginPassword',
        'password', 'Password',
        'password_hash', 'passwordHash', 'hashed_password', 'hashedPassword',
        'new_password', 'newPassword', 'old_password', 'oldPassword',
        'current_password', 'currentPassword', 'confirm_password', 'confirmPassword',
        'password_salt', 'passwordSalt',
        'mfa_secret', 'mfaSecret', 'totp_secret', 'totpSecret', 'otp_secret', 'otpSecret',
        'recovery_codes', 'recoveryCodes', 'mfa_recovery_codes', 'backup_codes', 'backupCodes'
    ]::text[]
$f$;

-- true when a listed key, anywhere in j, holds a real (unredacted) value
CREATE OR REPLACE FUNCTION pg_temp.tvs_holds_secret(j jsonb, keys text[]) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $f$
DECLARE k text; v jsonb;
BEGIN
    IF jsonb_typeof(j) = 'object' THEN
        FOR k, v IN SELECT * FROM jsonb_each(j) LOOP
            IF k = ANY (keys)
               AND jsonb_typeof(v) <> 'null'
               AND v NOT IN ('""'::jsonb, '"[REDACTED]"'::jsonb) THEN
                RETURN true;
            END IF;
            IF pg_temp.tvs_holds_secret(v, keys) THEN RETURN true; END IF;
        END LOOP;
    ELSIF jsonb_typeof(j) = 'array' THEN
        FOR v IN SELECT * FROM jsonb_array_elements(j) LOOP
            IF pg_temp.tvs_holds_secret(v, keys) THEN RETURN true; END IF;
        END LOOP;
    END IF;
    RETURN false;
END $f$;

-- j with every listed key removed at any depth; everything else unchanged
CREATE OR REPLACE FUNCTION pg_temp.tvs_strip_keys(j jsonb, keys text[]) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $f$
DECLARE out jsonb;
BEGIN
    IF jsonb_typeof(j) = 'object' THEN
        SELECT coalesce(jsonb_object_agg(e.key, pg_temp.tvs_strip_keys(e.value, keys)), '{}'::jsonb)
          INTO out
          FROM jsonb_each(j) e
         WHERE e.key <> ALL (keys);
        RETURN out;
    ELSIF jsonb_typeof(j) = 'array' THEN
        SELECT coalesce(jsonb_agg(pg_temp.tvs_strip_keys(a.value, keys) ORDER BY a.ord), '[]'::jsonb)
          INTO out
          FROM jsonb_array_elements(j) WITH ORDINALITY a(value, ord);
        RETURN out;
    END IF;
    RETURN j;
END $f$;

DO $$
DECLARE
    r        record;
    keys     text[] := pg_temp.tvs_secret_keys();
    -- cheap pre-filter on the text form before the exact recursive check
    rx       text := '"(' || array_to_string(pg_temp.tvs_secret_keys(), '|') || ')"\s*:';
    n        bigint;
    total    bigint := 0;
    leftover bigint;
BEGIN
    FOR r IN
        SELECT c.table_schema AS s, c.table_name AS t, c.column_name AS col, c.data_type AS typ,
               format('%I.%I', c.table_schema, c.table_name)::regclass AS rel
          FROM information_schema.columns c
          JOIN information_schema.tables tb USING (table_schema, table_name)
         WHERE tb.table_type = 'BASE TABLE'
           AND c.data_type IN ('json', 'jsonb')
           AND (c.table_name LIKE '%audit_log%' OR c.table_name LIKE '%activity_log%')
           AND c.table_schema NOT IN ('pg_catalog', 'information_schema')
         ORDER BY 1, 2, 3
    LOOP
        IF NOT has_table_privilege(r.rel, 'UPDATE') THEN
            RAISE WARNING '20261022-01: cannot UPDATE %.% -- secrets in %, if any, left in place', r.s, r.t, r.col;
            CONTINUE;
        END IF;

        EXECUTE format(
            'UPDATE %1$I.%2$I SET %3$I = pg_temp.tvs_strip_keys(%3$I::jsonb, $1)::%4$s
              WHERE %3$I IS NOT NULL
                AND %3$I::text ~ $2
                AND pg_temp.tvs_holds_secret(%3$I::jsonb, $1)',
            r.s, r.t, r.col, r.typ)
        USING keys, rx;
        GET DIAGNOSTICS n = ROW_COUNT;
        IF n > 0 THEN
            RAISE NOTICE '20261022-01: removed secret keys from % row(s) of %.%.%', n, r.s, r.t, r.col;
            total := total + n;
        END IF;

        EXECUTE format(
            'SELECT count(*) FROM %1$I.%2$I
              WHERE %3$I IS NOT NULL AND %3$I::text ~ $2
                AND pg_temp.tvs_holds_secret(%3$I::jsonb, $1)',
            r.s, r.t, r.col)
        INTO leftover USING keys, rx;
        IF leftover > 0 THEN
            RAISE EXCEPTION '20261022-01: % row(s) of %.%.% still hold a secret key', leftover, r.s, r.t, r.col;
        END IF;
    END LOOP;
    RAISE NOTICE '20261022-01: % audit/activity value(s) cleaned', total;
END $$;

COMMIT;
