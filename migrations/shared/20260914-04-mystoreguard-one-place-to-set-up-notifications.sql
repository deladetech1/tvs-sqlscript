-- Notifications, set up in one place instead of five.
--
-- Today a shop that wants to change how it contacts people has to find four
-- different screens, and most of what gets sent has no screen at all:
--
--     Settings -> Receipt          whether a paid receipt is sent, and how
--     Purchase orders -> a modal   how often an unanswered approval repeats
--     Return policy -> a modal     the same, for returns
--     Workflow settings            the same, for tasks
--     nowhere                      delivery emails to customers, which go out
--                                  unconditionally with no way to stop them
--     nowhere                      the instalment payment reminder: email only,
--                                  three days ahead, eight in the morning, all
--                                  three hard-coded in a timer job
--
-- And none of them can say "text this one as well as emailing it", which for a
-- shop in Ghana is backwards: far more customers read a text than an email.
--
-- So: one row per notification per business, holding the channel and the
-- cadence. The keys are a fixed list the application owns (see
-- notification_events.py) rather than free text, because a typo'd key is a
-- notification that silently never sends.
--
-- The existing settings are carried across below rather than left behind. A
-- shop that set its purchase-order reminder to fifteen minutes should find it
-- still says fifteen minutes.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_notification_settings (
    id                   text PRIMARY KEY,
    tenant_id            text NOT NULL,
    org_id               text NOT NULL,
    bus_id               text NOT NULL,

    -- Which notification this is. One of the keys in notification_events.py.
    event_key            text NOT NULL,

    -- Off means nothing is sent at all, whatever the channel says. Kept
    -- separate from the channel so a shop can switch something off for a month
    -- and switch it back on without having to remember how it was set up.
    is_enabled           boolean NOT NULL DEFAULT true,

    -- EMAIL, SMS or BOTH. BOTH uses every route the recipient actually gave
    -- us; it does not require both, so a customer with only a phone still
    -- hears from the shop.
    channel              text NOT NULL DEFAULT 'EMAIL',

    -- How many days BEFORE the thing happens to send. Only meaningful for the
    -- notifications that run ahead of a date — an instalment falling due.
    lead_days            integer,

    -- The hour of the day a daily job sends at, 0-23. Also only for the daily
    -- ones; the rest send when the event happens.
    send_at_hour         integer,

    -- How long to wait before saying it again, for the notifications that
    -- chase. Minutes rather than days because an approval sitting in somebody's
    -- inbox is chased in minutes and an unpaid instalment in days, and one
    -- column has to hold both.
    repeat_every_minutes integer,

    -- How many times in total, including the first. NULL means keep going
    -- until it is dealt with — which is right for money owed and wrong for an
    -- approval nobody is going to give.
    max_occurrences      integer,

    -- Extra addresses for the notifications that go to the business rather
    -- than to a customer. Empty means the people the notification already
    -- knows about: the approvers, the assignee, the owners.
    extra_recipients     text[] NOT NULL DEFAULT '{}',

    cdate                text,
    ctime                text,
    cdatetime            timestamptz NOT NULL DEFAULT NOW(),
    created_by           text,
    updated_by           text,
    deleted_by           text,

    CONSTRAINT ck_msg_notification_settings_channel
        CHECK (channel = ANY (ARRAY['EMAIL'::text, 'SMS'::text, 'BOTH'::text])),
    -- A lead of a year and a repeat of a minute are both mistakes somebody
    -- makes once in a form. Refused here so they cannot become a customer
    -- being texted every sixty seconds.
    CONSTRAINT ck_msg_notification_settings_lead_days
        CHECK (lead_days IS NULL OR (lead_days >= 0 AND lead_days <= 90)),
    CONSTRAINT ck_msg_notification_settings_hour
        CHECK (send_at_hour IS NULL OR (send_at_hour >= 0 AND send_at_hour <= 23)),
    CONSTRAINT ck_msg_notification_settings_repeat
        CHECK (repeat_every_minutes IS NULL OR repeat_every_minutes >= 5),
    CONSTRAINT ck_msg_notification_settings_max
        CHECK (max_occurrences IS NULL OR max_occurrences >= 1)
);

-- One row per notification per business. Partial, so a deleted row does not
-- block setting the same notification up again.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_notification_settings_event
    ON mystoreguard.msg_notification_settings (tenant_id, org_id, bus_id, event_key)
    WHERE deleted_by IS NULL;

CREATE INDEX IF NOT EXISTS ix_msg_notification_settings_lookup
    ON mystoreguard.msg_notification_settings (tenant_id, org_id, bus_id)
    WHERE deleted_by IS NULL;


-- ---------------------------------------------------------------------------
-- Carry the existing settings across
-- ---------------------------------------------------------------------------
--
-- Each block below reads a setting a shop has already chosen and writes it as
-- the matching row here. A business that never opened one of those screens has
-- no row to carry, and gets the application's default the first time it opens
-- the new one — which is the same behaviour it has now.

