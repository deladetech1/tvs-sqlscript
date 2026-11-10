-- Workflows: the rest of the Go apps publish their records' lifecycle to core_platform.cp_events
-- (tvs-coreplatform-bk docs/workflows/DESIGN.md, slice 2 continued after 20261110-11).
--
-- 1. EXPENSES, HMS, CLOUDHAMS (hospital) and SCHOOL (sms): every write path of these apps (screens,
--    portals, imports, channel sync, jobs) changes the same rows, so the one central place is the
--    row itself: an AFTER trigger per table, the way their accounting events already work. Each
--    trigger function runs its work inside BEGIN ... EXCEPTION (a savepoint): a failure is a
--    WARNING in the log and the change stands without its event. The event commits with the
--    change, or not at all. Rows whose details are written after the header (a reservation's
--    rooms, a fee invoice's lines) are told at COMMIT by a deferred constraint trigger that reads
--    the row as it then is.
--
--    Plain versioned payloads ({"v": 1, ...}; nulls dropped), link_key 'suite-events', target
--    'app-coreplatform', as 20261110-11. Kept to what a workflow tests and says:
--      * CloudHAMS: ids only for patients -- no name, sex, date of birth, phone, reason, notes,
--        appointment type or department NAME (a department can say what a patient is treated for).
--      * School: students (minors) by id and student number only; no names, birth dates, payer
--        names or notes.
--      * HMS: the guest by id; no notes, special requests, cancel reasons or contact details.
--      * Expenses: the claim's figures and claimant (as exp.claim_approved already does); no
--        purpose text, email, receipts or bank details.
--
--      exp.claim_submitted / claim_returned / claim_rejected     exp_claims status
--      exp.budget_threshold_reached                              exp_budget_alerts row (80 %, 100 %, ...)
--      hms.reservation_created (deferred) / reservation_checked_in / reservation_checked_out /
--        reservation_cancelled / reservation_no_show             hms_reservations
--      hms.payment_received                                      hms_folio_lines kind 'payment'
--      hms.maintenance_reported                                  hms_maintenance_tickets row
--      hospital.patient_registered                               hospital_patients row
--      hospital.appointment_booked / appointment_cancelled /
--        appointment_missed (no-show)                            hospital_appointments
--      hospital.payment_received                                 hospital_payments (payment, deposit)
--      hospital.invoice_paid                                     hospital_invoices status 'paid'
--      sms.student_enrolled                                      sms_students row, active
--      sms.fee_invoice_issued (deferred) / fee_invoice_paid      sms_fee_invoices
--      sms.fee_payment_received                                  sms_fee_payments status 'confirmed'
--      sms.student_absent                                        sms_attendance 'unexcused', once a day
--      sms.fee_invoice_overdue                                   the sms-fees job (tvs-shared-apps-bk
--                                                                sms/suite_events.go), not a trigger
--
-- 2. SCM and MANUFACTURING already publish their domain events from one place in the app (SCM
--    emit(), behind a savepoint; Manufacturing publish(), which by its own contract fails the
--    change when the event cannot be written). This file only catalogues the ones a workflow
--    starts from; SCM's emit() adds "v": 1 to its payloads from the same release.
--
-- Idempotent; re-runs on every deploy (CREATE OR REPLACE, DROP TRIGGER IF EXISTS). Each app's block
-- skips when its tables are not in this database. This file owns the catalogue rows of the kinds it
-- names. Nothing is narrowed.

BEGIN;

-- ===================================================================== the shared helper
-- Publishes one lifecycle event: "v": 1, nulls dropped, nothing without a tenant and business (a
-- workflow belongs to a business). Errors are the CALLER's to catch (each trigger below does).
CREATE OR REPLACE FUNCTION core_platform.cp_suite_event(p_tenant text, p_bus text, p_source text, p_kind text,
                                                        p_subject text, p_payload jsonb)
RETURNS void LANGUAGE plpgsql AS $fn$
BEGIN
    IF coalesce(p_tenant, '') = '' OR coalesce(p_bus, '') = '' THEN
        RETURN;
    END IF;
    PERFORM core_platform.cp_event_publish(p_tenant, p_bus, p_source, p_kind, p_subject,
                                           jsonb_strip_nulls(coalesce(p_payload, '{}'::jsonb)) || '{"v":1}'::jsonb);
END $fn$;

COMMENT ON FUNCTION core_platform.cp_suite_event(text, text, text, text, text, jsonb) IS
    'A lifecycle event for workflows (20261110-27): v 1, nulls dropped; skipped without tenant and business.';

-- ===================================================================== Expenses
DO $blk$
BEGIN
    IF to_regclass('expenses.exp_claims') IS NULL THEN
        RAISE NOTICE 'workflows-go-apps: no Expenses here; skipping its triggers';
        RETURN;
    END IF;

    CREATE OR REPLACE FUNCTION expenses.exp_suite_claim_event() RETURNS trigger LANGUAGE plpgsql AS $fn$
    DECLARE
        k text;
    BEGIN
        BEGIN
            IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
                RETURN NULL;
            END IF;
            k := CASE NEW.status WHEN 'submitted' THEN 'exp.claim_submitted' WHEN 'returned' THEN 'exp.claim_returned'
                                 WHEN 'rejected' THEN 'exp.claim_rejected' END;
            IF k IS NULL THEN
                RETURN NULL;
            END IF;
            PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-expenses', k, NEW.id, jsonb_build_object(
                'claim_id', NEW.id, 'number', NEW.number, 'title', NEW.title, 'claimant_id', NEW.claimant_id,
                'claimant_name', NEW.claimant_name, 'project_id', NEW.project_id, 'total', round(NEW.total, 2)::text,
                'currency', btrim(NEW.currency::text), 'status', NEW.status,
                'from_status', CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END,
                'current_approver_id', NEW.current_approver_id, 'submitted_at', NEW.submitted_at));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'suite events: expense claim % not published; the change stands: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $fn$;

    DROP TRIGGER IF EXISTS exp_claims_suite_event ON expenses.exp_claims;
    CREATE TRIGGER exp_claims_suite_event AFTER INSERT OR UPDATE OF status ON expenses.exp_claims
        FOR EACH ROW EXECUTE FUNCTION expenses.exp_suite_claim_event();

    IF to_regclass('expenses.exp_budget_alerts') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION expenses.exp_suite_budget_event() RETURNS trigger LANGUAGE plpgsql AS $fn$
        DECLARE
            b record;
        BEGIN
            BEGIN
                SELECT * INTO b FROM expenses.exp_budgets WHERE id = NEW.budget_id;
                IF NOT FOUND THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(b.tenant_id, b.bus_id, 'app-expenses', 'exp.budget_threshold_reached', b.id,
                    jsonb_build_object('budget_id', b.id, 'name', b.name, 'scope', b.scope, 'scope_id', b.scope_id,
                        'scope_label', b.scope_label, 'period', b.period, 'period_start', NEW.period_start,
                        'amount', round(b.amount, 2)::text, 'currency', btrim(b.currency::text), 'level', NEW.level,
                        'exceeded', NEW.level >= 100, 'hard_stop', b.hard_stop));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: budget alert % not published; the alert stands: %', NEW.budget_id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS exp_budget_alerts_suite_event ON expenses.exp_budget_alerts;
        CREATE TRIGGER exp_budget_alerts_suite_event AFTER INSERT ON expenses.exp_budget_alerts
            FOR EACH ROW EXECUTE FUNCTION expenses.exp_suite_budget_event();
    END IF;
