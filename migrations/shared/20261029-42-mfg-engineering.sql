-- Manufacturing: engineering -- what things are made of and how (design: docs/mfg/03-database-model.md
-- §3.3, §5, §8; 02-domain-model.md §2; contract R1.md §3).
--
--   mfg_item_settings            Manufacturing's own row for a product (core_platform.cp_products):
--                                item type, make or buy, lot sizing, scrap and yield, shelf life
--   mfg_uom_conversions          alternate units of a product and their factors
--   mfg_item_revisions           revisions of a product (A, B, C): draft -> in_review -> released
--                                -> superseded | obsolete
--   mfg_boms / mfg_bom_lines     bills of materials, revisioned, per (product, type, alternate,
--                                plant or every plant); lines are components, co-products,
--                                by-products or text
--   mfg_routings / mfg_operations   how a product is made: operations at work centers, with
--                                times, controls and the instruction to follow
--   mfg_operation_links          dependencies between operations; none means serial by seq
--   mfg_work_instructions        revisioned instructions; mfg_instruction_steps hold the steps and
--                                mfg_instruction_checkpoints what must be recorded at a step
--   mfg_documents                files (drawings, specs, certificates ...) in the app's private
--                                storage, owned by one entity; mfg_document_links attach a
--                                document to further entities
--
-- Released revisions are frozen by mfg.mfg_freeze_released() (20261029-40): the header, and every
-- child row (BOM lines, operations, operation links, steps, checkpoints) through a trigger that
-- looks up the header's status. A change always means a new revision.
--
-- There is no production-version table (R-2): an order's BOM and routing are the released ones of
-- the same alternate effective at its date, the plant's own before the every-plant one, unless
-- mfg_item_settings.default_bom_id / default_routing_id or the order names them.
--
-- Product ids are cp_products ids and supplier ids cp_parties ids, registered for merges in
-- 20261029-47. The CHECK lists live in 20261029-45. Idempotent; safe to re-run.

BEGIN;

-- ===================================================================== items
CREATE TABLE IF NOT EXISTS mfg.mfg_item_settings (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    org_id                 text,
    bus_id                 text NOT NULL,
    product_id             text NOT NULL,           -- cp_products.id (extension reference)
    item_type              text NOT NULL,
    procurement            text NOT NULL,
    is_phantom             boolean NOT NULL DEFAULT false,
    current_revision_id    text,
    default_bom_id         text,                    -- overrides the effectivity choice (R-2)
    default_routing_id     text,
    lot_size_rule          text NOT NULL DEFAULT 'lot_for_lot',
    lot_size_fixed         numeric(18,6),
    lot_size_min           numeric(18,6),
    lot_size_max           numeric(18,6),
    lot_size_multiple      numeric(18,6),
    period_days            integer,
    assembly_scrap_pct     numeric(6,3) NOT NULL DEFAULT 0,
    yield_pct              numeric(6,3) NOT NULL DEFAULT 100,
    make_lead_time_days    integer,
    time_fence_days        integer,
    shelf_life_days        integer,
    use_fefo               boolean NOT NULL DEFAULT false,
    backflush              boolean,                 -- NULL: the business default
    inspect_on_receipt     boolean NOT NULL DEFAULT false,
    inspect_on_completion  boolean NOT NULL DEFAULT false,
    storage_notes          text,
    hazard_class           text,
    country_of_origin      text,
    hs_code                text,
    weight_kg              numeric(18,6),
    volume_m3              numeric(18,6),
    length_mm              numeric(18,3),
    width_mm               numeric(18,3),
    height_mm              numeric(18,3),
    custom                 jsonb NOT NULL DEFAULT '{}',
    archived_at            timestamptz,
    version                integer NOT NULL DEFAULT 1,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz NOT NULL DEFAULT now(),
    updated_by             text,
    UNIQUE (bus_id, product_id)
);
CREATE INDEX IF NOT EXISTS mfg_item_settings_type_idx ON mfg.mfg_item_settings (bus_id, item_type, procurement) WHERE archived_at IS NULL;
ALTER TABLE mfg.mfg_item_settings DROP CONSTRAINT IF EXISTS mfg_item_settings_numbers_check;
ALTER TABLE mfg.mfg_item_settings ADD CONSTRAINT mfg_item_settings_numbers_check
    CHECK (assembly_scrap_pct >= 0 AND assembly_scrap_pct < 100 AND yield_pct > 0 AND yield_pct <= 100
           AND (lot_size_min IS NULL OR lot_size_min >= 0) AND (lot_size_max IS NULL OR lot_size_max >= coalesce(lot_size_min, 0))
           AND (lot_size_multiple IS NULL OR lot_size_multiple > 0) AND (lot_size_fixed IS NULL OR lot_size_fixed > 0));

