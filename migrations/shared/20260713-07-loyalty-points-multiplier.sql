-- Per-tier and per-segment points multiplier. A customer earns points at their
-- best (highest) multiplier across their tier and their segments. Default 1 =
-- no change. Idempotent.

ALTER TABLE mystoreguard.msg_loyalty_tiers
    ADD COLUMN IF NOT EXISTS points_multiplier numeric(6, 2) NOT NULL DEFAULT 1;

ALTER TABLE mystoreguard.msg_customer_segments
    ADD COLUMN IF NOT EXISTS points_multiplier numeric(6, 2) NOT NULL DEFAULT 1;
