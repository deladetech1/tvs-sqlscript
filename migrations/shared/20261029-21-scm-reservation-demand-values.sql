-- SCM: what a reservation may hold stock for (scm_reservations.demand_type, 20261029-20). The list
-- lives only here: to change it, edit this file. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE scm.scm_reservations DROP CONSTRAINT IF EXISTS scm_reservations_demand_type_check;
ALTER TABLE scm.scm_reservations ADD CONSTRAINT scm_reservations_demand_type_check CHECK (demand_type IN
    ('sales_order_line', 'production_order', 'maintenance_order', 'transfer'));

COMMIT;
