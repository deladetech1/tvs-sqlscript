-- A guardian's photo, for the record and for the gate to check the face of whoever collects a child.
-- Idempotent: re-runs on every deploy.

SELECT sms.widen_check('sms.sms_files', 'sms_files_entity_check', $q$'guardian'$q$, $q$CHECK (entity_type IS NULL OR entity_type IN
    ('profile', 'application', 'enquiry', 'family', 'guardian', 'student', 'leave_request', 'assignment', 'submission', 'class_resource', 'pickup_person', 'incident',
     'safeguarding', 'achievement', 'service_hours', 'trip', 'staff', 'staff_document', 'staff_check', 'job_application', 'staff_leave', 'payslip',
     'staff_cpd', 'gl_expense', 'gl_asset', 'maintenance', 'hs_record', 'newsletter', 'announcement'))$q$);