END $blk$;

-- ===================================================================== HMS
DO $blk$
BEGIN
    IF to_regclass('hms.hms_reservations') IS NULL THEN
        RAISE NOTICE 'workflows-go-apps: no HMS here; skipping its triggers';
        RETURN;
    END IF;

    -- The reservation as its events show it (rooms and amount from its units).
    CREATE OR REPLACE FUNCTION hms.hms_suite_reservation(p_id text) RETURNS jsonb LANGUAGE sql STABLE AS $fn$
        SELECT jsonb_build_object(
                   'reservation_id', r.id, 'code', r.code, 'status', r.status, 'source', r.source,
                   'property_id', r.property_id, 'property_name', p.name, 'guest_id', r.guest_id, 'company_id', r.company_id,
                   'arrive_on', r.arrive_on, 'depart_on', r.depart_on, 'nights', (r.depart_on - r.arrive_on),
                   'adults', r.adults, 'children', r.children, 'currency', r.currency,
                   'units', (SELECT string_agg(coalesce(u.room_name, u.name), ', ' ORDER BY u.name)
                               FROM hms.hms_reservation_units ru JOIN hms.hms_units u ON u.id = ru.unit_id
                              WHERE ru.reservation_id = r.id),
                   'amount', (SELECT round(sum(ru.amount), 2)::text FROM hms.hms_reservation_units ru WHERE ru.reservation_id = r.id),
                   'checked_in_at', r.checked_in_at, 'checked_out_at', r.checked_out_at, 'cancelled_at', r.cancelled_at)
          FROM hms.hms_reservations r LEFT JOIN hms.hms_properties p ON p.id = r.property_id
         WHERE r.id = p_id
    $fn$;

    CREATE OR REPLACE FUNCTION hms.hms_suite_reservation_status_kind(p_status text) RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
        SELECT CASE p_status WHEN 'checked_in' THEN 'hms.reservation_checked_in' WHEN 'checked_out' THEN 'hms.reservation_checked_out'
                             WHEN 'cancelled' THEN 'hms.reservation_cancelled' WHEN 'no_show' THEN 'hms.reservation_no_show' END
    $fn$;

    -- Created: at COMMIT (the rooms are written after the reservation). A walk-in written straight
    -- as checked in is also told as checked in.
    CREATE OR REPLACE FUNCTION hms.hms_suite_reservation_created() RETURNS trigger LANGUAGE plpgsql AS $fn$
    DECLARE
        p jsonb;
        k text;
    BEGIN
        BEGIN
            p := hms.hms_suite_reservation(NEW.id);
            IF p IS NULL THEN
                RETURN NULL; -- gone before commit
            END IF;
            PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hms', 'hms.reservation_created', NEW.id, p);
            k := hms.hms_suite_reservation_status_kind(NEW.status);
            IF k IS NOT NULL THEN
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hms', k, NEW.id, p);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'suite events: reservation % not published; the change stands: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $fn$;

    CREATE OR REPLACE FUNCTION hms.hms_suite_reservation_status() RETURNS trigger LANGUAGE plpgsql AS $fn$
    DECLARE
        k text;
    BEGIN
        BEGIN
            k := hms.hms_suite_reservation_status_kind(NEW.status);
            IF k IS NULL OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
                RETURN NULL;
            END IF;
            PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hms', k, NEW.id,
                hms.hms_suite_reservation(NEW.id) || jsonb_build_object('from_status', OLD.status));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'suite events: reservation % not published; the change stands: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $fn$;

    DROP TRIGGER IF EXISTS hms_reservations_suite_created ON hms.hms_reservations;
    CREATE CONSTRAINT TRIGGER hms_reservations_suite_created AFTER INSERT ON hms.hms_reservations
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION hms.hms_suite_reservation_created();
    DROP TRIGGER IF EXISTS hms_reservations_suite_status ON hms.hms_reservations;
    CREATE TRIGGER hms_reservations_suite_status AFTER UPDATE OF status ON hms.hms_reservations
        FOR EACH ROW EXECUTE FUNCTION hms.hms_suite_reservation_status();

    -- A payment on a bill (not a reversal, not a line moved from another bill).
    IF to_regclass('hms.hms_folio_lines') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION hms.hms_suite_payment() RETURNS trigger LANGUAGE plpgsql AS $fn$
        DECLARE
            f record;
        BEGIN
            BEGIN
                IF NEW.kind <> 'payment' OR NEW.reverses_line_id IS NOT NULL OR NEW.routed_from_folio_id IS NOT NULL THEN
                    RETURN NULL;
                END IF;
                SELECT fo.property_id, fo.reservation_id, fo.guest_id, fo.company_id, fo.currency, r.code
                  INTO f FROM hms.hms_folios fo LEFT JOIN hms.hms_reservations r ON r.id = fo.reservation_id
                 WHERE fo.id = NEW.folio_id;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hms', 'hms.payment_received', NEW.id,
                    jsonb_build_object('line_id', NEW.id, 'folio_id', NEW.folio_id, 'reservation_id', f.reservation_id,
                        'reservation_code', f.code, 'property_id', f.property_id, 'guest_id', f.guest_id, 'company_id', f.company_id,
                        'amount', round(NEW.amount, 2)::text, 'currency', f.currency, 'method', NEW.method,
                        'category', NEW.category, 'posted_on', NEW.posted_on));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: folio payment % not published; the payment stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS hms_folio_lines_suite_payment ON hms.hms_folio_lines;
        CREATE TRIGGER hms_folio_lines_suite_payment AFTER INSERT ON hms.hms_folio_lines
            FOR EACH ROW EXECUTE FUNCTION hms.hms_suite_payment();
    END IF;

    IF to_regclass('hms.hms_maintenance_tickets') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION hms.hms_suite_maintenance() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hms', 'hms.maintenance_reported', NEW.id,
                    jsonb_build_object('ticket_id', NEW.id, 'title', NEW.title, 'category', NEW.category, 'priority', NEW.priority,
                        'status', NEW.status, 'property_id', NEW.property_id,
                        'property_name', (SELECT name FROM hms.hms_properties WHERE id = NEW.property_id),
                        'unit_id', NEW.unit_id,
                        'unit_name', (SELECT coalesce(room_name, name) FROM hms.hms_units WHERE id = NEW.unit_id),
                        'source', NEW.source, 'from_guest', NEW.from_guest, 'takes_unit_out', NEW.takes_unit_out,
                        'assigned_to', NEW.assigned_to, 'due_on', NEW.due_on));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: maintenance ticket % not published; the ticket stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS hms_maintenance_tickets_suite_event ON hms.hms_maintenance_tickets;
        CREATE TRIGGER hms_maintenance_tickets_suite_event AFTER INSERT ON hms.hms_maintenance_tickets
            FOR EACH ROW EXECUTE FUNCTION hms.hms_suite_maintenance();
    END IF;
