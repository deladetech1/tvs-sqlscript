-- CloudHams round 5: more of what hospitals run. New modules, each a set of record kinds in
-- hospital_entries defined in tvs-shared-apps-bk internal/apps/hospital/defs_r5.go: medication
-- safety, consent and directives, nutrition, social work, cardiology, oncology, newborn care,
-- palliative and home care, specialist clinics, staff and training, research. Quality, nursing and
-- support services gain kinds under the features they already have.
-- Idempotent; safe to re-run.

BEGIN;

SELECT hospital.widen_check('hospital.hospital_facilities', 'hospital_facilities_modules_check', $q$'research'$q$,
    $q$CHECK (modules IS NULL OR modules <@ ARRAY['appointments', 'queue', 'opd', 'lab', 'pharmacy', 'ipd', 'insurance',
      'theatre', 'maternity', 'child_health', 'icu', 'dialysis', 'dental', 'eye', 'mental_health', 'physio', 'programmes',
      'blood_bank', 'imaging', 'inventory', 'procurement', 'support', 'relations', 'telemedicine', 'portal', 'reports',
      'nursing', 'referrals', 'pathology', 'certificates', 'quality', 'rosters', 'integrations',
      'medication_safety', 'consent', 'nutrition', 'social_work', 'cardiology', 'oncology', 'neonatal', 'palliative',
      'clinics', 'staff', 'research']::text[])$q$);

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('hospital.medication-safety', 'app-hospital', 'Medication Safety',         1, 'Medicines reconciliation, adverse drug reactions with Naranjo causality and the allergy recorded, pharmacist interventions'),
('hospital.consent',           'app-hospital', 'Consent & Directives',      1, 'Informed consent signed and witnessed, advance directives with DNR shown on the patient, refusals of treatment'),
('hospital.nutrition',         'app-hospital', 'Nutrition & Dietetics',     2, 'MUST screening, child malnutrition by MUAC, nutrition plans'),
('hospital.social-work',       'app-hospital', 'Social Work & Counselling', 2, 'Social assessments with safeguarding, approved assistance, counselling sessions'),
('hospital.cardiology',        'app-hospital', 'Cardiology',                2, 'ECGs with QTc, echocardiograms, cardiac procedures charged when done'),
('hospital.oncology',          'app-hospital', 'Oncology',                  3, 'The cancer register with TNM staging, chemotherapy dosed by body surface area and held for low counts, tumour boards'),
('hospital.neonatal',          'app-hospital', 'Newborn Care',              3, 'Newborn unit admissions, observations with danger signs, jaundice and phototherapy, kangaroo mother care'),
('hospital.palliative',        'app-hospital', 'Palliative & Home Care',    2, 'Symptom scores (ESAS), home visits and equipment lent to patients'),
('hospital.clinics',           'app-hospital', 'Specialist Clinics',        2, 'ENT, audiograms graded by WHO, skin lesions, endoscopy, fractures and casts'),
('hospital.staff',             'app-hospital', 'Staff & Training',          2, 'Leave approved by someone else and kept off the roster, training with certificates that lapse'),
('hospital.research',          'app-hospital', 'Research & Trials',         3, 'Studies with ethics approval, participants enrolled only after consent, adverse events reported in time')
ON CONFLICT (feature_key) DO UPDATE SET app_id = EXCLUDED.app_id, title = EXCLUDED.title, min_tier_rank = EXCLUDED.min_tier_rank,
    description = EXCLUDED.description, is_active = true;

COMMIT;
