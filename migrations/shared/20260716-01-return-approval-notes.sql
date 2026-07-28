-- 20260716-01-return-approval-notes.sql
-- Dedicated approval note on a store return so the approver's message is visible
-- at the Approved step, independent of processing_notes (which is populated at
-- process time). Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_returns
    ADD COLUMN IF NOT EXISTS approval_notes text;