END $blk$;

-- ===================================================================== CloudHAMS (hospital)
DO $blk$
BEGIN
    IF to_regclass('hospital.hospital_appointments') IS NULL THEN
        RAISE NOTICE 'workflows-go-apps: no CloudHAMS here; skipping its triggers';
        RETURN;
    END IF;

    CREATE OR REPLACE FUNCTION hospital.hospital_suite_appointment() RETURNS trigger LANGUAGE plpgsql AS $fn$
    DECLARE
        k text;
    BEGIN
        BEGIN
            IF TG_OP = 'INSERT' THEN
                k := CASE WHEN NEW.status IN ('booked', 'confirmed') THEN 'hospital.appointment_booked' END;
            ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
                k := CASE NEW.status WHEN 'cancelled' THEN 'hospital.appointment_cancelled'
                                     WHEN 'no_show' THEN 'hospital.appointment_missed' END;
            END IF;
            IF k IS NULL THEN
                RETURN NULL;
            END IF;
            -- Ids only: no reason, notes, type or department name.
            PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hospital', k, NEW.id, jsonb_build_object(
                'appointment_id', NEW.id, 'patient_id', NEW.patient_id,
                'mrn', (SELECT mrn FROM hospital.hospital_patients WHERE id = NEW.patient_id),
                'facility_id', NEW.facility_id, 'department_id', NEW.department_id, 'practitioner_id', NEW.practitioner_id,
                'starts_at', NEW.starts_at, 'duration_min', NEW.duration_min, 'status', NEW.status,
                'from_status', CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END, 'source', NEW.source));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'suite events: appointment % not published; the change stands: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $fn$;

    DROP TRIGGER IF EXISTS hospital_appointments_suite_event ON hospital.hospital_appointments;
    CREATE TRIGGER hospital_appointments_suite_event AFTER INSERT OR UPDATE OF status ON hospital.hospital_appointments
        FOR EACH ROW EXECUTE FUNCTION hospital.hospital_suite_appointment();

    IF to_regclass('hospital.hospital_patients') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION hospital.hospital_suite_patient() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hospital', 'hospital.patient_registered', NEW.id,
                    jsonb_build_object('patient_id', NEW.id, 'mrn', NEW.mrn, 'facility_id', NEW.home_facility_id,
                        'is_unknown', NEW.is_unknown));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: patient % not published; the registration stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS hospital_patients_suite_event ON hospital.hospital_patients;
        CREATE TRIGGER hospital_patients_suite_event AFTER INSERT ON hospital.hospital_patients
            FOR EACH ROW EXECUTE FUNCTION hospital.hospital_suite_patient();
    END IF;

    IF to_regclass('hospital.hospital_payments') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION hospital.hospital_suite_payment() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                IF NEW.kind NOT IN ('payment', 'deposit') THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hospital', 'hospital.payment_received', NEW.id,
                    jsonb_build_object('payment_id', NEW.id, 'receipt_no', NEW.receipt_no, 'kind', NEW.kind,
                        'amount', round(NEW.amount, 2)::text, 'currency', NEW.currency, 'method', NEW.method,
                        'patient_id', NEW.patient_id, 'facility_id', NEW.facility_id));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: payment % not published; the payment stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS hospital_payments_suite_event ON hospital.hospital_payments;
        CREATE TRIGGER hospital_payments_suite_event AFTER INSERT ON hospital.hospital_payments
            FOR EACH ROW EXECUTE FUNCTION hospital.hospital_suite_payment();
    END IF;

    IF to_regclass('hospital.hospital_invoices') IS NOT NULL THEN
        -- The payer by type and id: the name of a self-paying patient is not published.
        CREATE OR REPLACE FUNCTION hospital.hospital_suite_invoice() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                IF NEW.status <> 'paid' OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-hospital', 'hospital.invoice_paid', NEW.id,
                    jsonb_build_object('invoice_id', NEW.id, 'number', NEW.number, 'customer_type', NEW.customer_type,
                        'payer_id', NEW.payer_id, 'facility_id', NEW.facility_id, 'total', round(NEW.total, 2)::text,
                        'paid', round(NEW.paid, 2)::text, 'currency', NEW.currency, 'issue_date', NEW.issue_date,
                        'due_date', NEW.due_date, 'from_status', OLD.status));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: invoice % not published; the change stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS hospital_invoices_suite_event ON hospital.hospital_invoices;
        CREATE TRIGGER hospital_invoices_suite_event AFTER UPDATE OF status ON hospital.hospital_invoices
            FOR EACH ROW EXECUTE FUNCTION hospital.hospital_suite_invoice();
    END IF;
