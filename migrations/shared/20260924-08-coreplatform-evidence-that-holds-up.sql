-- Evidence that holds up, somewhere else to send it, and a key to fetch it with.
--
-- The three things an enterprise buyer asks for that the rest of this section
-- does not answer:
--
--   1. "How do I know these records were not edited afterwards?"
--   2. "Can they go to my SIEM instead of me logging in to look?"
--   3. "Can a machine fetch them without a person's password?"
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. A chain over the security events.
-- =====================================================================
-- Each row carries the hash of the one before it, so changing an old row
-- invalidates every row after it and the break is detectable.
--
-- What this does and does not do, stated plainly because the difference is
-- what somebody is actually buying: it makes retrospective editing DETECTABLE.
-- It does not prevent it. Anybody with UPDATE on this table can still change a
-- row; they simply cannot do it without the chain saying so, unless they
-- recompute every subsequent hash — which is possible for somebody with full
-- database access and is why the honest claim is "tamper-evident", never
-- "tamper-proof".
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'core_platform'
           AND table_name = 'cp_security_events'
           AND column_name = 'row_hash'
    ) THEN
        ALTER TABLE core_platform.cp_security_events
            -- Per tenant, so a chain can be verified on its own and one
            -- tenant's retention purge cannot break another's.
            ADD COLUMN chain_seq  bigint,
            ADD COLUMN prev_hash  text,
            ADD COLUMN row_hash   text;
    END IF;
END $$;

-- The order the chain is walked in, and the lookup for "the previous row".
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_security_events_chain
    ON core_platform.cp_security_events (tenant_id, chain_seq)
    WHERE chain_seq IS NOT NULL;


-- What the hash covers, and — just as importantly — what it does not.
--
-- The content is covered: who, what, when, from where. The TRIAGE columns are
-- not. status, status_note and status_changed_* exist to be changed; if the
-- hash covered them, acknowledging an event would break the chain and the
-- verifier would report tampering every time somebody did their job.
--
-- So the claim this chain supports is exact: "the record of what happened has
-- not been altered". Who has since looked at it is a separate, mutable fact,
-- and its own history is in cp_activity_logs.
CREATE OR REPLACE FUNCTION core_platform.cp_security_event_payload(
    p_id text, p_tenant_id text, p_app_id text, p_category text,
    p_event_type text, p_severity text, p_title text, p_description text,
    p_actor_user_id text, p_subject_user_id text, p_ip_address text,
    p_user_agent text, p_metadata jsonb, p_occurred_at timestamptz
) RETURNS text AS $$
    -- Null and empty string must not hash alike, or a row could be edited from
    -- one to the other undetected, so NULL becomes \x1e (record separator).
    -- \x1f (unit separator) delimits fields: neither can appear in the values,
    -- so content cannot be shifted across a field boundary to collide.
    --
    -- NOT \x00 — Postgres text cannot hold a NUL byte, and convert_to() raises
    -- on one rather than hashing it.
    SELECT concat_ws(
        E'\x1f',
        coalesce(p_id, E'\x1e'), coalesce(p_tenant_id, E'\x1e'),
        coalesce(p_app_id, E'\x1e'), coalesce(p_category, E'\x1e'),
        coalesce(p_event_type, E'\x1e'), coalesce(p_severity, E'\x1e'),
        coalesce(p_title, E'\x1e'), coalesce(p_description, E'\x1e'),
        coalesce(p_actor_user_id, E'\x1e'), coalesce(p_subject_user_id, E'\x1e'),
        coalesce(p_ip_address, E'\x1e'), coalesce(p_user_agent, E'\x1e'),
        -- jsonb::text is normalised by Postgres (keys sorted, whitespace gone),
        -- so the same object always renders the same way.
        coalesce(p_metadata::text, E'\x1e'),
        coalesce(to_char(p_occurred_at AT TIME ZONE 'UTC',
                         'YYYY-MM-DD"T"HH24:MI:SS.US'), E'\x1e')
    );
$$ LANGUAGE sql IMMUTABLE;


-- A trigger rather than application code, deliberately.
--
-- MyStoreGuard and LoanDrift each carry their own writer against this table.
-- Chaining in Core Platform's writer would leave their rows unchained, and a
-- chain with holes in it proves nothing. A trigger also means a writer cannot
-- forget, and cannot be bypassed by a future one.
CREATE OR REPLACE FUNCTION core_platform.cp_chain_security_event()
RETURNS trigger AS $$
DECLARE
    v_prev_hash text;
    v_prev_seq  bigint;
