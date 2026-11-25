-- =====================================================================================
-- The storefront assistant: a chat in Ecommerce that edits the shop's own website.
--
-- The owner types ("make the hero say Christmas sale", "hide the About page from the
-- menu"); the AI (Core's gateway, the tenant's own connection) proposes edits from a
-- fixed list; the edits collect in ONE open change set per shop. Nothing live changes
-- until the owner applies it, and an applied set can be undone.
--
--   msg_ecommerce_assistant_changes   the change set: OPEN -> APPLIED | DISCARDED
--                                     (APPLIED -> UNDONE). operations = what will run,
--                                     undo = how to reverse what did run.
--   msg_ecommerce_assistant_messages  the conversation, per shop.
--
-- Every row carries tenant_id/org_id/bus_id and the service reads and writes only by
-- the signed-in person's own tenant and business; ids the AI names are re-checked
-- against that scope before anything runs.
-- Idempotent; safe to re-run.
-- =====================================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_assistant_changes (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    status          text        NOT NULL DEFAULT 'OPEN',
    -- [{op, target, fields, ...}] in the order they run.
    operations      jsonb       NOT NULL DEFAULT '[]'::jsonb,
    -- Written when applied: the reverse of every operation, newest first.
    undo            jsonb,
    applied_at      timestamptz,
    applied_by      text,
    undone_at       timestamptz,
    undone_by       text,

    cdate           date,
    ctime           time,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    deleted_by      text,

    CONSTRAINT ck_msg_ecommerce_assistant_changes_status
        CHECK (status = ANY (ARRAY['OPEN','APPLIED','DISCARDED','UNDONE'])),
    CONSTRAINT ck_msg_ecommerce_assistant_changes_ops
        CHECK (jsonb_typeof(operations) = 'array' AND jsonb_array_length(operations) <= 200)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_ecommerce_assistant_changes_open
    ON mystoreguard.msg_ecommerce_assistant_changes (tenant_id, org_id, bus_id)
    WHERE status = 'OPEN' AND deleted_by IS NULL;

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_assistant_changes_shop
    ON mystoreguard.msg_ecommerce_assistant_changes (tenant_id, org_id, bus_id, cdatetime DESC);

COMMENT ON TABLE mystoreguard.msg_ecommerce_assistant_changes IS
    'Storefront edits proposed by the Ecommerce assistant. OPEN until the shop applies or discards them; one OPEN set per shop.';

CREATE TABLE IF NOT EXISTS mystoreguard.msg_ecommerce_assistant_messages (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    change_id       text        REFERENCES mystoreguard.msg_ecommerce_assistant_changes (id) ON DELETE SET NULL,

    role            text        NOT NULL,
    content         text        NOT NULL,
    -- What this answer added to the change set, as the shop saw it.
    operations      jsonb,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,

    CONSTRAINT ck_msg_ecommerce_assistant_messages_role
        CHECK (role = ANY (ARRAY['user','assistant'])),
    CONSTRAINT ck_msg_ecommerce_assistant_messages_size
        CHECK (char_length(content) <= 8000)
);

CREATE INDEX IF NOT EXISTS ix_msg_ecommerce_assistant_messages_shop
    ON mystoreguard.msg_ecommerce_assistant_messages (tenant_id, org_id, bus_id, cdatetime DESC);

COMMENT ON TABLE mystoreguard.msg_ecommerce_assistant_messages IS
    'The Ecommerce assistant conversation, per shop.';

-- Invariant: a shop has at most one open change set.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM mystoreguard.msg_ecommerce_assistant_changes
                WHERE status = 'OPEN' AND deleted_by IS NULL
                GROUP BY tenant_id, org_id, bus_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'a shop has more than one open assistant change set';
    END IF;
END $$;

COMMIT;
