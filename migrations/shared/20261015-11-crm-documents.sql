-- CRM: Documents. Files of any kind (documents, pictures, video, music) in folders that nest,
-- starred per person, with a recycle bin, and linkable to a contact, account, deal or ticket.
--
-- The bytes live in the shared apps' private blob container; a row here names the blob.
-- Trash is a timestamp, not a move: deleted_at set means "in the recycle bin", and the bin
-- is emptied by the app after 30 days. Trashing a folder trashes what is under it, each item
-- remembering which folder took it (trashed_with) so restoring the folder brings back exactly
-- that, and not what had been binned on its own before.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

CREATE TABLE IF NOT EXISTS crm.crm_doc_folders (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,
    parent_id     text        REFERENCES crm.crm_doc_folders(id) ON DELETE CASCADE,
    name          text        NOT NULL,
    color         text,
    created_by    text,
    updated_by    text,
    deleted_at    timestamptz,
    deleted_by    text,
    trashed_with  text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_doc_folders_name CHECK (length(btrim(name)) BETWEEN 1 AND 120),
    CONSTRAINT ck_crm_doc_folders_not_own_parent CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX IF NOT EXISTS ix_crm_doc_folders_scope ON crm.crm_doc_folders (tenant_id, bus_id, parent_id) WHERE deleted_at IS NULL;
-- One name per place: two "Invoices" side by side is always a mistake.
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_doc_folders_name ON crm.crm_doc_folders (tenant_id, bus_id, coalesce(parent_id, ''), lower(name))
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS crm.crm_documents (
    id            text        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id     text        NOT NULL,
    org_id        text        NOT NULL,
    bus_id        text        NOT NULL,
    folder_id     text        REFERENCES crm.crm_doc_folders(id) ON DELETE CASCADE,
    name          text        NOT NULL,
    extension     text,
    content_type  text        NOT NULL DEFAULT 'application/octet-stream',
    -- image | video | audio | pdf | document | spreadsheet | presentation | archive | other
    kind          text        NOT NULL DEFAULT 'other',
    size_bytes    bigint      NOT NULL DEFAULT 0,
    -- Where the bytes are, inside the container: <tenant>/<business>/<id>.
    blob_path     text        NOT NULL,
    description   text,
    contact_id    text,
    company_id    text,
    deal_id       text,
    ticket_id     text,
    uploaded_by   text,
    updated_by    text,
    deleted_at    timestamptz,
    deleted_by    text,
    trashed_with  text,
    cdatetime     timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_crm_documents_name CHECK (length(btrim(name)) BETWEEN 1 AND 255),
    CONSTRAINT ck_crm_documents_kind CHECK (kind IN ('image', 'video', 'audio', 'pdf', 'document', 'spreadsheet', 'presentation', 'archive', 'other')),
    CONSTRAINT ck_crm_documents_size CHECK (size_bytes >= 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_crm_documents_blob ON crm.crm_documents (blob_path);
CREATE INDEX IF NOT EXISTS ix_crm_documents_folder ON crm.crm_documents (tenant_id, bus_id, folder_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_trash ON crm.crm_documents (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_contact ON crm.crm_documents (contact_id) WHERE contact_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_company ON crm.crm_documents (company_id) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_deal ON crm.crm_documents (deal_id) WHERE deal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_ticket ON crm.crm_documents (ticket_id) WHERE ticket_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_crm_documents_name ON crm.crm_documents (tenant_id, bus_id, lower(name));

-- Starred, per person: what one person keeps at hand is not everybody's.
CREATE TABLE IF NOT EXISTS crm.crm_doc_favourites (
    tenant_id    text        NOT NULL,
    user_id      text        NOT NULL,
    entity_type  text        NOT NULL,
    entity_id    text        NOT NULL,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, entity_type, entity_id),
    CONSTRAINT ck_crm_doc_favourites_type CHECK (entity_type IN ('file', 'folder'))
);
CREATE INDEX IF NOT EXISTS ix_crm_doc_favourites_entity ON crm.crm_doc_favourites (entity_type, entity_id);

-- ===================================================================== permissions
INSERT INTO core_platform.cp_resource_types (id, resource_type_name, description, parent_resource_id) VALUES
('rt-crm-documents', 'CRM Documents', 'Files and folders kept in the CRM', 'rt-subscribed-app-crm')
ON CONFLICT (id) DO UPDATE SET resource_type_name = EXCLUDED.resource_type_name,
                               description        = EXCLUDED.description,
                               parent_resource_id = EXCLUDED.parent_resource_id;

WITH spec(resource_key, resource_type_id, action, label) AS (VALUES
    ('documents', 'rt-crm-documents', 'get',    'View and download documents'),
    ('documents', 'rt-crm-documents', 'create', 'Upload documents and make folders'),
    ('documents', 'rt-crm-documents', 'update', 'Rename and move documents and folders'),
    ('documents', 'rt-crm-documents', 'delete', 'Put documents in the recycle bin, restore them, and empty it')
)
INSERT INTO core_platform.cp_permissions (id, permission_name, resource_type_id, description, cdate, ctime, cdatetime)
SELECT 'permission-crm-' || spec.resource_key || '-' || spec.action,
       'CRM ' || initcap(replace(spec.resource_key, '-', ' ')) || ' ' || initcap(spec.action),
       spec.resource_type_id, spec.label, CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM spec
ON CONFLICT (id) DO UPDATE SET permission_name  = EXCLUDED.permission_name,
                               resource_type_id = EXCLUDED.resource_type_id,
                               description      = EXCLUDED.description;

UPDATE core_platform.cp_permissions p
   SET app_prefix = 'crm',
       resource_key = substring(p.id FROM '^permission-crm-(.+)-[a-z]+$'),
       action = substring(p.id FROM '-([a-z]+)$'),
       target = '',
       scope = 'any'
 WHERE p.id LIKE 'permission-crm-documents-%'
   AND (p.app_prefix IS DISTINCT FROM 'crm' OR p.action IS NULL);

-- A CRM user keeps files; a viewer reads them; the sales manager also clears the bin.
INSERT INTO core_platform.cp_role_permissions (tenant_id, role_id, permission_id, description, cdate, ctime, cdatetime)
SELECT 'system-tenant-id', spec.role_id, p.id, r.role_name || ' can ' || lower(p.description),
       CURRENT_DATE::text, CURRENT_TIME::text, CURRENT_TIMESTAMP
  FROM (VALUES
        ('role-crm-user', 'get'), ('role-crm-user', 'create'), ('role-crm-user', 'update'),
        ('role-crm-viewer', 'get'),
        ('role-crm-sales-manager', 'get'), ('role-crm-sales-manager', 'create'), ('role-crm-sales-manager', 'update'),
        ('role-crm-sales-manager', 'delete')
       ) AS spec(role_id, action)
  JOIN core_platform.cp_roles r ON r.id = spec.role_id
  JOIN core_platform.cp_permissions p
    ON p.app_prefix = 'crm' AND p.resource_key = 'documents' AND p.action = spec.action
   AND coalesce(p.target, '') = '' AND p.delete_status = 'NOT_DELETED'
ON CONFLICT (tenant_id, role_id, permission_id) DO NOTHING;

DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM core_platform.cp_permissions
     WHERE id LIKE 'permission-crm-documents-%' AND (app_prefix <> 'crm' OR resource_key IS NULL OR action IS NULL);
    IF n > 0 THEN
        RAISE EXCEPTION '% document permission(s) have no pair', n;
    END IF;
    SELECT count(*) INTO n FROM core_platform.cp_role_permissions rp
      JOIN core_platform.cp_permissions p ON p.id = rp.permission_id
      JOIN core_platform.cp_actions a ON a.action = p.action
     WHERE rp.role_id = 'role-crm-viewer' AND p.app_prefix = 'crm' AND NOT a.is_read_only;
    IF n > 0 THEN
        RAISE EXCEPTION 'role-crm-viewer holds % CRM permission(s) that change data', n;
    END IF;
END $$;

COMMIT;