END $blk$;

-- ===================================================================== School (sms)
DO $blk$
BEGIN
    IF to_regclass('sms.sms_students') IS NULL THEN
        RAISE NOTICE 'workflows-go-apps: no School here; skipping its triggers';
        RETURN;
    END IF;

    -- Students are minors: id, number and class only.
    CREATE OR REPLACE FUNCTION sms.sms_suite_student() RETURNS trigger LANGUAGE plpgsql AS $fn$
    BEGIN
        BEGIN
            IF NEW.status <> 'active' THEN
                RETURN NULL;
            END IF;
            PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-sms', 'sms.student_enrolled', NEW.id,
                jsonb_build_object('student_id', NEW.id, 'student_number', NEW.student_number, 'school_id', NEW.profile_id,
                    'class_id', NEW.class_id, 'class_name', NEW.class_name, 'year_group_id', NEW.year_group_id,
                    'academic_year', NEW.academic_year, 'admitted_on', NEW.admitted_on, 'application_id', NEW.application_id));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'suite events: student % not published; the enrolment stands: %', NEW.id, SQLERRM;
        END;
        RETURN NULL;
    END $fn$;

    DROP TRIGGER IF EXISTS sms_students_suite_event ON sms.sms_students;
    CREATE TRIGGER sms_students_suite_event AFTER INSERT ON sms.sms_students
        FOR EACH ROW EXECUTE FUNCTION sms.sms_suite_student();

    IF to_regclass('sms.sms_fee_invoices') IS NOT NULL THEN
        CREATE OR REPLACE FUNCTION sms.sms_suite_fee_invoice(p_id text) RETURNS jsonb LANGUAGE sql STABLE AS $fn$
            SELECT jsonb_build_object('invoice_id', i.id, 'number', i.number, 'student_id', i.student_id,
                       'student_number', (SELECT student_number FROM sms.sms_students WHERE id = i.student_id),
                       'sponsor_id', i.sponsor_id, 'school_id', i.profile_id, 'kind', i.kind, 'year_id', i.year_id,
                       'term_id', i.term_id, 'total', round(i.total, 2)::text, 'paid', round(i.paid, 2)::text,
                       'balance', round(i.total - i.paid - coalesce(i.adjusted, 0), 2)::text, 'currency', i.currency,
                       'issued_on', i.issued_on, 'due_on', i.due_on, 'status', i.status)
              FROM sms.sms_fee_invoices i WHERE i.id = p_id
        $fn$;

        -- Issued: at COMMIT (the lines and total are written after the invoice).
        CREATE OR REPLACE FUNCTION sms.sms_suite_fee_invoice_issued() RETURNS trigger LANGUAGE plpgsql AS $fn$
        DECLARE
            p jsonb;
        BEGIN
            BEGIN
                p := sms.sms_suite_fee_invoice(NEW.id);
                IF p IS NULL OR p->>'status' IN ('void', 'written_off') THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-sms', 'sms.fee_invoice_issued', NEW.id, p);
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: fee invoice % not published; the invoice stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        CREATE OR REPLACE FUNCTION sms.sms_suite_fee_invoice_paid() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                IF NEW.status <> 'paid' OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-sms', 'sms.fee_invoice_paid', NEW.id,
                    sms.sms_suite_fee_invoice(NEW.id) || jsonb_build_object('from_status', OLD.status));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: fee invoice % not published; the change stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS sms_fee_invoices_suite_issued ON sms.sms_fee_invoices;
        CREATE CONSTRAINT TRIGGER sms_fee_invoices_suite_issued AFTER INSERT ON sms.sms_fee_invoices
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION sms.sms_suite_fee_invoice_issued();
        DROP TRIGGER IF EXISTS sms_fee_invoices_suite_paid ON sms.sms_fee_invoices;
        CREATE TRIGGER sms_fee_invoices_suite_paid AFTER UPDATE OF status ON sms.sms_fee_invoices
            FOR EACH ROW EXECUTE FUNCTION sms.sms_suite_fee_invoice_paid();
    END IF;

    IF to_regclass('sms.sms_fee_payments') IS NOT NULL THEN
        -- Confirmed money only (a pending mobile-money or bank payment is told once confirmed); no payer name.
        CREATE OR REPLACE FUNCTION sms.sms_suite_fee_payment() RETURNS trigger LANGUAGE plpgsql AS $fn$
        BEGIN
            BEGIN
                IF NEW.status <> 'confirmed' OR (TG_OP = 'UPDATE' AND OLD.status = 'confirmed') THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(NEW.tenant_id, NEW.bus_id, 'app-sms', 'sms.fee_payment_received', NEW.id,
                    jsonb_build_object('payment_id', NEW.id, 'receipt_number', NEW.receipt_number, 'student_id', NEW.student_id,
                        'student_number', (SELECT student_number FROM sms.sms_students WHERE id = NEW.student_id),
                        'sponsor_id', NEW.sponsor_id, 'school_id', NEW.profile_id, 'amount', round(NEW.amount, 2)::text,
                        'currency', NEW.currency, 'method', NEW.method, 'received_on', NEW.received_on));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: fee payment % not published; the payment stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS sms_fee_payments_suite_event ON sms.sms_fee_payments;
        CREATE TRIGGER sms_fee_payments_suite_event AFTER INSERT OR UPDATE OF status ON sms.sms_fee_payments
            FOR EACH ROW EXECUTE FUNCTION sms.sms_suite_fee_payment();
    END IF;

    IF to_regclass('sms.sms_attendance') IS NOT NULL THEN
        -- An unexcused absence, told once per student and school day (a student missing five lessons
        -- is one event: the first register that marked them).
        CREATE OR REPLACE FUNCTION sms.sms_suite_absence() RETURNS trigger LANGUAGE plpgsql AS $fn$
        DECLARE
            g record;
        BEGIN
            BEGIN
                IF NEW.kind <> 'unexcused' OR (TG_OP = 'UPDATE' AND OLD.kind = 'unexcused') THEN
                    RETURN NULL;
                END IF;
                SELECT tenant_id, bus_id, profile_id, class_id, taken_on, period_id, subject_id
                  INTO g FROM sms.sms_attendance_registers WHERE id = NEW.register_id;
                IF NOT FOUND THEN
                    RETURN NULL;
                END IF;
                IF EXISTS (SELECT 1 FROM core_platform.cp_events e
                            WHERE e.subject_id = NEW.student_id AND e.kind = 'sms.student_absent'
                              AND e.tenant_id = g.tenant_id AND e.payload->>'date' = g.taken_on::text) THEN
                    RETURN NULL;
                END IF;
                PERFORM core_platform.cp_suite_event(g.tenant_id, g.bus_id, 'app-sms', 'sms.student_absent', NEW.student_id,
                    jsonb_build_object('student_id', NEW.student_id,
                        'student_number', (SELECT student_number FROM sms.sms_students WHERE id = NEW.student_id),
                        'school_id', g.profile_id, 'class_id', g.class_id, 'date', g.taken_on, 'register_id', NEW.register_id,
                        'period_id', g.period_id, 'subject_id', g.subject_id, 'source', NEW.source));
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'suite events: absence % not published; the mark stands: %', NEW.id, SQLERRM;
            END;
            RETURN NULL;
        END $fn$;

        DROP TRIGGER IF EXISTS sms_attendance_suite_absence ON sms.sms_attendance;
        CREATE TRIGGER sms_attendance_suite_absence AFTER INSERT OR UPDATE OF kind ON sms.sms_attendance
            FOR EACH ROW EXECUTE FUNCTION sms.sms_suite_absence();
    END IF;
