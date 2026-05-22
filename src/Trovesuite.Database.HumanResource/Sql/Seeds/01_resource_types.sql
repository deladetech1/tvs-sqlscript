-- =====================================================
-- Human Resources Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS human_resource;

-- Set the search path to human_resource schema for this session
SET search_path TO human_resource;

-- =====================================================
-- Resource types (one per HR sub-domain)
-- =====================================================

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-hr',  'HR APP',            'HR Subscribed APP',                       null),
('rt-hr-employees',       'HR Employees',      'Employees, including identity + employment fields', 'rt-subscribed-app-hr'),
('rt-hr-departments',     'HR Departments',    'Department lookup',                       'rt-subscribed-app-hr'),
('rt-hr-banks',           'HR Banks',          'Bank + bank branch lookup',               'rt-subscribed-app-hr'),
('rt-hr-pension',         'HR Pension',        'Pension providers (Tier 2 / Tier 3)',     'rt-subscribed-app-hr'),
('rt-hr-files',           'HR Files',          'Documents uploaded against employees',    'rt-subscribed-app-hr')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;
