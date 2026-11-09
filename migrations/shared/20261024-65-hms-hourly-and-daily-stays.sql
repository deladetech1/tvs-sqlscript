-- HMS: units priced by the day, and stays booked by the hour.
--
--   hms_unit_types.rate_period  adds 'day' (a day room, a hall or a car by the day).
--   hms_reservations,
--   hms_reservation_units       starts_at/ends_at: a stay booked by the hour (a hall 10:00-14:00),
--                               in the property's local time. Its dates still cover the days it
--                               touches, so the reports count it; clashes are found by time.
--   hms.hms_stay_range()        the time a stay holds a unit: its hours when booked by the hour,
--                               else noon on arrival to noon on departure (the changeover).
--   hms_reservations.deposit_*  the deposit asked for when the booking was made.

BEGIN;

ALTER TABLE hms.hms_unit_types DROP CONSTRAINT IF EXISTS hms_unit_types_rate_period_check;
ALTER TABLE hms.hms_unit_types ADD CONSTRAINT hms_unit_types_rate_period_check CHECK (rate_period IN ('hour', 'day', 'night', 'week', 'month'));

ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS starts_at timestamp;
ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS ends_at timestamp;
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS starts_at timestamp;
ALTER TABLE hms.hms_reservation_units ADD COLUMN IF NOT EXISTS ends_at timestamp;

ALTER TABLE hms.hms_reservations DROP CONSTRAINT IF EXISTS hms_reservations_times_check;
ALTER TABLE hms.hms_reservations ADD CONSTRAINT hms_reservations_times_check
    CHECK ((starts_at IS NULL AND ends_at IS NULL) OR (starts_at IS NOT NULL AND ends_at > starts_at));
ALTER TABLE hms.hms_reservation_units DROP CONSTRAINT IF EXISTS hms_reservation_units_times_check;
ALTER TABLE hms.hms_reservation_units ADD CONSTRAINT hms_reservation_units_times_check
    CHECK ((starts_at IS NULL AND ends_at IS NULL) OR (starts_at IS NOT NULL AND ends_at > starts_at));

ALTER TABLE hms.hms_reservations ADD COLUMN IF NOT EXISTS deposit_amount numeric(14,2);

CREATE OR REPLACE FUNCTION hms.hms_stay_range(arrive date, depart date, starts timestamp, ends timestamp) RETURNS tsrange
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN starts IS NOT NULL THEN tsrange(starts, ends)
                ELSE tsrange(arrive + time '12:00', depart + time '12:00') END
$$;

COMMIT;
