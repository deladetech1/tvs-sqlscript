-- Messages a shop writes once and sends many times, and messages to people who
-- are not in the system.
--
-- Two changes, both about the same thing: the shop composes far more messages
-- than it has records to attach them to.
--
-- 1. TEMPLATES
--
-- Every shop sends the same handful of messages for ever — the payment
-- reminder, the "your repair is ready", the festive note. Writing each one
-- again is how a reminder ends up saying something slightly different every
-- month, and how the good wording gets lost when the person who wrote it is
-- off. A template holds a subject and a body with their placeholders intact,
-- so it is filled in for whoever it is being sent to at the moment it goes.
--
-- `channel` is a hint rather than a rule: a template written for email can be
-- sent as an SMS, it will just read long. NULL means it suits either.
--
-- No usage counter. It would be one more thing to keep true across sends,
-- reschedules and failures, and nobody picks a template based on a number.
--
-- 2. RECIPIENTS WHO ARE NOT RECORDS
--
-- msg_message_recipients has always pointed at a customer or a supplier, so a
-- shop could not email a landlord, a prospect, or the courier — anybody it had
-- no reason to keep a record of. recipient_id becomes optional, with the name,
-- email and phone that were already on the row carrying the whole address.
--
-- The check keeps the two shapes honest: a row either names a record or spells
-- out an address, and either way it has somewhere to send to.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_message_templates (
    id            text PRIMARY KEY,
    tenant_id     text NOT NULL,
    org_id        text NOT NULL,
    bus_id        text NOT NULL,
    name          text NOT NULL,
    description   text,
    -- 'EMAIL', 'SMS', or NULL for either.
    channel       text,
    subject       text,
    body          text NOT NULL,
    -- What the shop files it under — Reminders, Marketing, Receipts. Free text
    -- rather than a fixed list: every trade groups its letters differently.
    category      text,
    is_active     boolean NOT NULL DEFAULT true,
    delete_status text NOT NULL DEFAULT 'NOT_DELETED',
    cdate         text,
    ctime         text,
    cdatetime     timestamptz NOT NULL DEFAULT NOW(),
    created_by    text,
    updated_by    text,
    deleted_by    text,
    CONSTRAINT ck_msg_message_templates_channel
        CHECK (channel IS NULL OR channel IN ('EMAIL', 'SMS'))
);

-- One name per shop, so "Payment reminder" means one thing when somebody picks
-- it off a list. Partial, so a deleted template releases its name.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_message_templates_name
    ON mystoreguard.msg_message_templates (tenant_id, org_id, bus_id, lower(name))
    WHERE delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_message_templates_business
    ON mystoreguard.msg_message_templates (tenant_id, org_id, bus_id, delete_status);

COMMENT ON TABLE mystoreguard.msg_message_templates IS
    'Reusable message subjects and bodies, placeholders intact. Filled in per '
    'recipient at the moment of sending, never at the moment of saving.';


-- Recipients who are not records --------------------------------------------

ALTER TABLE mystoreguard.msg_message_recipients
    ALTER COLUMN recipient_id DROP NOT NULL;

ALTER TABLE mystoreguard.msg_message_recipients
    DROP CONSTRAINT IF EXISTS ck_msg_message_recipients_addressable;

ALTER TABLE mystoreguard.msg_message_recipients
    ADD CONSTRAINT ck_msg_message_recipients_addressable
    CHECK (
        recipient_id IS NOT NULL
        OR recipient_email IS NOT NULL
        OR recipient_contact IS NOT NULL
    );

COMMENT ON COLUMN mystoreguard.msg_message_recipients.recipient_id IS
    'The customer or supplier this is going to. NULL for an address typed in by '
    'hand, where the name, email and phone on this row are the whole of what is '
    'known about them.';


-- CUSTOM: a message to somebody who is not on file at all.
--
-- The recipient_type has always been SUPPLIER or CUSTOMER, which is the same
-- assumption in another place — that everyone a shop writes to is already a
-- record. Both the message and its recipient rows carry the type, so both
-- checks have to allow the third case or the insert fails halfway through.

-- The names are the ones actually on the tables. Dropping a guessed name
-- silently does nothing, and the old two-value check would have survived
-- alongside the new one and gone on refusing CUSTOM.

ALTER TABLE mystoreguard.msg_messages
    DROP CONSTRAINT IF EXISTS ck_msg_messages_recipient_type;
ALTER TABLE mystoreguard.msg_messages
    ADD CONSTRAINT ck_msg_messages_recipient_type
    CHECK (recipient_type IN ('SUPPLIER', 'CUSTOMER', 'CUSTOM'));

ALTER TABLE mystoreguard.msg_message_recipients
    DROP CONSTRAINT IF EXISTS ck_msg_message_recipients_recipient_type;
ALTER TABLE mystoreguard.msg_message_recipients
    ADD CONSTRAINT ck_msg_message_recipients_recipient_type
    CHECK (recipient_type IN ('SUPPLIER', 'CUSTOMER', 'CUSTOM'));


-- Repeating every so many days ----------------------------------------------
--
-- The fixed rules — daily, weekly, monthly, quarterly, yearly — cover what most
-- reminders want and not what shops keep asking for: every ten days, every 45
-- days. A follow-up cycle rarely lands neatly on a week or a month.
--
-- The gap lives on the message rather than being encoded into the recurrence
-- name, so "every 10 days" and "every 45 days" are the same rule with different
-- numbers instead of two more values to handle everywhere.

ALTER TABLE mystoreguard.msg_messages
    ADD COLUMN IF NOT EXISTS recurrence_interval_days integer;

ALTER TABLE mystoreguard.msg_messages
    DROP CONSTRAINT IF EXISTS ck_msg_messages_recurrence;
ALTER TABLE mystoreguard.msg_messages
    ADD CONSTRAINT ck_msg_messages_recurrence
    CHECK (recurrence IN ('NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY',
                          'YEARLY', 'EVERY_N_DAYS'));

-- The two halves belong together. EVERY_N_DAYS with no gap would repeat
-- immediately and for ever; a gap on any other rule is a number nobody reads
-- and the next person to open the record believes.
ALTER TABLE mystoreguard.msg_messages
    DROP CONSTRAINT IF EXISTS ck_msg_messages_interval_shape;
ALTER TABLE mystoreguard.msg_messages
    ADD CONSTRAINT ck_msg_messages_interval_shape
    CHECK (
        (recurrence = 'EVERY_N_DAYS' AND recurrence_interval_days > 0)
        OR (recurrence <> 'EVERY_N_DAYS' AND recurrence_interval_days IS NULL)
    );

COMMENT ON COLUMN mystoreguard.msg_messages.recurrence_interval_days IS
    'Days between sends when recurrence is EVERY_N_DAYS. NULL for every other rule.';
