-- 20260828-04-mystoreguard-message-document-ref.sql
-- Which document a message was sent for, so the email can carry it as a PDF.
--
-- One nullable column rather than a table: a message is about at most one
-- document, and the alternative — building the PDF at compose time and storing
-- the bytes — would keep a copy that goes stale the moment the invoice is
-- edited. The reference is resolved when the message is actually sent, so the
-- attachment is always the document as it stands.
--
-- Format is "TYPE:id", e.g. "INVOICE:inv_9f8k…". Text rather than two columns
-- because nothing joins on it; it is read by exactly one code path.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE mystoreguard.msg_messages
    ADD COLUMN IF NOT EXISTS document_ref text;
