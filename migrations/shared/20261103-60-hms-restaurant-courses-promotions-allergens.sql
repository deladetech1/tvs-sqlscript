-- HMS restaurant and bar, more of what a busy one needs:
--
--   * allergens and dietary marks on dishes (shown on the menu, the till, QR ordering and the
--     kitchen's ticket), and how long a dish takes, for the kitchen's ticket timers;
--   * courses: a line belongs to a course (0 = straight away, 1 starters, 2 mains, 3 desserts)
--     and reaches the kitchen when its course is fired -- fired_at is NULL while it is held;
--   * promotions: happy hours and price rules (percent off, an amount off, or a set price) on
--     chosen dishes or categories, on chosen days and hours, applied when the line is ordered.
--     The line keeps its list price and the promotion's name.
--
-- Shifts and cash-up use the tills already there (hms_cash_sessions). Idempotent.

BEGIN;

ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS allergens text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS dietary text[] NOT NULL DEFAULT '{}';
ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS prep_minutes int;
ALTER TABLE hms.hms_menu_items ADD COLUMN IF NOT EXISTS course int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_menu_items DROP CONSTRAINT IF EXISTS hms_menu_items_prep_minutes_check;
ALTER TABLE hms.hms_menu_items ADD CONSTRAINT hms_menu_items_prep_minutes_check CHECK (prep_minutes IS NULL OR prep_minutes BETWEEN 1 AND 240);
ALTER TABLE hms.hms_menu_items DROP CONSTRAINT IF EXISTS hms_menu_items_course_check;
ALTER TABLE hms.hms_menu_items ADD CONSTRAINT hms_menu_items_course_check CHECK (course BETWEEN 0 AND 3);

ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS course int NOT NULL DEFAULT 0;
ALTER TABLE hms.hms_order_items DROP CONSTRAINT IF EXISTS hms_order_items_course_check;
ALTER TABLE hms.hms_order_items ADD CONSTRAINT hms_order_items_course_check CHECK (course BETWEEN 0 AND 3);
-- Lines already ordered were sent when they were ordered.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'hms' AND table_name = 'hms_order_items' AND column_name = 'fired_at') THEN
    ALTER TABLE hms.hms_order_items ADD COLUMN fired_at timestamptz;
    UPDATE hms.hms_order_items SET fired_at = cdatetime;
  END IF;
END $$;
ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS list_price numeric(14,2);
ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS promotion_id text;
ALTER TABLE hms.hms_order_items ADD COLUMN IF NOT EXISTS promo_name text;
CREATE INDEX IF NOT EXISTS hms_order_items_held_idx ON hms.hms_order_items (order_id) WHERE fired_at IS NULL AND voided_at IS NULL;

CREATE TABLE IF NOT EXISTS hms.hms_promotions (
    id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text NOT NULL,
    bus_id        text NOT NULL,
    property_id   text NOT NULL REFERENCES hms.hms_properties (id),
    name          text NOT NULL,
    kind          text NOT NULL,
    value         numeric(14,2) NOT NULL CHECK (value >= 0),
    -- Empty: every dish and drink; else the items and the categories listed.
    item_ids      text[] NOT NULL DEFAULT '{}',
    category_ids  text[] NOT NULL DEFAULT '{}',
    -- 0 Sunday .. 6 Saturday; empty: every day.
    days          int[] NOT NULL DEFAULT '{}',
    -- Local time; both empty: all day. An end before the start runs past midnight.
    start_time    time,
    end_time      time,
    starts_on     date,
    ends_on       date,
    active        boolean NOT NULL DEFAULT true,
    archived_at   timestamptz,
    created_by    text,
    cdatetime     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hms.hms_promotions DROP CONSTRAINT IF EXISTS hms_promotions_kind_check;
ALTER TABLE hms.hms_promotions ADD CONSTRAINT hms_promotions_kind_check CHECK (kind IN ('percent_off', 'amount_off', 'fixed_price'));
CREATE INDEX IF NOT EXISTS hms_promotions_property_idx ON hms.hms_promotions (property_id) WHERE archived_at IS NULL;

COMMIT;
