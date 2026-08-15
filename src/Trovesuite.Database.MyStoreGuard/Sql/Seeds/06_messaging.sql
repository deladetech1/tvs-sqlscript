-- =====================================================
-- Messaging & Meetings (Supplier & Customer Communication)
-- =====================================================

CREATE SCHEMA IF NOT EXISTS mystoreguard;

SET search_path TO mystoreguard;


-- =====================================================
-- 1. TABLES
-- =====================================================

-- Messages Table
CREATE TABLE IF NOT EXISTS msg_messages
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,

    -- Message details
    subject VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,

    -- Delivery channel
    channel TEXT NOT NULL DEFAULT 'SMS' CHECK(channel IN ('SMS', 'EMAIL')),

    -- Recipient targeting
    recipient_type TEXT NOT NULL CHECK(recipient_type IN ('SUPPLIER', 'CUSTOMER')),

    -- Scheduling (NULL = send immediately)
    scheduled_at TIMESTAMPTZ,

    -- Status
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN
        ('DRAFT', 'SCHEDULED', 'QUEUED', 'SENDING', 'SENT', 'FAILED', 'CANCELLED')
    ),

    sent_at TIMESTAMPTZ,

    -- Processing lock (used by Azure Function to prevent double-processing)
    picked_up_at TIMESTAMPTZ,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,
    updated_by TEXT,
    deleted_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, id),

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, updated_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, deleted_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- Message Recipients Table
CREATE TABLE IF NOT EXISTS msg_message_recipients
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,

    message_id TEXT NOT NULL,

    -- Recipient reference
    recipient_type TEXT NOT NULL CHECK(recipient_type IN ('SUPPLIER', 'CUSTOMER')),
    recipient_id TEXT NOT NULL,

    -- Denormalized contact info (snapshot at send time)
    recipient_name TEXT,
    recipient_email TEXT,
    recipient_contact TEXT,

    -- Delivery status per recipient
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED')),
    failure_reason TEXT,
    delivered_at TIMESTAMPTZ,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, id),

    FOREIGN KEY (tenant_id, org_id, bus_id, message_id)
        REFERENCES msg_messages(tenant_id, org_id, bus_id, id)
        ON DELETE CASCADE,

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- Meetings Table
CREATE TABLE IF NOT EXISTS msg_meetings
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,

    -- Meeting details
    title VARCHAR(255) NOT NULL,
    description TEXT,
    location TEXT,

    -- Scheduling
    meeting_date TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ,

    -- Participant targeting
    participant_type TEXT NOT NULL CHECK(participant_type IN ('SUPPLIER', 'CUSTOMER')),

    -- Reminder notification (how many minutes before to send reminder)
    reminder_minutes INT DEFAULT 30,
    reminder_channel TEXT DEFAULT 'SMS' CHECK(reminder_channel IN ('SMS', 'EMAIL')),

    -- Status
    status TEXT NOT NULL DEFAULT 'SCHEDULED' CHECK(status IN
        ('SCHEDULED', 'REMINDER_SENT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')
    ),

    -- Processing lock (used by Azure Function for reminders)
    reminder_picked_up_at TIMESTAMPTZ,
    reminder_sent_at TIMESTAMPTZ,

    notes TEXT,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,
    updated_by TEXT,
    deleted_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, id),

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, updated_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, deleted_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- Meeting Participants Table
CREATE TABLE IF NOT EXISTS msg_meeting_participants
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,

    meeting_id TEXT NOT NULL,

    -- Participant reference
    participant_type TEXT NOT NULL CHECK(participant_type IN ('SUPPLIER', 'CUSTOMER')),
    participant_id TEXT NOT NULL,

    -- Denormalized contact info (snapshot at creation time)
    participant_name TEXT,
    participant_email TEXT,
    participant_contact TEXT,

    -- RSVP
    rsvp_status TEXT NOT NULL DEFAULT 'PENDING' CHECK(rsvp_status IN ('PENDING', 'ACCEPTED', 'DECLINED')),

    -- Reminder delivery status
    reminder_status TEXT NOT NULL DEFAULT 'PENDING' CHECK(reminder_status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED')),
    reminder_failure_reason TEXT,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, id),

    FOREIGN KEY (tenant_id, org_id, bus_id, meeting_id)
        REFERENCES msg_meetings(tenant_id, org_id, bus_id, id)
        ON DELETE CASCADE,

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- =====================================================
-- 2. RESOURCE TYPES
-- =====================================================

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-messaging', 'Messaging', 'Messaging management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-meetings', 'Meetings', 'Meetings management for Mystoreguard', 'rt-subscribed-app-msg')
ON CONFLICT (id) DO UPDATE SET
    resource_type_name = EXCLUDED.resource_type_name,
    description        = EXCLUDED.description,
    parent_resource_id = EXCLUDED.parent_resource_id;


-- =====================================================
-- 3. PERMISSIONS
-- =====================================================

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Messaging permissions
('permission-msg-messaging-create', 'Mystoreguard Messaging Create', 'rt-messaging', 'Can compose and send messages to suppliers and customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-messaging-get', 'Mystoreguard Messaging Get', 'rt-messaging', 'Can view, list, read messages, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-messaging-update', 'Mystoreguard Messaging Update', 'rt-messaging', 'Can update draft messages and resend failed messages', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-messaging-delete', 'Mystoreguard Messaging Delete', 'rt-messaging', 'Can delete messages', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Meeting permissions
('permission-msg-meetings-create', 'Mystoreguard Meetings Create', 'rt-meetings', 'Can schedule meetings with suppliers and customers', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-meetings-get', 'Mystoreguard Meetings Get', 'rt-meetings', 'Can view, list, read meetings, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-meetings-update', 'Mystoreguard Meetings Update', 'rt-meetings', 'Can reschedule and update meetings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-meetings-delete', 'Mystoreguard Meetings Delete', 'rt-meetings', 'Can cancel and delete meetings', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO UPDATE SET
    permission_name  = EXCLUDED.permission_name,
    resource_type_id = EXCLUDED.resource_type_id,
    description      = EXCLUDED.description;


-- =====================================================
-- 4. ROLES
-- =====================================================

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-msg-messaging-admin', 'system-tenant-id', 'Mystoreguard Messaging Admin', 'Administrator for messaging management with full access to compose, send, and manage messages', 'rt-messaging', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-meetings-admin', 'system-tenant-id', 'Mystoreguard Meetings Admin', 'Administrator for meetings management with full access to schedule and manage meetings', 'rt-meetings', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, role_name) DO UPDATE SET
    description      = EXCLUDED.description,
    resource_type_id = EXCLUDED.resource_type_id,
    is_system        = EXCLUDED.is_system,
    is_active        = EXCLUDED.is_active;


-- =====================================================
-- 5. ROLE-PERMISSION MAPPINGS
-- =====================================================

INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id) VALUES
('system-tenant-id', 'role-msg-messaging-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-messaging-admin', 'permission-user-get-locations'),

('system-tenant-id', 'role-msg-meetings-admin', 'permission-app-get'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-business-get'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-organization-get'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-business-app-get'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-business-app-subscribe'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-business-app-get-locations'),
('system-tenant-id', 'role-msg-meetings-admin', 'permission-user-get-locations')
ON CONFLICT DO NOTHING;