BEGIN
    -- Two events arriving at once would otherwise both read the same previous
    -- row and fork the chain. The lock is per tenant and held to the end of
    -- the transaction; it serialises writes for one tenant only, which is the
    -- rate a single tenant generates security events — not a bottleneck.
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.tenant_id, 0));

    SELECT row_hash, chain_seq INTO v_prev_hash, v_prev_seq
      FROM core_platform.cp_security_events
     WHERE tenant_id = NEW.tenant_id AND chain_seq IS NOT NULL
     ORDER BY chain_seq DESC
     LIMIT 1;

    NEW.chain_seq := coalesce(v_prev_seq, 0) + 1;
    -- The genesis row's predecessor is a fixed string rather than NULL, so
    -- "this is the first row" and "this row's link is missing" are different
    -- states the verifier can tell apart.
    NEW.prev_hash := coalesce(v_prev_hash, 'genesis');
    NEW.row_hash := encode(
        sha256(convert_to(
            core_platform.cp_security_event_payload(
                NEW.id, NEW.tenant_id, NEW.app_id, NEW.category,
                NEW.event_type, NEW.severity, NEW.title, NEW.description,
                NEW.actor_user_id, NEW.subject_user_id, NEW.ip_address,
                NEW.user_agent, NEW.metadata, NEW.occurred_at
            ) || E'\x1f' || NEW.prev_hash,
            'UTF8'
        )), 'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cp_security_events_chain
    ON core_platform.cp_security_events;
CREATE TRIGGER trg_cp_security_events_chain
    BEFORE INSERT ON core_platform.cp_security_events
    FOR EACH ROW EXECUTE FUNCTION core_platform.cp_chain_security_event();

-- The chain verifier USED to be defined here.
--
-- It now lives in 20260925-02-coreplatform-say-what-broke-in-english.sql,
-- which changed its OUT columns to return a stable reason_code alongside the
-- prose. Two files cannot both define it: shared migrations re-run in
-- filename order on EVERY deploy, so this older file would recreate the older
-- signature moments before the newer one replaced it — and `CREATE OR REPLACE`
-- refuses to change a function's return type, which took a deploy down with
-- "42P13: cannot change return type of existing function".
--
-- Removed rather than guarded: a function with one owner is the only version
-- of this that stays true. See that file for the definition.


-- =====================================================================
-- 2. Sending events somewhere else.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_security_webhooks (
    id             text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text        NOT NULL,

    label          text,
    url            text        NOT NULL,
    -- Used to sign every delivery. The receiver recomputes the signature and
    -- so knows the payload came from us and was not altered in flight —
    -- without which a webhook endpoint accepts anything anybody posts to it.
    signing_secret text        NOT NULL,

    -- Which events are worth sending. Empty means all of them.
    min_severity   text        NOT NULL DEFAULT 'WARNING',
    categories     text[],

    is_enabled     boolean     NOT NULL DEFAULT true,

    -- Set when deliveries keep failing, so a dead endpoint stops costing a
    -- request per event for ever. Cleared by a successful delivery.
    failing_since  timestamptz,
    last_error     text,
    last_success   timestamptz,

    description    text,
    cdate          text,
    ctime          text,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_by     text,

    CONSTRAINT ck_cp_security_webhooks_severity
        CHECK (min_severity IN ('CRITICAL', 'WARNING', 'INFO')),
    CONSTRAINT fk_cp_security_webhooks_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_cp_security_webhooks_tenant
    ON core_platform.cp_security_webhooks (tenant_id, is_enabled);


-- One row per attempt to deliver one event to one endpoint.
--
-- A queue AND the delivery log, on purpose: "what is waiting to go" and "what
-- happened to it" are the same question asked at two moments, and splitting
-- them would mean writing the row twice and reconciling them later.
CREATE TABLE IF NOT EXISTS core_platform.cp_security_webhook_deliveries (
    id            bigserial   PRIMARY KEY,
    tenant_id     text        NOT NULL,
    webhook_id    text        NOT NULL,
    event_id      text        NOT NULL,

    status        text        NOT NULL DEFAULT 'PENDING',
    attempts      integer     NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),

    response_code integer,
    error         text,

    created_at    timestamptz NOT NULL DEFAULT now(),
    delivered_at  timestamptz,

    CONSTRAINT ck_cp_security_webhook_deliveries_status
        CHECK (status IN ('PENDING', 'DELIVERED', 'FAILED', 'ABANDONED')),
    CONSTRAINT fk_cp_swd_webhook
        FOREIGN KEY (webhook_id) REFERENCES core_platform.cp_security_webhooks (id)
        ON DELETE CASCADE
);

-- The dispatcher's only query: what is due, oldest first.
CREATE INDEX IF NOT EXISTS ix_cp_swd_due
    ON core_platform.cp_security_webhook_deliveries (next_attempt_at)
    WHERE status = 'PENDING';

-- The screen's query: what happened to this endpoint lately.
CREATE INDEX IF NOT EXISTS ix_cp_swd_webhook
    ON core_platform.cp_security_webhook_deliveries (webhook_id, created_at DESC);

-- One delivery per (webhook, event). Without this a retry that raced with the
-- enqueue would send the same event twice, and a SIEM counting events would be
-- wrong in the direction that causes a false alarm.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_swd_once
    ON core_platform.cp_security_webhook_deliveries (webhook_id, event_id);

-- Delivered rows are of no use after a week; the event itself is the record.
CREATE OR REPLACE FUNCTION core_platform.cp_prune_webhook_deliveries()
RETURNS integer AS $$
DECLARE v_deleted integer;
BEGIN
    DELETE FROM core_platform.cp_security_webhook_deliveries
     WHERE status IN ('DELIVERED', 'ABANDONED')
       AND created_at < now() - interval '7 days';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- 3. Keys for machines.
-- =====================================================================
CREATE TABLE IF NOT EXISTS core_platform.cp_api_keys (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,

    label         text        NOT NULL,

    -- The first characters, in clear, so a key can be identified in a list and
    -- in a log without being usable. The rest exists only as a hash.
    key_prefix    text        NOT NULL,
    -- SHA-256, not bcrypt. A bcrypt work factor defends a LOW-entropy secret
    -- against offline guessing; these are 256 bits of randomness, where
    -- guessing is not a threat model, and bcrypt would add its cost to every
    -- machine request for nothing.
    key_hash      text        NOT NULL,

    -- What the key may do. Narrow by design: a key that can read events should
    -- not be able to change a setting.
    scopes        text[]      NOT NULL DEFAULT ARRAY['events:read'],

    expires_at    timestamptz,
    last_used_at  timestamptz,
    last_used_ip  text,

    revoked_at    timestamptz,
    revoked_by    text,

    cdate         text,
    ctime         text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    created_by    text,

    CONSTRAINT fk_cp_api_keys_cp_tenants_tenant_id
        FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants (id) ON DELETE CASCADE
);

-- The lookup on every machine request.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cp_api_keys_hash
    ON core_platform.cp_api_keys (key_hash);

CREATE INDEX IF NOT EXISTS ix_cp_api_keys_tenant
    ON core_platform.cp_api_keys (tenant_id, revoked_at);

CREATE TABLE IF NOT EXISTS core_platform.cp_api_keys_audit_logs (
    id                     text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text        NOT NULL,
    org_id                 text,
    bus_id                 text,
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

CREATE INDEX IF NOT EXISTS idx_cp_api_keys_audit_logs_scope
    ON core_platform.cp_api_keys_audit_logs (tenant_id, cdatetime DESC);
CREATE INDEX IF NOT EXISTS idx_cp_api_keys_audit_logs_action
    ON core_platform.cp_api_keys_audit_logs (tenant_id, action);


-- =====================================================================
-- 4. Backfilling the chain.
-- =====================================================================
-- Events written before the trigger existed have no hash. Leaving them unhashed
-- would make the verifier report a break at the boundary for every tenant that
-- has ever had an event, which is a red light meaning nothing.
--
-- They are chained now, in their existing order. This proves nothing about what
-- happened before this migration ran — a row altered yesterday is being hashed
-- in its altered state — and that is the honest position: the chain attests to
-- everything from here on.
DO $$
DECLARE
    r      record;
    v_prev text;
    v_seq  bigint;
    v_tenant text := NULL;
BEGIN
    FOR r IN
        SELECT * FROM core_platform.cp_security_events
         WHERE chain_seq IS NULL
         ORDER BY tenant_id, occurred_at, id
    LOOP
        IF v_tenant IS DISTINCT FROM r.tenant_id THEN
            v_tenant := r.tenant_id;
            SELECT row_hash, chain_seq INTO v_prev, v_seq
              FROM core_platform.cp_security_events
             WHERE tenant_id = v_tenant AND chain_seq IS NOT NULL
             ORDER BY chain_seq DESC LIMIT 1;
            v_seq := coalesce(v_seq, 0);
            v_prev := coalesce(v_prev, 'genesis');
        END IF;

        v_seq := v_seq + 1;
        UPDATE core_platform.cp_security_events
           SET chain_seq = v_seq,
               prev_hash = v_prev,
               row_hash = encode(sha256(convert_to(
                   core_platform.cp_security_event_payload(
                       r.id, r.tenant_id, r.app_id, r.category, r.event_type,
                       r.severity, r.title, r.description, r.actor_user_id,
                       r.subject_user_id, r.ip_address, r.user_agent,
                       r.metadata, r.occurred_at
                   ) || E'\x1f' || v_prev, 'UTF8')), 'hex')
         WHERE id = r.id
        RETURNING row_hash INTO v_prev;
    END LOOP;
END $$;