END $blk$;

-- ===================================================================== the event catalogue
DO $blk$
BEGIN
    IF to_regclass('core_platform.cp_event_schemas') IS NULL THEN
        RAISE NOTICE 'workflows-go-apps: no event catalogue here (20261102-50 not applied); skipping its rows';
        RETURN;
    END IF;

    WITH v AS (SELECT '{"v":{"type":"integer","minimum":1}}'::jsonb AS p
    ), claim AS (
        SELECT (SELECT p FROM v) || '{"claim_id":{"type":"string"},"number":{"type":"string"},"title":{"type":"string"},
                 "claimant_id":{"type":"string"},"claimant_name":{"type":"string"},"project_id":{"type":"string"},
                 "total":{"type":"string"},"currency":{"type":"string"},"status":{"type":"string"},"from_status":{"type":"string"},
                 "current_approver_id":{"type":"string"},"submitted_at":{"type":"string","format":"date-time"}}'::jsonb AS p
    ), reservation AS (
        SELECT (SELECT p FROM v) || '{"reservation_id":{"type":"string"},"code":{"type":"string"},"status":{"type":"string"},
                 "from_status":{"type":"string"},"source":{"type":"string"},"property_id":{"type":"string"},
                 "property_name":{"type":"string"},"guest_id":{"type":"string"},"company_id":{"type":"string"},
                 "arrive_on":{"type":"string","format":"date"},"depart_on":{"type":"string","format":"date"},
                 "nights":{"type":"integer"},"adults":{"type":"integer"},"children":{"type":"integer"},
                 "units":{"type":"string"},"amount":{"type":"string"},"currency":{"type":"string"},
                 "checked_in_at":{"type":"string","format":"date-time"},"checked_out_at":{"type":"string","format":"date-time"},
                 "cancelled_at":{"type":"string","format":"date-time"}}'::jsonb AS p
    ), appointment AS (
        SELECT (SELECT p FROM v) || '{"appointment_id":{"type":"string"},"patient_id":{"type":"string"},"mrn":{"type":"string"},
                 "facility_id":{"type":"string"},"department_id":{"type":"string"},"practitioner_id":{"type":"string"},
                 "starts_at":{"type":"string","format":"date-time"},"duration_min":{"type":"integer"},"status":{"type":"string"},
                 "from_status":{"type":"string"},"source":{"type":"string"}}'::jsonb AS p
    ), fee_invoice AS (
        SELECT (SELECT p FROM v) || '{"invoice_id":{"type":"string"},"number":{"type":"string"},"student_id":{"type":"string"},
                 "student_number":{"type":"string"},"sponsor_id":{"type":"string"},"school_id":{"type":"string"},
                 "kind":{"type":"string"},"year_id":{"type":"string"},"term_id":{"type":"string"},"total":{"type":"string"},
                 "paid":{"type":"string"},"balance":{"type":"string"},"currency":{"type":"string"},
                 "issued_on":{"type":"string","format":"date"},"due_on":{"type":"string","format":"date"},
                 "status":{"type":"string"},"from_status":{"type":"string"},"days_overdue":{"type":"integer"}}'::jsonb AS p
    ), scm_doc AS (
        SELECT (SELECT p FROM v) || '{"number":{"type":"string"},"total":{"type":"string"},"currency":{"type":"string"},
                 "supplier_id":{"type":"string"},"reason":{"type":"string"},"auto":{"type":"boolean"},
                 "po_id":{"type":"string"},"po_number":{"type":"string"},"receipt_id":{"type":"string"},
                 "warehouse_id":{"type":"string"},"confirmed_date":{"type":"string","format":"date"}}'::jsonb AS p
    ), mfg_order AS (
        SELECT (SELECT p FROM v) || '{"production_order_id":{"type":"string"},"number":{"type":"string"},"plant_id":{"type":"string"},
                 "status":{"type":"string"},"product_id":{"type":"string"},"qty":{"type":"string"},"unit":{"type":"string"},
                 "due_date":{"type":"string","format":"date"},"priority":{"type":"integer"},"mode":{"type":"string"},
                 "business_date":{"type":"string","format":"date"}}'::jsonb AS p
    ), kinds (kind, source_app, description, props, required) AS (
        -- Expenses
        SELECT 'exp.claim_submitted', 'app-expenses', 'An expense claim was submitted for approval.',
               (SELECT p FROM claim), '["v","claim_id"]'::jsonb
        UNION ALL SELECT 'exp.claim_returned', 'app-expenses', 'An expense claim was sent back to the claimant for changes.',
               (SELECT p FROM claim), '["v","claim_id"]'::jsonb
        UNION ALL SELECT 'exp.claim_rejected', 'app-expenses', 'An expense claim was rejected.',
               (SELECT p FROM claim), '["v","claim_id"]'::jsonb
        UNION ALL SELECT 'exp.budget_threshold_reached', 'app-expenses', 'Spending reached an alert level of a budget (100 = exceeded).',
               (SELECT p FROM v) || '{"budget_id":{"type":"string"},"name":{"type":"string"},"scope":{"type":"string"},
                 "scope_id":{"type":"string"},"scope_label":{"type":"string"},"period":{"type":"string"},
                 "period_start":{"type":"string","format":"date"},"amount":{"type":"string"},"currency":{"type":"string"},
                 "level":{"type":"integer"},"exceeded":{"type":"boolean"},"hard_stop":{"type":"boolean"}}'::jsonb,
               '["v","budget_id","level"]'::jsonb
        -- HMS
        UNION ALL SELECT 'hms.reservation_created', 'app-hms', 'A reservation was made (any channel).',
               (SELECT p FROM reservation), '["v","reservation_id"]'::jsonb
        UNION ALL SELECT 'hms.reservation_checked_in', 'app-hms', 'A guest checked in.',
               (SELECT p FROM reservation), '["v","reservation_id"]'::jsonb
        UNION ALL SELECT 'hms.reservation_checked_out', 'app-hms', 'A guest checked out.',
               (SELECT p FROM reservation), '["v","reservation_id"]'::jsonb
        UNION ALL SELECT 'hms.reservation_cancelled', 'app-hms', 'A reservation was cancelled.',
               (SELECT p FROM reservation), '["v","reservation_id"]'::jsonb
        UNION ALL SELECT 'hms.reservation_no_show', 'app-hms', 'A reservation was marked a no-show.',
               (SELECT p FROM reservation), '["v","reservation_id"]'::jsonb
        UNION ALL SELECT 'hms.payment_received', 'app-hms', 'A payment was taken on a guest or company bill.',
               (SELECT p FROM v) || '{"line_id":{"type":"string"},"folio_id":{"type":"string"},"reservation_id":{"type":"string"},
                 "reservation_code":{"type":"string"},"property_id":{"type":"string"},"guest_id":{"type":"string"},
                 "company_id":{"type":"string"},"amount":{"type":"string"},"currency":{"type":"string"},"method":{"type":"string"},
                 "category":{"type":"string"},"posted_on":{"type":"string","format":"date"}}'::jsonb,
               '["v","line_id","amount"]'::jsonb
        UNION ALL SELECT 'hms.maintenance_reported', 'app-hms', 'A maintenance request was reported.',
               (SELECT p FROM v) || '{"ticket_id":{"type":"string"},"title":{"type":"string"},"category":{"type":"string"},
                 "priority":{"type":"string"},"status":{"type":"string"},"property_id":{"type":"string"},
                 "property_name":{"type":"string"},"unit_id":{"type":"string"},"unit_name":{"type":"string"},
                 "source":{"type":"string"},"from_guest":{"type":"boolean"},"takes_unit_out":{"type":"boolean"},
                 "assigned_to":{"type":"string"},"due_on":{"type":"string","format":"date"}}'::jsonb,
               '["v","ticket_id"]'::jsonb
        -- CloudHAMS
        UNION ALL SELECT 'hospital.patient_registered', 'app-hospital', 'A patient was registered (ids only).',
               (SELECT p FROM v) || '{"patient_id":{"type":"string"},"mrn":{"type":"string"},"facility_id":{"type":"string"},
                 "is_unknown":{"type":"boolean"}}'::jsonb, '["v","patient_id"]'::jsonb
        UNION ALL SELECT 'hospital.appointment_booked', 'app-hospital', 'An appointment was booked (ids only, no clinical details).',
               (SELECT p FROM appointment), '["v","appointment_id","patient_id"]'::jsonb
        UNION ALL SELECT 'hospital.appointment_cancelled', 'app-hospital', 'An appointment was cancelled.',
               (SELECT p FROM appointment), '["v","appointment_id","patient_id"]'::jsonb
        UNION ALL SELECT 'hospital.appointment_missed', 'app-hospital', 'A patient did not attend an appointment (no-show).',
               (SELECT p FROM appointment), '["v","appointment_id","patient_id"]'::jsonb
        UNION ALL SELECT 'hospital.payment_received', 'app-hospital', 'A payment or deposit was received at the cashier or online.',
               (SELECT p FROM v) || '{"payment_id":{"type":"string"},"receipt_no":{"type":"string"},"kind":{"enum":["payment","deposit"]},
                 "amount":{"type":"string"},"currency":{"type":"string"},"method":{"type":"string"},"patient_id":{"type":"string"},
                 "facility_id":{"type":"string"}}'::jsonb, '["v","payment_id","amount"]'::jsonb
        UNION ALL SELECT 'hospital.invoice_paid', 'app-hospital', 'An invoice to a payer, company or other customer was paid in full.',
               (SELECT p FROM v) || '{"invoice_id":{"type":"string"},"number":{"type":"string"},"customer_type":{"type":"string"},
                 "payer_id":{"type":"string"},"facility_id":{"type":"string"},"total":{"type":"string"},"paid":{"type":"string"},
                 "currency":{"type":"string"},"issue_date":{"type":"string","format":"date"},
                 "due_date":{"type":"string","format":"date"},"from_status":{"type":"string"}}'::jsonb,
               '["v","invoice_id"]'::jsonb
        -- School
        UNION ALL SELECT 'sms.student_enrolled', 'app-sms', 'A student was enrolled (id, number and class only).',
               (SELECT p FROM v) || '{"student_id":{"type":"string"},"student_number":{"type":"string"},"school_id":{"type":"string"},
                 "class_id":{"type":"string"},"class_name":{"type":"string"},"year_group_id":{"type":"string"},
                 "academic_year":{"type":"string"},"admitted_on":{"type":"string","format":"date"},
                 "application_id":{"type":"string"}}'::jsonb, '["v","student_id"]'::jsonb
        UNION ALL SELECT 'sms.fee_invoice_issued', 'app-sms', 'A fee invoice was issued.',
               (SELECT p FROM fee_invoice), '["v","invoice_id"]'::jsonb
        UNION ALL SELECT 'sms.fee_invoice_paid', 'app-sms', 'A fee invoice was paid in full.',
               (SELECT p FROM fee_invoice), '["v","invoice_id"]'::jsonb
        UNION ALL SELECT 'sms.fee_invoice_overdue', 'app-sms', 'A fee invoice passed its due date unpaid (told once per due date).',
               (SELECT p FROM fee_invoice), '["v","invoice_id","due_on"]'::jsonb
        UNION ALL SELECT 'sms.fee_payment_received', 'app-sms', 'A fee payment was received and confirmed.',
               (SELECT p FROM v) || '{"payment_id":{"type":"string"},"receipt_number":{"type":"string"},"student_id":{"type":"string"},
                 "student_number":{"type":"string"},"sponsor_id":{"type":"string"},"school_id":{"type":"string"},
                 "amount":{"type":"string"},"currency":{"type":"string"},"method":{"type":"string"},
                 "received_on":{"type":"string","format":"date"}}'::jsonb, '["v","payment_id","amount"]'::jsonb
        UNION ALL SELECT 'sms.student_absent', 'app-sms', 'A student was marked absent without a reason (once per school day).',
               (SELECT p FROM v) || '{"student_id":{"type":"string"},"student_number":{"type":"string"},"school_id":{"type":"string"},
                 "class_id":{"type":"string"},"date":{"type":"string","format":"date"},"register_id":{"type":"string"},
                 "period_id":{"type":"string"},"subject_id":{"type":"string"},"source":{"type":"string"}}'::jsonb,
               '["v","student_id","date"]'::jsonb
        -- Supply Chain (emit(), scm/base.go)
        UNION ALL SELECT 'requisition.submitted', 'app-scm', 'A purchase requisition was submitted for approval.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'requisition.approved', 'app-scm', 'A purchase requisition was approved.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'requisition.rejected', 'app-scm', 'A purchase requisition was rejected.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'requisition.converted', 'app-scm', 'A requisition was turned into a purchase order.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.submitted', 'app-scm', 'A purchase order was submitted for approval.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.approved', 'app-scm', 'A purchase order was approved.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.sent', 'app-scm', 'A purchase order was sent to the supplier.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.confirmed', 'app-scm', 'The supplier confirmed a purchase order.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.partially_received', 'app-scm', 'Part of a purchase order was received.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.received', 'app-scm', 'A purchase order was received in full.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'purchase_order.cancelled', 'app-scm', 'A purchase order was cancelled.', (SELECT p FROM scm_doc), '["v","number"]'::jsonb
        UNION ALL SELECT 'receipt.posted', 'app-scm', 'Goods were received into a warehouse (a goods receipt was posted).',
               (SELECT p FROM scm_doc) || '{"total_qty":{"type":"string"},"total_cost":{"type":"string"}}'::jsonb, '["v","number"]'::jsonb
        UNION ALL SELECT 'exception.raised', 'app-scm', 'The control tower raised an exception (stock below reorder point, PO overdue, ...).',
               (SELECT p FROM v) || '{"kind":{"type":"string"},"severity":{"type":"string"},"subject_type":{"type":"string"},
                 "subject_id":{"type":"string"},"title":{"type":"string"},"impact_amount":{"type":"string"},
                 "due_date":{"type":"string","format":"date"}}'::jsonb, '["v","kind","severity"]'::jsonb
        -- Manufacturing (publish(), mfg/common.go)
        UNION ALL SELECT 'production_order.created', 'app-mfg', 'A production (work) order was created.', (SELECT p FROM mfg_order), '["v","production_order_id"]'::jsonb
        UNION ALL SELECT 'production_order.released', 'app-mfg', 'A production order was released to the floor.', (SELECT p FROM mfg_order), '["v","production_order_id"]'::jsonb
        UNION ALL SELECT 'production_order.completed', 'app-mfg', 'A production order was completed (output received).', (SELECT p FROM mfg_order), '["v","production_order_id"]'::jsonb
        UNION ALL SELECT 'ncr.opened', 'app-mfg', 'A non-conformance report (NCR) was raised.',
               (SELECT p FROM v) || '{"ncr_id":{"type":"string"},"number":{"type":"string"},"source":{"type":"string"},
                 "source_id":{"type":"string"},"product_id":{"type":"string"},"severity":{"type":"string"},
                 "qty":{"type":"string"},"unit":{"type":"string"}}'::jsonb, '["v","ncr_id"]'::jsonb
        UNION ALL SELECT 'readiness.changed', 'app-mfg', 'A readiness signal of an order changed colour (material red = a material shortage).',
               (SELECT p FROM mfg_order) || '{"dimension":{"enum":["material","capacity","maintenance","quality"]},
                 "from":{"type":"string"},"to":{"type":"string"},"reason":{"type":"string"}}'::jsonb,
               '["v","production_order_id","dimension"]'::jsonb
    )
    INSERT INTO core_platform.cp_event_schemas (kind, version, link_key, source_app, target_app, phase, description, schema, updated_at)
    SELECT k.kind, 1, 'suite-events', k.source_app, 'app-coreplatform', 1, k.description,
           jsonb_build_object('$schema', 'https://json-schema.org/draft/2020-12/schema', 'type', 'object',
                              'title', k.kind || ' v1', 'required', k.required, 'properties', k.props), now()
      FROM kinds k
    ON CONFLICT (kind, version) DO UPDATE SET
        link_key = EXCLUDED.link_key, source_app = EXCLUDED.source_app, target_app = EXCLUDED.target_app,
        phase = EXCLUDED.phase, description = EXCLUDED.description, schema = EXCLUDED.schema,
        updated_at = CASE WHEN core_platform.cp_event_schemas.schema IS DISTINCT FROM EXCLUDED.schema
                            OR core_platform.cp_event_schemas.description IS DISTINCT FROM EXCLUDED.description
                          THEN now() ELSE core_platform.cp_event_schemas.updated_at END;
