-- =====================================================================================
-- The storefront assistant (AI chat that edited the shop website) is removed at the
-- owner's request, 2026-11-25. 20261125-03 created its two tables on dev only; this
-- drops them. Nothing else referenced them. Idempotent; safe to re-run.
-- =====================================================================================

BEGIN;

DROP TABLE IF EXISTS mystoreguard.msg_ecommerce_assistant_messages;
DROP TABLE IF EXISTS mystoreguard.msg_ecommerce_assistant_changes;

COMMIT;
