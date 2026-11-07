-- CloudHams round 6: emergency and trauma care, public health and rehabilitation as modules
-- (record kinds in tvs-shared-apps-bk internal/apps/hospital/defs_r6.go). The controlled drugs
-- register, laboratory quality control, pre-operative assessment, transfusion observations,
-- delirium, frailty, alcohol, restraint, spirometry, IPSS, the risk register, policy documents,
-- mortality reviews, contracts and porters join modules that already exist.
-- Idempotent; safe to re-run.

BEGIN;

SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_modules_check', $q$'rehab'$q$,
    $q$CHECK (modules IS NULL OR modules <@ ARRAY['appointments', 'queue', 'opd', 'lab', 'pharmacy', 'ipd', 'insurance',
      'theatre', 'maternity', 'child_health', 'icu', 'dialysis', 'dental', 'eye', 'mental_health', 'physio', 'programmes',
      'blood_bank', 'imaging', 'inventory', 'procurement', 'support', 'relations', 'telemedicine', 'portal', 'reports',
      'nursing', 'referrals', 'pathology', 'certificates', 'quality', 'rosters', 'integrations',
      'medication_safety', 'consent', 'nutrition', 'social_work', 'cardiology', 'oncology', 'neonatal', 'palliative',
      'clinics', 'staff', 'research', 'emergency_care', 'public_health', 'rehab']::text[])$q$);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.emergency-care',  'app-hospital', 'Emergency & Trauma', 1, 'Trauma assessment with the Revised Trauma Score, burns with Parkland fluids, cardiac arrests timed, the sepsis hour-one bundle, poisoning and snakebite'),
('hospital.public-health',   'app-hospital', 'Public Health',      1, 'Notifiable diseases reported in time, contact tracing to the end of incubation, community outreach'),
('hospital.rehabilitation',  'app-hospital', 'Rehabilitation',     2, 'Barthel index, swallow screens, occupational and speech therapy, prostheses and assistive devices')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
