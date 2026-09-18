-- When was this put here, and by whom.
--
-- A storage place records where stock is kept. Nothing records when anybody
-- last said so, and that is the failure mode of every location system ever
-- built: it is accurate only while people update it, and a placement made
-- eleven months ago looks exactly like one made this morning.
--
-- That matters more than it sounds. A shelf label nobody maintains is worse
-- than no shelf label, because people trust it and walk to the wrong rack.
-- The system cannot make the answer true — only a person moving stock can do
-- that — but it can say how old the answer is, so somebody deciding whether to
-- trust it has something to go on.
--
-- Nullable, and null means "nobody recorded it". That is every row placed
-- before this ran. Deliberately not backfilled with NOW(): stamping today's
-- date on a placement made months ago would be inventing the one fact this
-- migration exists to record, and would make stale entries look fresh —
-- exactly backwards.

ALTER TABLE mystoreguard.msg_batch_locations
    ADD COLUMN IF NOT EXISTS placed_at timestamptz,
    ADD COLUMN IF NOT EXISTS placed_by text;

ALTER TABLE mystoreguard.msg_product_units
    ADD COLUMN IF NOT EXISTS placed_at timestamptz,
    ADD COLUMN IF NOT EXISTS placed_by text;

COMMENT ON COLUMN mystoreguard.msg_batch_locations.placed_at IS
    'When somebody last said where this delivery is kept. Null means nobody '
    'recorded it — every row placed before this column existed. Cleared when '
    'the place is cleared, so it never outlives the fact it describes.';

COMMENT ON COLUMN mystoreguard.msg_batch_locations.placed_by IS
    'Who last said where this delivery is kept.';

COMMENT ON COLUMN mystoreguard.msg_product_units.placed_at IS
    'When somebody last said which place this item is in. Distinct from '
    'updated_by/cdatetime, which move for any change to the item at all — a '
    'price correction is not somebody confirming where it is standing.';

COMMENT ON COLUMN mystoreguard.msg_product_units.placed_by IS
    'Who last said which place this item is in.';

-- Same shape as the actor columns already on msg_product_units, so a made-up
-- id fails here rather than becoming an audit trail nobody can follow back.
ALTER TABLE mystoreguard.msg_batch_locations
    DROP CONSTRAINT IF EXISTS fk_msg_batch_locations_cp_users_placed_by;
ALTER TABLE mystoreguard.msg_batch_locations
    ADD CONSTRAINT fk_msg_batch_locations_cp_users_placed_by
    FOREIGN KEY (placed_by, tenant_id)
    REFERENCES core_platform.cp_users(id, tenant_id) ON DELETE SET NULL;

ALTER TABLE mystoreguard.msg_product_units
    DROP CONSTRAINT IF EXISTS fk_msg_product_units_cp_users_placed_by;
ALTER TABLE mystoreguard.msg_product_units
    ADD CONSTRAINT fk_msg_product_units_cp_users_placed_by
    FOREIGN KEY (placed_by, tenant_id)
    REFERENCES core_platform.cp_users(id, tenant_id) ON DELETE SET NULL;

-- "What has not been confirmed in a while" is the question this exists to
-- answer, and it should not be a scan of every delivery a shop has ever taken.
CREATE INDEX IF NOT EXISTS ix_msg_batch_locations_placed_at
    ON mystoreguard.msg_batch_locations (tenant_id, org_id, bus_id, placed_at)
    WHERE place_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_msg_product_units_placed_at
    ON mystoreguard.msg_product_units (tenant_id, org_id, bus_id, placed_at)
    WHERE place_id IS NOT NULL;
