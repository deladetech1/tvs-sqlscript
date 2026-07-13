-- Manual overrides for segment membership. A member row can be:
--   AUTO     - added by the matching rules (default)
--   MANUAL   - manually added; kept even if it stops matching
--   EXCLUDED - manually removed; the auto-job will not re-add it
-- Idempotent.

ALTER TABLE mystoreguard.msg_customer_segment_members
    ADD COLUMN IF NOT EXISTS membership text NOT NULL DEFAULT 'AUTO';

ALTER TABLE mystoreguard.msg_customer_segment_members
    DROP CONSTRAINT IF EXISTS ck_msg_customer_segment_members_membership;
ALTER TABLE mystoreguard.msg_customer_segment_members
    ADD CONSTRAINT ck_msg_customer_segment_members_membership
    CHECK (membership IN ('AUTO', 'MANUAL', 'EXCLUDED'));
