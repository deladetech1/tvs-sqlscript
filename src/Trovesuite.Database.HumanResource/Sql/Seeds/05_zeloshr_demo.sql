-- ZelosHR sprint demo data (idempotent). Tenant: demo-tenant | Org: org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a
-- Apply when TVS_SEED_ZELOSHR_DEMO=1 during tvs-db deploy

-- Demo seed for frontend alignment (idempotent)
-- Tenant: demo-tenant | Org: org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a

INSERT INTO zeloshr.zhr_branches (id, tenant_id, org_id, name, created_at, updated_at)
VALUES
    ('a1000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Accra HQ', NOW(), NOW()),
    ('a1000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Kumasi', NOW(), NOW()),
    ('a1000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Takoradi', NOW(), NOW()),
    ('a1000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Tema', NOW(), NOW())
ON CONFLICT (tenant_id, org_id, name) DO NOTHING;

INSERT INTO zeloshr.zhr_departments (id, tenant_id, org_id, name, parent_department_id, created_at, updated_at)
VALUES
    ('b1000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Engineering', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Frontend Engineering', 'b1000001-0000-4000-8000-000000000001', NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Backend Engineering', 'b1000001-0000-4000-8000-000000000001', NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'DevOps & Platform', 'b1000001-0000-4000-8000-000000000001', NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000005', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Product', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000006', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Product Design', 'b1000001-0000-4000-8000-000000000005', NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000007', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Marketing', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000008', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Finance', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000009', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'People', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000010', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Data & Insights', NULL, NOW(), NOW()),
    ('b1000001-0000-4000-8000-000000000099', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Legacy Ops', NULL, NOW(), NOW())
ON CONFLICT (tenant_id, org_id, name) DO NOTHING;

UPDATE zeloshr.zhr_departments SET is_archived = TRUE WHERE id = 'b1000001-0000-4000-8000-000000000099';

INSERT INTO zeloshr.zhr_employees (
    id, employee_code, tenant_id, org_id,
    first_name, last_name, date_of_birth, gender, nationality,
    ghana_card_number, personal_email, personal_phone, residential_address, ghana_post_gps,
    lifecycle_state, job_title, department_id, branch_id, employment_type,
    manager_id, employment_status, contract_type, employment_start_date, probation_end_date,
    created_at, updated_at
)
VALUES
    ('e1000001-0000-4000-8000-000000000001', 'ZEL-0042', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Ama', 'Asante', '1992-03-12', 'Female', 'Ghanaian', 'GHA-100000001', 'ama.asante@zeloshr.demo', '+233201000001', 'Accra', 'GA-001', 'Active',
     'Senior Product Designer', 'b1000001-0000-4000-8000-000000000005', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     'e1000001-0000-4000-8000-000000000010', 'Active', 'Permanent', '2023-01-15', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000002', 'ZEL-0089', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Kwame', 'Asare', '1994-07-22', 'Male', 'Ghanaian', 'GHA-100000002', 'kwame.asare@zeloshr.demo', '+233201000002', 'Accra', 'GA-002', 'Active',
     'Data Analyst', 'b1000001-0000-4000-8000-000000000010', 'a1000001-0000-4000-8000-000000000001', 'Contractor',
     'e1000001-0000-4000-8000-000000000003', 'Probation', 'Fixed-term', '2024-06-01', '2025-06-01', NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000003', 'ZEL-0072', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Yaw', 'Appiah', '1988-11-05', 'Male', 'Ghanaian', 'GHA-100000003', 'yaw.appiah@zeloshr.demo', '+233201000003', 'Accra', 'GA-003', 'Terminated',
     'Head of Marketing', 'b1000001-0000-4000-8000-000000000007', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     'e1000001-0000-4000-8000-000000000010', 'Terminated', 'Permanent', '2019-04-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000004', 'ZEL-0015', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Kofi', 'Mensah', '1991-01-18', 'Male', 'Ghanaian', 'GHA-100000004', 'kofi.mensah@zeloshr.demo', '+233201000004', 'Accra', 'GA-004', 'Active',
     'Software Engineer', 'b1000001-0000-4000-8000-000000000002', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     'e1000001-0000-4000-8000-000000000001', 'Active', 'Permanent', '2022-08-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000005', 'ZEL-0033', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Abena', 'Owusu', '1993-09-30', 'Female', 'Ghanaian', 'GHA-100000005', 'abena.owusu@zeloshr.demo', '+233201000005', 'Kumasi', 'GA-005', 'Active',
     'Marketing Lead', 'b1000001-0000-4000-8000-000000000007', 'a1000001-0000-4000-8000-000000000002', 'Full-time',
     'e1000001-0000-4000-8000-000000000003', 'Active', 'Fixed-term', '2021-03-10', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000006', 'ZEL-0056', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Adwoa', 'Bediako', '1990-12-02', 'Female', 'Ghanaian', 'GHA-100000006', 'adwoa.bediako@zeloshr.demo', '+233201000006', 'Accra', 'GA-006', 'Active',
     'VP Engineering', 'b1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     NULL, 'Active', 'Permanent', '2018-02-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000007', 'ZEL-0061', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Serwa', 'Acheampong', '1987-05-14', 'Female', 'Ghanaian', 'GHA-100000007', 'serwa.acheampong@zeloshr.demo', '+233201000007', 'Accra', 'GA-007', 'Active',
     'People Operations', 'b1000001-0000-4000-8000-000000000009', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     'e1000001-0000-4000-8000-000000000010', 'Active', 'Permanent', '2020-07-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000008', 'ZEL-0028', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Kwesi', 'Owusu', '1989-08-21', 'Male', 'Ghanaian', 'GHA-100000008', 'kwesi.owusu@zeloshr.demo', '+233201000008', 'Accra', 'GA-008', 'Active',
     'Director of Product', 'b1000001-0000-4000-8000-000000000005', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     'e1000001-0000-4000-8000-000000000010', 'Active', 'Permanent', '2017-11-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000009', 'ZEL-0001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Esi', 'Quainoo', '1985-02-28', 'Female', 'Ghanaian', 'GHA-100000009', 'esi.quainoo@zeloshr.demo', '+233201000009', 'Accra', 'GA-009', 'Active',
     'Managing Director', 'b1000001-0000-4000-8000-000000000009', 'a1000001-0000-4000-8000-000000000001', 'Full-time',
     NULL, 'Active', 'Permanent', '2015-01-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000010', 'ZEL-0010', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Kwame', 'Boateng', '1986-06-17', 'Male', 'Ghanaian', 'GHA-100000010', 'kwame.boateng@zeloshr.demo', '+233201000010', 'Tema', 'GA-010', 'Active',
     'Engineering Manager', 'b1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000004', 'Full-time',
     'e1000001-0000-4000-8000-000000000009', 'Active', 'Permanent', '2016-05-01', NULL, NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000011', 'ZEL-0095', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Efua', 'Boateng', '1995-04-09', 'Female', 'Ghanaian', 'GHA-100000011', 'efua.boateng@zeloshr.demo', '+233201000011', 'Takoradi', 'GA-011', 'Active',
     'Operations Coordinator', 'b1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000003', 'Contractor',
     'e1000001-0000-4000-8000-000000000010', 'Active', 'Fixed-term', '2024-01-01', '2025-12-31', NOW(), NOW()),
    ('e1000001-0000-4000-8000-000000000012', 'ZEL-0077', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
     'Kojo', 'Annan', '1993-10-25', 'Male', 'Ghanaian', 'GHA-100000012', 'kojo.annan@zeloshr.demo', '+233201000012', 'Kumasi', 'GA-012', 'Active',
     'Finance Analyst', 'b1000001-0000-4000-8000-000000000008', 'a1000001-0000-4000-8000-000000000002', 'Full-time',
     'e1000001-0000-4000-8000-000000000009', 'Probation', 'Permanent', '2024-11-01', '2025-05-01', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000001' WHERE id = 'b1000001-0000-4000-8000-000000000005';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000004' WHERE id = 'b1000001-0000-4000-8000-000000000002';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000005' WHERE id = 'b1000001-0000-4000-8000-000000000003';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000006' WHERE id = 'b1000001-0000-4000-8000-000000000001';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000008' WHERE id = 'b1000001-0000-4000-8000-000000000005';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000003' WHERE id = 'b1000001-0000-4000-8000-000000000007';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000008' WHERE id = 'b1000001-0000-4000-8000-000000000008';
UPDATE zeloshr.zhr_departments SET head_of_department_id = 'e1000001-0000-4000-8000-000000000007' WHERE id = 'b1000001-0000-4000-8000-000000000009';

INSERT INTO zeloshr.zhr_audit_logs (
    id, tenant_id, org_id, occurred_at, action_title, action_description,
    employee_id, employee_display_code, employee_full_name, actor_id, actor_full_name,
    category, severity, is_flagged, is_sensitive_read, created_at
)
VALUES
    ('c1000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-14 09:41:22+00',
     'Employee record created', 'New record created. Onboarding invite sent automatically.',
     'e1000001-0000-4000-8000-000000000001', 'EMP-00142', 'Kwaku Asante', 'actor-hr-1', 'Belinda Osei',
     'Lifecycle', 'Low', FALSE, FALSE, '2025-03-14 09:41:22+00'),
    ('c1000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-14 10:05:11+00',
     'Personal information updated', 'Phone number and residential address changed.',
     'e1000001-0000-4000-8000-000000000002', 'EMP-00089', 'Kwame Asare', 'actor-hr-1', 'Belinda Osei',
     'Field change', 'Medium', FALSE, FALSE, '2025-03-14 10:05:11+00'),
    ('c1000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-13 16:22:00+00',
     'SSNIT number revealed', 'Payroll officer viewed full SSNIT for compliance check.',
     'e1000001-0000-4000-8000-000000000004', 'EMP-00015', 'Kofi Mensah', 'actor-pay-1', 'Ama Payroll',
     'System', 'High', TRUE, TRUE, '2025-03-13 16:22:00+00'),
    ('c1000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-13 14:00:00+00',
     'Leave request approved', 'Annual leave approved for 5 working days.',
     'e1000001-0000-4000-8000-000000000005', 'EMP-00033', 'Abena Owusu', 'actor-mgr-1', 'Kwame Boateng',
     'Approval', 'Low', FALSE, FALSE, '2025-03-13 14:00:00+00'),
    ('c1000001-0000-4000-8000-000000000005', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-12 11:30:00+00',
     'Employment status changed', 'Status changed from Active to Terminated.',
     'e1000001-0000-4000-8000-000000000003', 'EMP-00072', 'Yaw Appiah', 'actor-hr-2', 'Fiifi Admin',
     'Lifecycle', 'High', TRUE, FALSE, '2025-03-12 11:30:00+00'),
    ('c1000001-0000-4000-8000-000000000006', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-12 09:15:00+00',
     'Document uploaded', 'Contract PDF uploaded under Contract category.',
     'e1000001-0000-4000-8000-000000000011', 'EMP-00095', 'Efua Boateng', 'actor-hr-1', 'Belinda Osei',
     'System', 'Low', FALSE, FALSE, '2025-03-12 09:15:00+00'),
    ('c1000001-0000-4000-8000-000000000007', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-11 17:45:00+00',
     'Compensation updated', 'Gross salary revised after annual review.',
     'e1000001-0000-4000-8000-000000000001', 'EMP-00142', 'Ama Asante', 'actor-hr-2', 'Fiifi Admin',
     'Field change', 'Medium', FALSE, FALSE, '2025-03-11 17:45:00+00'),
    ('c1000001-0000-4000-8000-000000000008', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-11 08:00:00+00',
     'Probation review scheduled', 'Probation end date within 30 days.',
     'e1000001-0000-4000-8000-000000000012', 'EMP-00077', 'Kojo Annan', 'actor-sys', 'System',
     'Lifecycle', 'Medium', FALSE, FALSE, '2025-03-11 08:00:00+00'),
    ('c1000001-0000-4000-8000-000000000009', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-10 15:20:00+00',
     'Bank details updated', 'Employee self-service update to mobile money.',
     'e1000001-0000-4000-8000-000000000002', 'EMP-00089', 'Kwame Asare', 'actor-emp-2', 'Kwame Asare',
     'Field change', 'Low', FALSE, FALSE, '2025-03-10 15:20:00+00'),
    ('c1000001-0000-4000-8000-000000000010', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-10 12:00:00+00',
     'Unauthorized access attempt', 'Employee role attempted to view another profile.',
     'e1000001-0000-4000-8000-000000000008', 'EMP-00028', 'Kwesi Owusu', 'actor-emp-8', 'Kwesi Owusu',
     'System', 'High', TRUE, FALSE, '2025-03-10 12:00:00+00'),
    ('c1000001-0000-4000-8000-000000000011', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-09 10:10:00+00',
     'Department reassigned', 'Moved from Marketing to Product.',
     'e1000001-0000-4000-8000-000000000001', 'EMP-00142', 'Ama Asante', 'actor-hr-1', 'Belinda Osei',
     'Field change', 'Medium', FALSE, FALSE, '2025-03-09 10:10:00+00'),
    ('c1000001-0000-4000-8000-000000000012', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', '2025-03-08 09:00:00+00',
     'Reporting line updated', 'Manager changed to Kwame Boateng.',
     'e1000001-0000-4000-8000-000000000004', 'EMP-00015', 'Kofi Mensah', 'actor-hr-1', 'Belinda Osei',
     'Field change', 'Low', FALSE, FALSE, '2025-03-08 09:00:00+00')
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_lifecycle_events (
    id, tenant_id, org_id, employee_id, employee_full_name, event_type,
    department_name, branch_name, due_date, status, urgency, created_at, updated_at
)
VALUES
    ('d1000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000005',
     'Abena Mensah', 'Probation review', 'Design', 'Accra HQ', '2025-03-08', 'Pending', 'Overdue', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000002',
     'Kweku Ansah', 'Contract expiry', 'Engineering', 'Accra HQ', '2025-04-01', 'Awaiting Manager', 'Critical', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000011',
     'Efua Boateng', 'Resignation', 'Operations', 'Takoradi', '2025-03-20', 'In progress', 'Due soon', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000007',
     'Ama Darko', 'Contract expiry', 'Human Resources', 'Kumasi', '2025-03-15', 'Pending', 'Upcoming', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000005', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000012',
     'Kojo Annan', 'Confirm probation', 'Finance', 'Kumasi', '2025-03-25', 'Pending', 'Due soon', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000006', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000003',
     'Yaw Appiah', 'Termination', 'Marketing', 'Accra HQ', '2025-03-10', 'In progress', 'Overdue', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000007', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001',
     'Ama Asante', 'Extend probation', 'Product', 'Accra HQ', '2025-04-05', 'Awaiting Manager', 'Upcoming', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000008', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000004',
     'Kofi Mensah', 'Rehire check', 'Engineering', 'Accra HQ', '2025-03-18', 'Pending', 'Critical', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000009', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000010',
     'Kwame Boateng', 'Contract expiry', 'Engineering', 'Tema', '2025-04-10', 'Pending', 'Upcoming', NOW(), NOW()),
    ('d1000001-0000-4000-8000-000000000010', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000008',
     'Kwesi Owusu', 'Probation review', 'Product', 'Accra HQ', '2025-03-12', 'In progress', 'Overdue', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Attendance (today + recent)
INSERT INTO zeloshr.zhr_attendance_records (
    id, tenant_id, org_id, employee_id, employee_full_name, employee_code,
    department_name, branch_name, attendance_date, clock_in, clock_out, status, hours_worked, created_at
)
VALUES
    ('f1000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'ZEL-0042', 'Product', 'Accra HQ', CURRENT_DATE, '08:02', '17:15', 'Present', 8.5, NOW()),
    ('f1000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000004', 'Kofi Mensah', 'ZEL-0015', 'Frontend Engineering', 'Accra HQ', CURRENT_DATE, '08:45', '17:30', 'Late', 8.0, NOW()),
    ('f1000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000002', 'Kwame Asare', 'ZEL-0089', 'Data & Insights', 'Accra HQ', CURRENT_DATE, NULL, NULL, 'Absent', 0, NOW()),
    ('f1000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000005', 'Abena Owusu', 'ZEL-0033', 'Marketing', 'Kumasi', CURRENT_DATE, NULL, NULL, 'On Leave', 0, NOW()),
    ('f1000001-0000-4000-8000-000000000005', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000010', 'Kwame Boateng', 'ZEL-0010', 'Engineering', 'Tema', CURRENT_DATE, '07:55', '16:00', 'Present', 8.0, NOW()),
    ('f1000001-0000-4000-8000-000000000006', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000012', 'Kojo Annan', 'ZEL-0077', 'Finance', 'Kumasi', CURRENT_DATE - 1, '08:10', '17:00', 'Present', 8.0, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_leave_requests (
    id, tenant_id, org_id, employee_id, employee_full_name, leave_type,
    start_date, end_date, days_requested, status, approver_name, submitted_at
)
VALUES
    ('f2000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000005', 'Abena Owusu', 'Annual Leave', CURRENT_DATE, CURRENT_DATE + 4, 5, 'Approved', 'Kwame Boateng', NOW()),
    ('f2000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'Annual Leave', CURRENT_DATE + 7, CURRENT_DATE + 9, 3, 'Pending', NULL, NOW()),
    ('f2000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000004', 'Kofi Mensah', 'Sick Leave', CURRENT_DATE - 2, CURRENT_DATE - 1, 2, 'Approved', 'Kwame Boateng', NOW()),
    ('f2000001-0000-4000-8000-000000000004', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000011', 'Efua Boateng', 'Compassionate', CURRENT_DATE + 14, CURRENT_DATE + 16, 3, 'Pending', NULL, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_leave_balances (
    id, tenant_id, org_id, employee_id, employee_full_name, leave_type, entitled_days, used_days, remaining_days
)
VALUES
    ('f2100001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'Annual Leave', 21, 5, 16),
    ('f2100001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000004', 'Kofi Mensah', 'Annual Leave', 21, 8, 13)
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_job_postings (
    id, tenant_id, org_id, title, department_name, branch_name, employment_type, status, applicants_count, posted_at, closing_date
)
VALUES
    ('f3000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Senior Software Engineer', 'Engineering', 'Accra HQ', 'Full-time', 'Open', 24, CURRENT_DATE - 14, CURRENT_DATE + 30),
    ('f3000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Product Designer', 'Product Design', 'Accra HQ', 'Full-time', 'Open', 18, CURRENT_DATE - 7, CURRENT_DATE + 21),
    ('f3000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Finance Analyst', 'Finance', 'Kumasi', 'Full-time', 'Closed', 42, CURRENT_DATE - 45, CURRENT_DATE - 5)
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_onboarding_tasks (
    id, tenant_id, org_id, employee_id, employee_full_name, task_name, category, due_date, status, assigned_to
)
VALUES
    ('f4000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000012', 'Kojo Annan', 'Complete IT setup', 'IT', CURRENT_DATE + 2, 'Pending', 'IT Support'),
    ('f4000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000012', 'Kojo Annan', 'Sign employment contract', 'HR', CURRENT_DATE, 'In progress', 'Belinda Osei'),
    ('f4000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000012', 'Kojo Annan', 'Policy induction session', 'Training', CURRENT_DATE + 5, 'Pending', 'Serwa Acheampong')
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_performance_reviews (
    id, tenant_id, org_id, employee_id, employee_full_name, review_period, reviewer_name, overall_rating, status, due_date
)
VALUES
    ('f5000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'H1 2025', 'Kwame Boateng', NULL, 'In progress', CURRENT_DATE + 14),
    ('f5000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000004', 'Kofi Mensah', 'H1 2025', 'Ama Asante', 'Exceeds Expectations', 'Completed', CURRENT_DATE - 7),
    ('f5000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000010', 'Kwame Boateng', 'H1 2025', 'Esi Quainoo', NULL, 'Pending', CURRENT_DATE + 21)
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_disciplinary_cases (
    id, tenant_id, org_id, employee_id, employee_full_name, case_type, severity, status, opened_at, description
)
VALUES
    ('f6000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000002', 'Kwame Asare', 'Attendance violation', 'Medium', 'Open', CURRENT_DATE - 10, 'Repeated late arrivals in March.'),
    ('f6000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000003', 'Yaw Appiah', 'Misconduct', 'High', 'Closed', CURRENT_DATE - 60, 'Resolved prior to termination.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO zeloshr.zhr_employee_documents (
    id, tenant_id, org_id, employee_id, employee_full_name, document_name, category, file_size_kb, uploaded_by, uploaded_at, status
)
VALUES
    ('f7000001-0000-4000-8000-000000000001', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'Employment Contract 2024.pdf', 'Contract', 840, 'Belinda Osei', NOW() - INTERVAL '30 days', 'Active'),
    ('f7000001-0000-4000-8000-000000000002', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000001', 'Ama Asante', 'Ghana Card Scan.jpg', 'National ID', 420, 'Belinda Osei', NOW() - INTERVAL '60 days', 'Active'),
    ('f7000001-0000-4000-8000-000000000003', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'e1000001-0000-4000-8000-000000000011', 'Efua Boateng', 'Fixed Term Contract.pdf', 'Contract', 1024, 'Fiifi Admin', NOW() - INTERVAL '14 days', 'Active')
ON CONFLICT (id) DO NOTHING;

-- Trove platform context for local Swagger/curl (headers: org-id, bus-id, loc-id, app-id)
INSERT INTO core_platform.cp_tenants (id, delete_status, is_active, description, is_verified, is_system)
VALUES ('demo-tenant', 'NOT_DELETED', true, 'ZelosHR demo tenant', true, false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO core_platform.cp_organizations (id, tenant_id, org_name, delete_status, is_active)
VALUES ('org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'demo-tenant', 'ZelosHR Demo Organisation', 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_businesses (id, tenant_id, org_id, bus_name, delete_status, is_active)
VALUES ('bus_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'Demo Business Unit', 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_locations (id, tenant_id, loc_name, delete_status, is_active)
VALUES ('loc_c79fd9a5c53a8eaa82805e63a84da112387743c5dcdff7f7b254c02302c', 'demo-tenant', 'Accra HQ', 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_business_apps (id, tenant_id, bus_id, app_id, delete_status, is_active)
VALUES ('ba_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d', 'demo-tenant', 'bus_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d', 'app-hr', 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_business_app_locations (id, tenant_id, org_id, bus_id, app_id, loc_id, business_app_id, delete_status, is_active)
VALUES ('bal_c79fd9a5c53a8eaa82805e63a84da112387743c5dcdff7f7b254c02302c', 'demo-tenant', 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a', 'bus_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d', 'app-hr', 'loc_c79fd9a5c53a8eaa82805e63a84da112387743c5dcdff7f7b254c02302c', 'ba_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d', 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

-- Platform users for registration wizard demos (read-only in ZelosHR; owned by core_platform)
INSERT INTO core_platform.cp_users (id, tenant_id, fullname, email, contact, is_owner, can_login, delete_status, is_active)
VALUES
    ('u1000001-0000-4000-8000-000000000001', 'demo-tenant', 'Demo HR Admin', 'demo.admin@zeloshr.local', '+233200000001', true, true, 'NOT_DELETED', true),
    ('u-demo-ama-asante', 'demo-tenant', 'Ama Asante', 'ama.asante@zeloshr.demo', '+233201000001', false, true, 'NOT_DELETED', true),
    ('u-demo-kwame-asare', 'demo-tenant', 'Kwame Asare', 'kwame.asare@zeloshr.demo', '+233201000002', false, true, 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_login_settings (id, tenant_id, user_id, can_always_login, delete_status, is_active)
VALUES ('ls-demo-admin', 'demo-tenant', 'u1000001-0000-4000-8000-000000000001', true, 'NOT_DELETED', true)
ON CONFLICT (id, tenant_id) DO NOTHING;

INSERT INTO core_platform.cp_user_locations (id, tenant_id, user_id, org_id, bus_id, app_id, bus_app_loc_id, delete_status, is_active)
VALUES (
    'ul-demo-admin-hr',
    'demo-tenant',
    'u1000001-0000-4000-8000-000000000001',
    'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a',
    'bus_5d929457b0ea7e6d55c5da25c8cfb38aeef0573658121bf5399f6f1e64d',
    'app-hr',
    'bal_c79fd9a5c53a8eaa82805e63a84da112387743c5dcdff7f7b254c02302c',
    'NOT_DELETED',
    true
)
ON CONFLICT (id, tenant_id) DO NOTHING;

-- Link demo employees to platform users only (identity stays on cp_users).
UPDATE zeloshr.zhr_employees e
SET user_id = u.id
FROM core_platform.cp_users u
WHERE e.tenant_id = 'demo-tenant'
  AND e.org_id = 'org_bcf5a0951f5ed22448dc5262e641e428caa3638d38b94cfa3b79c13d38a'
  AND u.tenant_id = e.tenant_id
  AND lower(u.email) = lower(e.personal_email)
  AND e.user_id IS NULL;
