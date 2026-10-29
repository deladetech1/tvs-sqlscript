-- Manufacturing: engineering change (design: docs/mfg/03-database-model.md §3.5 Engineering change;
-- 02-domain-model.md §2, §6; contract R2.md §1.6, C8).
--
--   mfg_ecos            an engineering change request (ecr) or order (eco): draft -> submitted ->
--                       approved -> implemented, or rejected | cancelled. source_ncr_id when an NCR
--                       line's needs_engineering_change disposition opened it (R-8). Effectivity:
--                       date (effective_on) | serial | lot (effectivity_ref) | use_up
--   mfg_eco_items       what it changes: an item revision, BOM, routing, work instruction or
--                       inspection plan, from one revision to the next (to_revision_id is the new
--                       draft revision; implementing releases it), with what happens to stock and
--                       open orders
--   mfg_eco_impacts     APPEND-ONLY; the impact report (where-used, stock, open orders, open
--                       planned orders, cost) as computed. Recomputing adds a row; the row written
--                       on submit is_frozen and is the one approval sees
--   mfg_eco_approvals   APPEND-ONLY; each approval decision (approve | reject) with its comment
--
-- Implementing an ECO writes the new revisions released (and supersedes the old ones) through the
-- R1 engineering tables, whose eco_id columns name the ECO.
--
-- Product ids are registered for merges in 20261030-20. The CHECK lists live in 20261030-19. No
-- grants. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS mfg.mfg_ecos (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text,
    bus_id             text NOT NULL,
    plant_id           text REFERENCES mfg.mfg_plants (id),
    number             text NOT NULL,              -- ECO-00042 (mfg_number_series kind eco)
    kind               text NOT NULL DEFAULT 'eco',
    title              text NOT NULL,
    reason             text NOT NULL,
    description        text,
    source_ncr_id      text,                       -- mfg_ncrs id (R-8)
    urgency            text NOT NULL DEFAULT 'normal',
    effectivity        text NOT NULL DEFAULT 'date',
    effective_on       date,                       -- effectivity date (the API's effective_date)
    effectivity_ref    text,                       -- effectivity serial or lot: from this serial / lot
    status             text NOT NULL DEFAULT 'draft',
    submitted_at       timestamptz,
    submitted_by       text,
    approved_at        timestamptz,
    approved_by        text,
    rejected_at        timestamptz,
    rejected_by        text,
    rejected_reason    text,
    implemented_at     timestamptz,
    implemented_by     text,
    cancelled_at       timestamptz,
    cancelled_by       text,
    cancelled_reason   text,
    idempotency_key    text,
    version            integer NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz NOT NULL DEFAULT now(),
    updated_by         text,
    UNIQUE (bus_id, number)
);
CREATE INDEX IF NOT EXISTS mfg_ecos_list_idx ON mfg.mfg_ecos (bus_id, status, cdatetime DESC);
CREATE INDEX IF NOT EXISTS mfg_ecos_ncr_idx ON mfg.mfg_ecos (source_ncr_id) WHERE source_ncr_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS mfg_ecos_idempotency_uq
    ON mfg.mfg_ecos (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE mfg.mfg_ecos DROP CONSTRAINT IF EXISTS mfg_ecos_lifecycle_check;
ALTER TABLE mfg.mfg_ecos ADD CONSTRAINT mfg_ecos_lifecycle_check
    CHECK ((status NOT IN ('approved', 'implemented') OR approved_at IS NOT NULL)
           AND (status <> 'implemented' OR implemented_at IS NOT NULL)
           AND (status <> 'rejected' OR rejected_at IS NOT NULL)
           AND (effectivity <> 'date' OR status IN ('draft', 'cancelled', 'rejected') OR effective_on IS NOT NULL));

CREATE TABLE IF NOT EXISTS mfg.mfg_eco_items (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    eco_id               text NOT NULL REFERENCES mfg.mfg_ecos (id) ON DELETE CASCADE,
    position             integer NOT NULL,
    object_type          text NOT NULL,           -- item_revision | bom | routing | work_instruction | inspection_plan
    product_id           text NOT NULL,
    from_revision_id     text,                    -- the released record it replaces; NULL for a new one
    to_revision_id       text,                    -- the draft record that becomes released
    change_summary       text,
    stock_disposition    text NOT NULL DEFAULT 'use_up',
    order_disposition    text NOT NULL DEFAULT 'none',
    notes                text,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text,
    UNIQUE (eco_id, position)
);
CREATE INDEX IF NOT EXISTS mfg_eco_items_product_idx ON mfg.mfg_eco_items (bus_id, product_id);

CREATE TABLE IF NOT EXISTS mfg.mfg_eco_impacts (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    org_id        text,
    bus_id        text NOT NULL,
    eco_id        text NOT NULL REFERENCES mfg.mfg_ecos (id),
    snapshot      jsonb NOT NULL,                 -- {"where_used", "stock", "open_orders", "planned_orders", "cost"}
    is_frozen     boolean NOT NULL DEFAULT false, -- the one written on submit, which approval sees
    computed_at   timestamptz NOT NULL DEFAULT now(),
    computed_by   text
);
CREATE INDEX IF NOT EXISTS mfg_eco_impacts_eco_idx ON mfg.mfg_eco_impacts (eco_id, computed_at DESC);

CREATE TABLE IF NOT EXISTS mfg.mfg_eco_approvals (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    eco_id           text NOT NULL REFERENCES mfg.mfg_ecos (id),
    step             integer NOT NULL DEFAULT 1,
    approver_role    text,
    approver         text NOT NULL,
    decision         text NOT NULL,
    comment          text,
    impact_id        text REFERENCES mfg.mfg_eco_impacts (id),   -- the impact the approver saw
    decided_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mfg_eco_approvals_eco_idx ON mfg.mfg_eco_approvals (eco_id, decided_at);

DROP TRIGGER IF EXISTS mfg_eco_impacts_append_only ON mfg.mfg_eco_impacts;
CREATE TRIGGER mfg_eco_impacts_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_eco_impacts
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();
DROP TRIGGER IF EXISTS mfg_eco_approvals_append_only ON mfg.mfg_eco_approvals;
CREATE TRIGGER mfg_eco_approvals_append_only BEFORE UPDATE OR DELETE ON mfg.mfg_eco_approvals
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_refuse_change();

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['mfg_eco_impacts', 'mfg_eco_approvals'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                        WHERE g.tgrelid = ('mfg.' || t)::regclass AND p.proname = 'mfg_refuse_change' AND NOT g.tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% is not append-only: its mfg_refuse_change trigger is missing', t;
        END IF;
    END LOOP;
END $$;

COMMIT;
