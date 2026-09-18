-- Stock taken out of a bin because it was sold.
--
-- The bin movements so far are all things a person does to the shelves:
-- putting stock in, carrying it between bins, counting it, taking it out.
-- Selling is different — it is the stock leaving the shop entirely — and
-- recording it as CLEARED would put it in the same sentence as somebody
-- deciding a bin is no longer the right place, which is not what happened.
--
-- It matters because the history is read to answer "why does Rack B say forty
-- when I put sixty there". "Twelve sold" and "twelve moved to Rack C" are
-- different answers to that question and must not look alike.
--
-- Still records a STATEMENT, not stock: nothing about a sale's quantities
-- depends on this, and the sale deducts from the shelf exactly as it always
-- has, whatever a cashier does or does not say about a bin.

ALTER TABLE mystoreguard.msg_place_movements
    DROP CONSTRAINT IF EXISTS ck_msg_place_movements_type;

ALTER TABLE mystoreguard.msg_place_movements
    ADD CONSTRAINT ck_msg_place_movements_type
    CHECK (movement_type = ANY (ARRAY['PLACED','MOVED','COUNTED','CLEARED','TAKEN']));

COMMENT ON COLUMN mystoreguard.msg_place_movements.movement_type IS
    'PLACED — stock given a bin. MOVED — carried between bins. COUNTED — a bin '
    'counted. CLEARED — no longer recorded in that bin. TAKEN — sold out of it.';

-- Whether a bin''s figure is still something to act on.
--
-- A deduction a person CHOSE is worth trusting; one nobody was asked about was
-- worked out by a rule, and a rule cannot know which bin a hand reached into.
-- Without this the two are indistinguishable and every bin looks equally
-- reliable — which is how a shelf label nobody can trust gets trusted.
ALTER TABLE mystoreguard.msg_place_movements
    ADD COLUMN IF NOT EXISTS was_chosen boolean;

COMMENT ON COLUMN mystoreguard.msg_place_movements.was_chosen IS
    'For a TAKEN movement: true where a person said which bin, false where the '
    'system worked it out because nobody was asked. Null for every other kind, '
    'which is always somebody acting deliberately.';

-- "Has anything been assumed in this bin since it was last counted" is the
-- question that decides whether its number can be acted on.
CREATE INDEX IF NOT EXISTS ix_msg_place_movements_assumed
    ON mystoreguard.msg_place_movements (tenant_id, org_id, bus_id,
                                         from_place_id, cdatetime DESC)
    WHERE was_chosen IS FALSE;