END $blk$;

-- ===================================================================== invariants, not counts
DO $blk$
DECLARE
    bad text;
BEGIN
    -- Every trigger this file creates is there whenever its table is.
    SELECT string_agg(t.tbl || ' ' || t.trg, ', ') INTO bad
      FROM (VALUES ('expenses.exp_claims', 'exp_claims_suite_event'),
                   ('expenses.exp_budget_alerts', 'exp_budget_alerts_suite_event'),
                   ('hms.hms_reservations', 'hms_reservations_suite_created'),
                   ('hms.hms_reservations', 'hms_reservations_suite_status'),
                   ('hms.hms_folio_lines', 'hms_folio_lines_suite_payment'),
                   ('hms.hms_maintenance_tickets', 'hms_maintenance_tickets_suite_event'),
                   ('hospital.hospital_appointments', 'hospital_appointments_suite_event'),
                   ('hospital.hospital_patients', 'hospital_patients_suite_event'),
                   ('hospital.hospital_payments', 'hospital_payments_suite_event'),
                   ('hospital.hospital_invoices', 'hospital_invoices_suite_event'),
                   ('sms.sms_students', 'sms_students_suite_event'),
                   ('sms.sms_fee_invoices', 'sms_fee_invoices_suite_issued'),
                   ('sms.sms_fee_invoices', 'sms_fee_invoices_suite_paid'),
                   ('sms.sms_fee_payments', 'sms_fee_payments_suite_event'),
                   ('sms.sms_attendance', 'sms_attendance_suite_absence')) AS t(tbl, trg)
     WHERE to_regclass(t.tbl) IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_trigger g WHERE g.tgrelid = to_regclass(t.tbl) AND g.tgname = t.trg);
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'workflows-go-apps: lifecycle triggers missing: %', bad;
    END IF;

    IF to_regclass('core_platform.cp_event_schemas') IS NOT NULL THEN
        -- The prefixed lifecycle kinds name their sender, and every row here is versioned.
        SELECT string_agg(kind || ' v' || version, ', ') INTO bad FROM core_platform.cp_event_schemas
         WHERE link_key = 'suite-events'
           AND source_app IN ('app-expenses', 'app-hms', 'app-hospital', 'app-sms', 'app-scm', 'app-mfg')
           AND (NOT (schema -> 'required') @> '["v"]'::jsonb
                OR (source_app = 'app-expenses' AND split_part(kind, '.', 1) <> 'exp')
                OR (source_app = 'app-hms' AND split_part(kind, '.', 1) <> 'hms')
                OR (source_app = 'app-hospital' AND split_part(kind, '.', 1) <> 'hospital')
                OR (source_app = 'app-sms' AND split_part(kind, '.', 1) <> 'sms'));
        IF bad IS NOT NULL THEN
            RAISE EXCEPTION 'workflows-go-apps: lifecycle rows not versioned, or whose prefix does not name the sender: %', bad;
        END IF;
    END IF;
END $blk$;

COMMIT;
