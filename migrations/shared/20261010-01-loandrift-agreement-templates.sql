-- LoanDrift agreement templates.
--
-- Every business generates agreements on the LoanDrift Standard wording. Choosing
-- one of the other ready-made templates, or writing and editing its own, is a
-- Premium feature (loandrift.agreement-templates). The ready-made templates live
-- in the API (agr_templates.py); a business's own templates live here.
--
-- Idempotent; safe to re-run on every deploy.

INSERT INTO core_platform.cp_app_feature_catalog (feature_key, app_id, title, min_tier_rank, description) VALUES
('loandrift.agreement-templates', 'app-loandrift', 'Agreement Templates', 3,
 'Choose a ready-made loan agreement template, or write and edit your own with merge fields')
ON CONFLICT (feature_key) DO UPDATE SET
    app_id = EXCLUDED.app_id, title = EXCLUDED.title,
    min_tier_rank = EXCLUDED.min_tier_rank, description = EXCLUDED.description, is_active = true;

-- A business's own templates: the loan agreement terms and, optionally, its own
-- guarantor and collateral wording (empty means the standard wording).
CREATE TABLE IF NOT EXISTS loandrift.ld_agreement_templates (
    tenant_id        text NOT NULL,
    id               text NOT NULL,
    org_id           text NOT NULL,
    bus_id           text NOT NULL,
    name             text NOT NULL,
    description      text,
    terms            text NOT NULL,
    guarantor_terms  text,
    collateral_terms text,
    -- The ready-made template it was started from, if any.
    based_on         text,
    is_deleted       boolean NOT NULL DEFAULT false,
    created_by       text,
    updated_by       text,
    cdatetime        timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ld_agreement_templates PRIMARY KEY (id, tenant_id)
);
CREATE INDEX IF NOT EXISTS ix_ld_agreement_templates_business
    ON loandrift.ld_agreement_templates (tenant_id, org_id, bus_id) WHERE NOT is_deleted;

-- Which template the business uses: a ready-made key (e.g. 'standard', 'sme') or
-- the id of one of its own. NULL means LoanDrift Standard.
ALTER TABLE loandrift.ld_agreement_settings ADD COLUMN IF NOT EXISTS template_key text;

-- Wording a business already wrote under Settings > Loan Agreement becomes its
-- own template, chosen, so nothing it signs changes when templates arrive.
INSERT INTO loandrift.ld_agreement_templates (tenant_id, id, org_id, bus_id, name, description, terms, based_on, updated_by)
SELECT s.tenant_id, 'agt-legacy-' || md5(s.tenant_id || '|' || s.org_id || '|' || s.bus_id), s.org_id, s.bus_id,
       'Our terms', 'The wording saved under Settings > Loan Agreement before templates.',
       s.terms_and_conditions, 'standard', s.updated_by
FROM loandrift.ld_agreement_settings s
WHERE s.terms_and_conditions IS NOT NULL AND btrim(s.terms_and_conditions) <> '' AND s.template_key IS NULL
ON CONFLICT (id, tenant_id) DO NOTHING;

UPDATE loandrift.ld_agreement_settings s
SET template_key = 'agt-legacy-' || md5(s.tenant_id || '|' || s.org_id || '|' || s.bus_id)
WHERE s.terms_and_conditions IS NOT NULL AND btrim(s.terms_and_conditions) <> '' AND s.template_key IS NULL;