CREATE TABLE IF NOT EXISTS mfg.mfg_uom_conversions (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    product_id   text NOT NULL,
    from_unit    text NOT NULL,
    to_unit      text NOT NULL,
    factor       numeric(24,12) NOT NULL CHECK (factor > 0),
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   text,
    UNIQUE (bus_id, product_id, from_unit, to_unit)
);

CREATE TABLE IF NOT EXISTS mfg.mfg_item_revisions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    product_id      text NOT NULL,
    revision        text NOT NULL,
    status          text NOT NULL DEFAULT 'draft',
    effective_from  date,
    effective_to    date,
    eco_id          text,
    notes           text,
    released_at     timestamptz,
    released_by     text,
    version         integer NOT NULL DEFAULT 1,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text,
    UNIQUE (bus_id, product_id, revision)
);

-- ====================================================================== BOMs
CREATE TABLE IF NOT EXISTS mfg.mfg_boms (
    id                   text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id            text NOT NULL,
    org_id               text,
    bus_id               text NOT NULL,
    product_id           text NOT NULL,
    item_revision_id     text REFERENCES mfg.mfg_item_revisions (id),
    bom_type             text NOT NULL DEFAULT 'manufacturing',
    usage                text NOT NULL DEFAULT 'production',
    alternate            integer NOT NULL DEFAULT 1 CHECK (alternate >= 1),
    revision             text NOT NULL,
    status               text NOT NULL DEFAULT 'draft',
    plant_id             text REFERENCES mfg.mfg_plants (id),   -- NULL = every plant
    base_qty             numeric(18,6) NOT NULL DEFAULT 1 CHECK (base_qty > 0),
    unit                 text NOT NULL,
    effective_from       date,
    effective_to         date,
    derived_from_bom_id  text REFERENCES mfg.mfg_boms (id),     -- an MBOM derived from an EBOM
    notes                text,
    eco_id               text,
    idempotency_key      text,
    released_at          timestamptz,
    released_by          text,
    archived_at          timestamptz,
    version              integer NOT NULL DEFAULT 1,
    cdatetime            timestamptz NOT NULL DEFAULT now(),
    created_by           text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    updated_by           text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_boms_revision_uq
    ON mfg.mfg_boms (bus_id, product_id, bom_type, alternate, revision, coalesce(plant_id, ''));
CREATE UNIQUE INDEX IF NOT EXISTS mfg_boms_idempotency_uq ON mfg.mfg_boms (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_boms_effective_idx ON mfg.mfg_boms (bus_id, product_id, status, effective_from);
ALTER TABLE mfg.mfg_boms DROP CONSTRAINT IF EXISTS mfg_boms_effective_check;
ALTER TABLE mfg.mfg_boms ADD CONSTRAINT mfg_boms_effective_check
    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from);

CREATE TABLE IF NOT EXISTS mfg.mfg_bom_lines (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    org_id                text,
    bus_id                text NOT NULL,
    bom_id                text NOT NULL REFERENCES mfg.mfg_boms (id) ON DELETE CASCADE,
    position              integer NOT NULL,
    line_type             text NOT NULL DEFAULT 'component',
    component_id          text,                       -- cp_products.id; NULL only for text lines
    qty                   numeric(18,6) NOT NULL,     -- per base_qty; negative for co/by-products
    unit                  text NOT NULL,
    scrap_pct             numeric(6,3) NOT NULL DEFAULT 0 CHECK (scrap_pct >= 0 AND scrap_pct < 100),
    operation_seq         integer,                    -- consumed at this routing operation
    issue_method          text NOT NULL DEFAULT 'manual',
    is_phantom            boolean NOT NULL DEFAULT false,
    is_optional           boolean NOT NULL DEFAULT false,
    condition             jsonb,                      -- {"colour": ["red","blue"]}; NULL = always
    substitute_group      text,
    substitute_priority   integer,
    cost_share_pct        numeric(6,3),               -- co/by-products
    ref_designators       text,
    line_text             text,                       -- the text of a text line
    notes                 text,
    derived_from_line_id  text,
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text,
    UNIQUE (bom_id, position)
);
CREATE INDEX IF NOT EXISTS mfg_bom_lines_where_used_idx ON mfg.mfg_bom_lines (component_id) INCLUDE (bom_id, qty);

-- ================================================================== routings
CREATE TABLE IF NOT EXISTS mfg.mfg_routings (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    product_id       text NOT NULL,
    alternate        integer NOT NULL DEFAULT 1 CHECK (alternate >= 1),
    revision         text NOT NULL,
    status           text NOT NULL DEFAULT 'draft',
    usage            text NOT NULL DEFAULT 'production',
    plant_id         text REFERENCES mfg.mfg_plants (id),   -- NULL = every plant
    effective_from   date,
    effective_to     date,
    notes            text,
    eco_id           text,
    idempotency_key  text,
    released_at      timestamptz,
    released_by      text,
    archived_at      timestamptz,
    version          integer NOT NULL DEFAULT 1,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_routings_revision_uq
    ON mfg.mfg_routings (bus_id, product_id, usage, alternate, revision, coalesce(plant_id, ''));
CREATE UNIQUE INDEX IF NOT EXISTS mfg_routings_idempotency_uq ON mfg.mfg_routings (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_routings_effective_idx ON mfg.mfg_routings (bus_id, product_id, status, effective_from);
ALTER TABLE mfg.mfg_routings DROP CONSTRAINT IF EXISTS mfg_routings_effective_check;
ALTER TABLE mfg.mfg_routings ADD CONSTRAINT mfg_routings_effective_check
    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from);

-- ======================================================= work instructions
CREATE TABLE IF NOT EXISTS mfg.mfg_work_instructions (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    org_id           text,
    bus_id           text NOT NULL,
    code             text NOT NULL,
    revision         text NOT NULL,
    status           text NOT NULL DEFAULT 'draft',
    title            text NOT NULL,
    product_id       text,                    -- the product it is written for, if one
    effective_from   date,
    effective_to     date,
    notes            text,
    eco_id           text,
    idempotency_key  text,
    released_at      timestamptz,
    released_by      text,
    archived_at      timestamptz,
    version          integer NOT NULL DEFAULT 1,
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    updated_by       text,
    UNIQUE (bus_id, code, revision)
);
CREATE UNIQUE INDEX IF NOT EXISTS mfg_work_instructions_idempotency_uq ON mfg.mfg_work_instructions (bus_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS mfg_work_instructions_product_idx ON mfg.mfg_work_instructions (bus_id, product_id, status);

CREATE TABLE IF NOT EXISTS mfg.mfg_instruction_steps (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    org_id            text,
    bus_id            text NOT NULL,
    instruction_id    text NOT NULL REFERENCES mfg.mfg_work_instructions (id) ON DELETE CASCADE,
    position          integer NOT NULL,
    title             text NOT NULL,
    body              text,                   -- Markdown
    media             jsonb NOT NULL DEFAULT '[]',   -- document ids
    safety            text,
    tools             jsonb NOT NULL DEFAULT '[]',
    machine_settings  jsonb NOT NULL DEFAULT '[]',   -- [{name, value, unit, tolerance}]
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        text,
    UNIQUE (instruction_id, position)
);

-- What must be recorded before a step is done. key is unique per instruction, so a confirmation's
-- checkpoints [{key, value}] name one without ambiguity.
CREATE TABLE IF NOT EXISTS mfg.mfg_instruction_checkpoints (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    org_id          text,
    bus_id          text NOT NULL,
    instruction_id  text NOT NULL REFERENCES mfg.mfg_work_instructions (id) ON DELETE CASCADE,
    step_id         text NOT NULL REFERENCES mfg.mfg_instruction_steps (id) ON DELETE CASCADE,
    position        integer NOT NULL DEFAULT 0,
    key             text NOT NULL,
    label           text NOT NULL,
    type            text NOT NULL,            -- check | number | text | photo (20261029-45)
    min_value       numeric(18,6),
    max_value       numeric(18,6),
    unit            text,
    required        boolean NOT NULL DEFAULT true,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      text,
    UNIQUE (instruction_id, key)
);
CREATE INDEX IF NOT EXISTS mfg_instruction_checkpoints_step_idx ON mfg.mfg_instruction_checkpoints (step_id, position);
ALTER TABLE mfg.mfg_instruction_checkpoints DROP CONSTRAINT IF EXISTS mfg_instruction_checkpoints_limits_check;
ALTER TABLE mfg.mfg_instruction_checkpoints ADD CONSTRAINT mfg_instruction_checkpoints_limits_check
    CHECK (min_value IS NULL OR max_value IS NULL OR max_value >= min_value);

-- ================================================================ operations
CREATE TABLE IF NOT EXISTS mfg.mfg_operations (
    id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id             text NOT NULL,
    org_id                text,
    bus_id                text NOT NULL,
    routing_id            text NOT NULL REFERENCES mfg.mfg_routings (id) ON DELETE CASCADE,
    seq                   integer NOT NULL CHECK (seq > 0),
    name                  text NOT NULL,
    description           text,
    work_center_id        text NOT NULL REFERENCES mfg.mfg_work_centers (id),
    alt_work_center_ids   text[] NOT NULL DEFAULT '{}',    -- ranked
    setup_min             numeric(12,3) NOT NULL DEFAULT 0 CHECK (setup_min >= 0),
    run_sec_per_unit      numeric(18,6) NOT NULL DEFAULT 0 CHECK (run_sec_per_unit >= 0),
    queue_min             integer,
    move_min              integer,
    wait_min              integer,
    inspect_min           integer,
    labour_count          numeric(8,2) NOT NULL DEFAULT 0,
    skill                 text,
    machine_count         integer NOT NULL DEFAULT 1,
    tooling               jsonb NOT NULL DEFAULT '[]',     -- resource ids of tools
    control_key           text NOT NULL DEFAULT 'count_point',
    subcontract_party_id  text,                            -- cp_parties.id
    subcontract_price     numeric(18,4),
    work_instruction_id   text REFERENCES mfg.mfg_work_instructions (id),
    inspection_plan_id    text,                            -- R2
    send_ahead_qty        numeric(18,6),
    cdatetime             timestamptz NOT NULL DEFAULT now(),
    created_by            text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    updated_by            text,
    UNIQUE (routing_id, seq)
);
CREATE INDEX IF NOT EXISTS mfg_operations_work_center_idx ON mfg.mfg_operations (work_center_id);
CREATE INDEX IF NOT EXISTS mfg_operations_instruction_idx ON mfg.mfg_operations (work_instruction_id) WHERE work_instruction_id IS NOT NULL;

-- Empty for a routing = serial by seq. (20 and 30 both after 10; 40 after both.)
CREATE TABLE IF NOT EXISTS mfg.mfg_operation_links (
    tenant_id   text NOT NULL,
    org_id      text,
    bus_id      text NOT NULL,
    routing_id  text NOT NULL REFERENCES mfg.mfg_routings (id) ON DELETE CASCADE,
    from_seq    integer NOT NULL,
    to_seq      integer NOT NULL,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    PRIMARY KEY (routing_id, from_seq, to_seq),
    CHECK (from_seq <> to_seq)
);

-- ================================================================= documents
-- pending until the API confirms the blob exists (POST /documents/{id}/uploaded).
CREATE TABLE IF NOT EXISTS mfg.mfg_documents (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    org_id         text,
    bus_id         text NOT NULL,
    entity_type    text NOT NULL,             -- the entity that owns it: item, bom, routing, ...
    entity_id      text NOT NULL,
    kind           text NOT NULL,
    title          text NOT NULL,
    revision       text,
    status         text NOT NULL DEFAULT 'pending',
    file_name      text,
    blob_path      text NOT NULL,             -- private container; served through short-lived signed links
    content_type   text,
    size_bytes     bigint CHECK (size_bytes IS NULL OR size_bytes >= 0),
    sha256         text,
    confidential   boolean NOT NULL DEFAULT false,
    expires_on     date,
    archived_at    timestamptz,
    version        integer NOT NULL DEFAULT 1,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz NOT NULL DEFAULT now(),
    updated_by     text
);
CREATE INDEX IF NOT EXISTS mfg_documents_entity_idx ON mfg.mfg_documents (bus_id, entity_type, entity_id) WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS mfg.mfg_document_links (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    org_id       text,
    bus_id       text NOT NULL,
    document_id  text NOT NULL REFERENCES mfg.mfg_documents (id) ON DELETE CASCADE,
    entity_type  text NOT NULL,
    entity_id    text NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    UNIQUE (document_id, entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS mfg_document_links_entity_idx ON mfg.mfg_document_links (bus_id, entity_type, entity_id);

-- ============================================================ revision freezing
DROP TRIGGER IF EXISTS mfg_item_revisions_freeze ON mfg.mfg_item_revisions;
CREATE TRIGGER mfg_item_revisions_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_item_revisions
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released();
DROP TRIGGER IF EXISTS mfg_boms_freeze ON mfg.mfg_boms;
CREATE TRIGGER mfg_boms_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_boms
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released();
DROP TRIGGER IF EXISTS mfg_routings_freeze ON mfg.mfg_routings;
CREATE TRIGGER mfg_routings_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_routings
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released();
DROP TRIGGER IF EXISTS mfg_work_instructions_freeze ON mfg.mfg_work_instructions;
CREATE TRIGGER mfg_work_instructions_freeze BEFORE UPDATE OR DELETE ON mfg.mfg_work_instructions
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released();

DROP TRIGGER IF EXISTS mfg_bom_lines_freeze ON mfg.mfg_bom_lines;
CREATE TRIGGER mfg_bom_lines_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_bom_lines
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_boms', 'bom_id');
DROP TRIGGER IF EXISTS mfg_operations_freeze ON mfg.mfg_operations;
CREATE TRIGGER mfg_operations_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_operations
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_routings', 'routing_id');
DROP TRIGGER IF EXISTS mfg_operation_links_freeze ON mfg.mfg_operation_links;
CREATE TRIGGER mfg_operation_links_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_operation_links
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_routings', 'routing_id');
DROP TRIGGER IF EXISTS mfg_instruction_steps_freeze ON mfg.mfg_instruction_steps;
CREATE TRIGGER mfg_instruction_steps_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_instruction_steps
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_work_instructions', 'instruction_id');
DROP TRIGGER IF EXISTS mfg_instruction_checkpoints_freeze ON mfg.mfg_instruction_checkpoints;
CREATE TRIGGER mfg_instruction_checkpoints_freeze BEFORE INSERT OR UPDATE OR DELETE ON mfg.mfg_instruction_checkpoints
    FOR EACH ROW EXECUTE FUNCTION mfg.mfg_freeze_released('mfg.mfg_work_instructions', 'instruction_id');

-- ===================================================================== invariants
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['mfg_item_revisions', 'mfg_boms', 'mfg_routings', 'mfg_work_instructions', 'mfg_bom_lines',
                             'mfg_operations', 'mfg_operation_links', 'mfg_instruction_steps', 'mfg_instruction_checkpoints'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('mfg.' || t)::regclass AND tgname = t || '_freeze' AND NOT tgisinternal) THEN
            RAISE EXCEPTION 'mfg.% is not frozen on release: trigger %_freeze is missing', t, t;
        END IF;
    END LOOP;

    -- A released BOM or routing has lines.
    IF EXISTS (SELECT 1 FROM mfg.mfg_boms b WHERE b.status = 'released'
                  AND NOT EXISTS (SELECT 1 FROM mfg.mfg_bom_lines l WHERE l.bom_id = b.id)) THEN
        RAISE EXCEPTION 'a released Manufacturing BOM has no lines';
    END IF;
    IF EXISTS (SELECT 1 FROM mfg.mfg_routings r WHERE r.status = 'released'
                  AND NOT EXISTS (SELECT 1 FROM mfg.mfg_operations o WHERE o.routing_id = r.id)) THEN
        RAISE EXCEPTION 'a released Manufacturing routing has no operations';
    END IF;

    -- No two released BOMs of one (product, type, alternate, plant) are effective on the same day.
    IF EXISTS (SELECT 1 FROM mfg.mfg_boms a JOIN mfg.mfg_boms b
                 ON b.bus_id = a.bus_id AND b.product_id = a.product_id AND b.bom_type = a.bom_type
                AND b.alternate = a.alternate AND coalesce(b.plant_id, '') = coalesce(a.plant_id, '') AND b.id > a.id
                WHERE a.status = 'released' AND b.status = 'released'
                  AND daterange(a.effective_from, a.effective_to, '[)') && daterange(b.effective_from, b.effective_to, '[)')) THEN
        RAISE EXCEPTION 'two released Manufacturing BOMs of one product, type, alternate and plant overlap in effectivity';
    END IF;

    -- Every BOM line names a product of its business, or is a text line.
    IF to_regclass('core_platform.cp_products') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM mfg.mfg_bom_lines l
                    WHERE l.line_type <> 'text'
                      AND NOT EXISTS (SELECT 1 FROM core_platform.cp_products p
                                       WHERE p.id = l.component_id AND p.bus_id = l.bus_id)) THEN
            RAISE EXCEPTION 'a Manufacturing BOM line names a product that is not one of its business''s products';
        END IF;
    END IF;
END $$;

COMMIT;
