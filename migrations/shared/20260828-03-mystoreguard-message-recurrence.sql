-- 20260828-03-mystoreguard-message-recurrence.sql
-- Messages that repeat, messages without a subject, and messages sent now.
--
-- Idempotent; safe to re-run on every deploy.

-- ---------------------------------------------------------------------------
-- A text message has no subject line.
--
-- The column was NOT NULL, so composing an SMS meant inventing a subject
-- nobody would ever see. Made nullable, with a CHECK keeping it required for
-- EMAIL — where it is the first thing a recipient reads and an empty one lands
-- in spam.
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_messages
    ALTER COLUMN subject DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_msg_messages_subject_required_for_email'
    ) THEN
        ALTER TABLE mystoreguard.msg_messages
            ADD CONSTRAINT ck_msg_messages_subject_required_for_email
            CHECK (channel <> 'EMAIL' OR subject IS NOT NULL);
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Repeating messages
--
-- The rule lives on the message itself rather than in a separate schedule
-- table. A repeating message is the same message sent again — same body, same
-- recipients — so a second table would hold a copy of all of it to express
-- "and again next week".
--
-- occurrences_sent counts what has actually gone out, so a run that fails does
-- not consume one. next_run_at is when it is next due; NULL means never again,
-- which is also how a finished series comes to rest.
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_messages
    ADD COLUMN IF NOT EXISTS recurrence        text    NOT NULL DEFAULT 'NONE',
    ADD COLUMN IF NOT EXISTS recurrence_count  integer,
    ADD COLUMN IF NOT EXISTS occurrences_sent  integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_run_at       timestamptz;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_messages_recurrence'
    ) THEN
        ALTER TABLE mystoreguard.msg_messages
            ADD CONSTRAINT ck_msg_messages_recurrence
            CHECK (recurrence IN ('NONE','DAILY','WEEKLY','MONTHLY','QUARTERLY','YEARLY'));
    END IF;

    -- "Send it twice" has to mean twice. A repeat with a count of zero or a
    -- negative number is a message that repeats never, which is a one-off
    -- wearing a costume.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_messages_recurrence_count'
    ) THEN
        ALTER TABLE mystoreguard.msg_messages
            ADD CONSTRAINT ck_msg_messages_recurrence_count
            CHECK (recurrence_count IS NULL OR recurrence_count > 0);
    END IF;

    -- A count without a rule is meaningless: nothing says when the second one
    -- would go.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_msg_messages_recurrence_shape'
    ) THEN
        ALTER TABLE mystoreguard.msg_messages
            ADD CONSTRAINT ck_msg_messages_recurrence_shape
            CHECK (recurrence <> 'NONE' OR recurrence_count IS NULL);
    END IF;
END $$;

-- What the dispatcher asks for on every run: everything due, oldest first.
CREATE INDEX IF NOT EXISTS idx_msg_messages_due
    ON mystoreguard.msg_messages (tenant_id, next_run_at)
    WHERE next_run_at IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Per-occurrence delivery
--
-- A recipient row records the LAST attempt, so on a repeating message the
-- earlier ones would be overwritten and "did the reminder go out three weeks
-- running" becomes unanswerable. This records which occurrence a row belongs
-- to; occurrence 1 is the first send.
-- ---------------------------------------------------------------------------
ALTER TABLE mystoreguard.msg_message_recipients
    ADD COLUMN IF NOT EXISTS occurrence integer NOT NULL DEFAULT 1;
