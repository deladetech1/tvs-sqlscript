-- =====================================================
-- Return Policies & Store Returns
-- =====================================================

CREATE SCHEMA IF NOT EXISTS mystoreguard;

SET search_path TO mystoreguard;


-- =====================================================
-- 1. TABLES
-- =====================================================

-- Return Policies Table
CREATE TABLE IF NOT EXISTS msg_return_policies
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,

    -- Basic details
    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Target (applies to pattern - same as pricing rules)
    policy_target_type TEXT NOT NULL CHECK(policy_target_type IN
        ('PRODUCT', 'ALL_PRODUCTS', 'SKU', 'LOCATION', 'TAG', 'CATEGORY', 'BRAND', 'LABEL')
    ),
    policy_target_id TEXT,

    -- Return rules
    return_window_days INT NOT NULL DEFAULT 0,
    condition_required TEXT NOT NULL DEFAULT 'ANY' CHECK(condition_required IN
        ('ANY', 'UNOPENED', 'WITH_TAGS', 'UNDAMAGED')
    ),
    receipt_required BOOLEAN DEFAULT TRUE,
    allow_expired_returns BOOLEAN DEFAULT FALSE,

    -- Refund rules
    restocking_fee_percent DECIMAL(5,2) DEFAULT 0.00,
    refund_method TEXT NOT NULL DEFAULT 'ANY' CHECK(refund_method IN
        ('ORIGINAL_PAYMENT', 'STORE_CREDIT', 'CASH', 'ANY')
    ),

    -- Approval
    approval_required BOOLEAN DEFAULT FALSE,
    approvers JSONB,  -- List of email addresses authorized to approve returns under this policy
    approval_threshold_amount DECIMAL(10,2),

    -- Policy behavior
    stops_other_policies BOOLEAN DEFAULT FALSE,
    priority INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,

    -- Time-based activation
    start_datetime TIMESTAMP,
    end_datetime TIMESTAMP,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,
    updated_by TEXT,
    deleted_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, id),

    FOREIGN KEY (tenant_id, updated_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, deleted_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- Returns Table
CREATE TABLE IF NOT EXISTS msg_returns
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,

    sale_id TEXT NOT NULL,
    return_number TEXT NOT NULL,
    return_date TEXT,

    return_type TEXT NOT NULL DEFAULT 'REFUND' CHECK(return_type IN ('REFUND', 'EXCHANGE', 'STORE_CREDIT')),
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'APPROVED', 'REJECTED', 'COMPLETED')),
    reason TEXT NOT NULL DEFAULT 'CUSTOMER_CHANGED_MIND' CHECK(reason IN
        ('DEFECTIVE', 'WRONG_ITEM', 'CUSTOMER_CHANGED_MIND', 'EXPIRED', 'DAMAGED_IN_TRANSIT', 'OTHER')
    ),
    reason_notes TEXT,
    refund_method TEXT NOT NULL DEFAULT 'ORIGINAL_PAYMENT' CHECK(refund_method IN
        ('ORIGINAL_PAYMENT', 'STORE_CREDIT', 'CASH', 'ANY')
    ),

    -- Calculated amounts
    subtotal_refund_amount DECIMAL(10,2) DEFAULT 0,
    restocking_fee_percent DECIMAL(5,2) DEFAULT 0,
    restocking_fee_amount DECIMAL(10,2) DEFAULT 0,
    total_refund_amount DECIMAL(10,2) DEFAULT 0,

    -- Policy reference
    return_policy_id TEXT,
    approval_required BOOLEAN DEFAULT FALSE,

    -- Approval
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    rejected_by TEXT,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,

    -- Processing
    processed_by TEXT,
    processed_at TIMESTAMPTZ,
    processing_notes TEXT,

    -- Customer
    customer_id TEXT,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,
    updated_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, loc_id, id),

    FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, sale_id)
        REFERENCES msg_sales(tenant_id, org_id, bus_id, loc_id, id)
        ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, updated_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, approved_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, rejected_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, processed_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, org_id) REFERENCES core_platform.cp_organizations(tenant_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, bus_id) REFERENCES core_platform.cp_businesses(tenant_id, id) ON DELETE RESTRICT
);