-- Whether a paid receipt is sent, and by which route. The old column said ALL,
-- EMAIL or SMS; ALL is BOTH here, and the business-level row wins over any
-- branch override because the new setting is per business.
INSERT INTO mystoreguard.msg_notification_settings
    (id, tenant_id, org_id, bus_id, event_key, is_enabled, channel, cdatetime)
SELECT 'nts_' || md5(r.tenant_id || r.org_id || r.bus_id || 'sale.receipt'),
       r.tenant_id, r.org_id, r.bus_id, 'sale.receipt',
       COALESCE(r.auto_send_on_payment, false),
       CASE UPPER(COALESCE(r.auto_send_channel, 'ALL'))
            WHEN 'SMS' THEN 'SMS' WHEN 'EMAIL' THEN 'EMAIL' ELSE 'BOTH' END,
       NOW()
FROM mystoreguard.msg_receipt_settings r
WHERE r.loc_id IS NULL AND r.deleted_by IS NULL
ON CONFLICT DO NOTHING;

-- How often an unanswered purchase-order approval is said again. opt_in was
-- per user; the new setting is per business, so a business counts as opted in
-- if anybody there was.
INSERT INTO mystoreguard.msg_notification_settings
    (id, tenant_id, org_id, bus_id, event_key, is_enabled, channel,
     repeat_every_minutes, cdatetime)
SELECT 'nts_' || md5(p.tenant_id || p.org_id || p.bus_id || 'purchase_order.approval'),
       p.tenant_id, p.org_id, p.bus_id, 'purchase_order.approval',
       bool_or(COALESCE(p.opt_in, true)), 'EMAIL',
       GREATEST(MIN(COALESCE(p.reminder_interval_minutes, 5)), 5),
       NOW()
FROM mystoreguard.msg_purchase_order_notification_settings p
WHERE p.deleted_by IS NULL
GROUP BY p.tenant_id, p.org_id, p.bus_id
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_notification_settings
    (id, tenant_id, org_id, bus_id, event_key, is_enabled, channel,
     repeat_every_minutes, cdatetime)
SELECT 'nts_' || md5(r.tenant_id || r.org_id || r.bus_id || 'return.approval'),
       r.tenant_id, r.org_id, r.bus_id, 'return.approval',
       COALESCE(r.is_active, true), 'EMAIL',
       GREATEST(COALESCE(r.reminder_interval_minutes, 60), 5),
       NOW()
FROM mystoreguard.msg_return_notification_settings r
ON CONFLICT DO NOTHING;

INSERT INTO mystoreguard.msg_notification_settings
    (id, tenant_id, org_id, bus_id, event_key, is_enabled, channel,
     repeat_every_minutes, cdatetime)
SELECT 'nts_' || md5(t.tenant_id || t.org_id || t.bus_id || 'task.reminder'),
       t.tenant_id, t.org_id, t.bus_id, 'task.reminder',
       bool_or(COALESCE(t.opt_in, true)), 'EMAIL',
       GREATEST(MIN(COALESCE(t.reminder_interval_minutes, 120)), 15),
       NOW()
FROM mystoreguard.msg_task_notification_settings t
WHERE t.deleted_by IS NULL
GROUP BY t.tenant_id, t.org_id, t.bus_id
ON CONFLICT DO NOTHING;


-- ---------------------------------------------------------------------------
-- Chasing an instalment that is already late
-- ---------------------------------------------------------------------------
--
-- reminded_at records that a period was chased once, three days before it fell
-- due. Nothing has ever looked at a period AFTER its due date, so a customer
-- who simply does not pay is never contacted again — the one moment a shop most
-- needs the system to say something.
--
-- A separate column, not a reuse of reminded_at: "we told them it was coming"
-- and "we have chased them twice since" are different facts, and the first must
-- not be overwritten by the second or the reminder-before-due goes out again.
ALTER TABLE mystoreguard.msg_installment_schedule
    ADD COLUMN IF NOT EXISTS overdue_reminded_at timestamptz,
    ADD COLUMN IF NOT EXISTS overdue_reminder_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN mystoreguard.msg_installment_schedule.overdue_reminded_at IS
    'When this period was last chased for being late. Distinct from reminded_at, '
    'which is the one notice sent before it fell due.';

COMMENT ON COLUMN mystoreguard.msg_installment_schedule.overdue_reminder_count IS
    'How many times it has been chased, so a cap can be honoured and a customer '
    'is not texted every day for ever.';

-- Finding the periods to chase means "late, not settled, and not chased
-- recently", which without this is a scan of every schedule row ever written.
CREATE INDEX IF NOT EXISTS ix_msg_installment_schedule_overdue
    ON mystoreguard.msg_installment_schedule (tenant_id, due_date)
    WHERE status IN ('PENDING', 'PARTIALLY_PAID');
