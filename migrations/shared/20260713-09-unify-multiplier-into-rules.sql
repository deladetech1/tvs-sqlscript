-- Unify points multipliers into the rules engine: customer tier / segment
-- become rule conditions (CUSTOMER scope), and the standalone points_multiplier
-- on tiers/segments is retired. Idempotent.

-- Allow the new CUSTOMER scope on point rules.
ALTER TABLE mystoreguard.msg_loyalty_point_rules
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_point_rules_scope;
ALTER TABLE mystoreguard.msg_loyalty_point_rules
    ADD CONSTRAINT ck_msg_loyalty_point_rules_scope
    CHECK (scope IN ('SALE', 'ITEM', 'CUSTOMER'));

-- Retire the standalone multiplier (now expressed as a CUSTOMER-scope rule).
ALTER TABLE mystoreguard.msg_loyalty_tiers
    DROP COLUMN IF EXISTS points_multiplier;
ALTER TABLE mystoreguard.msg_customer_segments
    DROP COLUMN IF EXISTS points_multiplier;