-- Return Items Table
CREATE TABLE IF NOT EXISTS msg_return_items
(
    id TEXT DEFAULT gen_random_uuid()::TEXT,
    tenant_id TEXT NOT NULL,

    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,

    return_id TEXT NOT NULL,
    sale_item_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    batch_id TEXT,

    quantity_returned NUMERIC(18,2) NOT NULL CHECK (quantity_returned > 0),
    condition TEXT NOT NULL DEFAULT 'RESALABLE' CHECK(condition IN
        ('RESALABLE', 'DAMAGED', 'EXPIRED', 'OPENED', 'WRITE_OFF')
    ),
    restock BOOLEAN DEFAULT TRUE,

    unit_refund_amount NUMERIC(18,2) DEFAULT 0,
    line_refund_amount NUMERIC(18,2) DEFAULT 0,

    reason TEXT,

    cdate TEXT,
    ctime TEXT,
    cdatetime TIMESTAMPTZ,

    created_by TEXT,

    PRIMARY KEY (tenant_id, org_id, bus_id, loc_id, id),

    FOREIGN KEY (tenant_id) REFERENCES core_platform.cp_tenants(id) ON DELETE CASCADE,

    FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, return_id)
        REFERENCES msg_returns(tenant_id, org_id, bus_id, loc_id, id)
        ON DELETE CASCADE,

    FOREIGN KEY (tenant_id, org_id, bus_id, loc_id, sale_item_id)
        REFERENCES msg_sales_items(tenant_id, org_id, bus_id, loc_id, id)
        ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id, org_id, bus_id, product_id)
        REFERENCES mystoreguard.msg_products(tenant_id, org_id, bus_id, id)
        ON DELETE RESTRICT,

    FOREIGN KEY (tenant_id, created_by) REFERENCES core_platform.cp_users(tenant_id, id) ON DELETE RESTRICT
);


-- =====================================================
-- 2. RESOURCE TYPES
-- =====================================================

INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-return-policies', 'Return Policies', 'Return Policies management for Mystoreguard', 'rt-subscribed-app-msg'),
('rt-store-returns', 'Store Returns', 'Store Returns management for Mystoreguard', 'rt-subscribed-app-msg')
ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- 3. PERMISSIONS
-- =====================================================

INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime) VALUES

-- Return Policies permissions
('permission-msg-return-policy-create', 'Mystoreguard Return Policy Create', 'rt-return-policies', 'Can create new return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-get', 'Mystoreguard Return Policy Get', 'rt-return-policies', 'Can view, list, read return policies, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-update', 'Mystoreguard Return Policy Update', 'rt-return-policies', 'Can update return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-return-policy-delete', 'Mystoreguard Return Policy Delete', 'rt-return-policies', 'Can delete return policies', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),

-- Store Returns permissions
('permission-msg-store-returns-create', 'Mystoreguard Store Returns Create', 'rt-store-returns', 'Can create new return requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-get', 'Mystoreguard Store Returns Get', 'rt-store-returns', 'Can view, list, read returns, view statistics, and export data', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-update', 'Mystoreguard Store Returns Update', 'rt-store-returns', 'Can process approved returns (restock and refund)', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('permission-msg-store-returns-approve', 'Mystoreguard Store Returns Approve', 'rt-store-returns', 'Can approve or reject pending return requests', CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)

ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- 4. ROLES
-- =====================================================

INSERT INTO core_platform.cp_roles (id, tenant_id, role_name, description, resource_type_id, is_system, is_active, cdate, ctime, cdatetime) VALUES
('role-msg-return-policies-admin', 'system-tenant-id', 'Mystoreguard Return Policies Admin', 'Administrator for return policies management', 'rt-return-policies', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP),
('role-msg-store-returns-admin', 'system-tenant-id', 'Mystoreguard Store Returns Admin', 'Administrator for store returns management with full access including approve and process', 'rt-store-returns', true, true, CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (tenant_id, role_name) DO NOTHING;
