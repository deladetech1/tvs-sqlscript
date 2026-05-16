-- =====================================================
-- Human Resources Database Schema
-- =====================================================

-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS human_resource;

-- Set the search path to human_resource schema for this session
SET search_path TO human_resource;

-- =====================================================
-- Initial Data
-- =====================================================

-- Insert resource types
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-subscribed-app-hr', 'HR APP', 'HR Subscribed APP', null)
ON CONFLICT (id) DO NOTHING;