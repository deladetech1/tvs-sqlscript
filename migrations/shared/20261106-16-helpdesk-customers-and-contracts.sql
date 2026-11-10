-- Help Desk R4: customers, contacts, customer groups, contracts and entitlements.
--
--   hd_contacts                people who raise tickets without being hub users; their company is a
--                              Core customer party (core_platform.cp_parties) or an MSP client
--   hd_customer_groups         groups of customer companies, for SLA matching and reporting
--   hd_customer_group_members  which companies are in a group
--   hd_contracts               a support contract with a company or an MSP client (exactly one)
--   hd_entitlements            what a contract includes: tickets, hours or unlimited, per period
--   hd_entitlement_usage       append-only: what each ticket used of an entitlement
--   hd_tickets                 + requester_contact_id, customer_party_id, contract_id,
--                                client_account_id, channel_thread_key
--   hd_sla_policies            + match_contract_id, match_customer_group_id
--
-- The client_account_id columns get their FK in 20261106-19, which creates hd_client_accounts.
-- Party columns are registered in core_platform.cp_party_references so a party merge re-points
-- them; group membership is an extension (FK ON DELETE CASCADE), the rest count as in use.
--
-- This file is the newest that touches two lists, so it owns them:
--   * hd_number_series.kind gains 'contract' (prefix CTR);
--   * hd_tickets_requester_check: a ticket may name its requester by contact alone (a chat visitor
--     who gave no email), so requester_contact_id now counts.
-- CHECK lists of new tables are inline. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §3, §6. Idempotent; safe to re-run.

BEGIN;

-- ========================================================================== contacts
CREATE TABLE IF NOT EXISTS helpdesk.hd_contacts (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    party_id           text,
    client_account_id  text,
    name               text,
    email              text,
    phone              text,
    job_title          text,
    preferred_channel  text NOT NULL DEFAULT 'email'
                       CONSTRAINT hd_contacts_preferred_channel_check CHECK (preferred_channel IN ('email', 'sms', 'portal')),
    email_opt_out      boolean NOT NULL DEFAULT false,
    sms_opt_out        boolean NOT NULL DEFAULT false,
    locale             text,
    timezone           text,
    is_vip             boolean NOT NULL DEFAULT false,
    -- Sees every ticket of their company in the customer portal (R4.md §6 BE-2).
    is_company_admin   boolean NOT NULL DEFAULT false,
    notes              text,
    archived_at        timestamptz,
    version            int NOT NULL DEFAULT 1,
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz,
    updated_by         text
);
ALTER TABLE helpdesk.hd_contacts ADD COLUMN IF NOT EXISTS is_company_admin boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS hd_contacts_email_uq
    ON helpdesk.hd_contacts (tenant_id, bus_id, lower(email)) WHERE email IS NOT NULL AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hd_contacts_phone_idx ON helpdesk.hd_contacts (tenant_id, bus_id, phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS hd_contacts_party_idx ON helpdesk.hd_contacts (tenant_id, bus_id, party_id);
CREATE INDEX IF NOT EXISTS hd_contacts_client_idx ON helpdesk.hd_contacts (tenant_id, bus_id, client_account_id);

-- ==================================================================== customer groups
CREATE TABLE IF NOT EXISTS helpdesk.hd_customer_groups (
    id           text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id    text NOT NULL,
    bus_id       text NOT NULL,
    name         text NOT NULL,
    description  text,
    cdatetime    timestamptz NOT NULL DEFAULT now(),
    created_by   text,
    updated_at   timestamptz,
    updated_by   text
);
CREATE INDEX IF NOT EXISTS hd_customer_groups_business_idx ON helpdesk.hd_customer_groups (tenant_id, bus_id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_customer_group_members (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    group_id    text NOT NULL REFERENCES helpdesk.hd_customer_groups (id),
    party_id    text NOT NULL REFERENCES core_platform.cp_parties (id) ON DELETE CASCADE,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (group_id, party_id)
);
CREATE INDEX IF NOT EXISTS hd_customer_group_members_party_idx ON helpdesk.hd_customer_group_members (party_id);

-- ========================================================================= contracts
CREATE TABLE IF NOT EXISTS helpdesk.hd_contracts (
    id                         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id                  text NOT NULL,
    bus_id                     text NOT NULL,
    party_id                   text,
    client_account_id          text,
    number                     text NOT NULL,
    name                       text NOT NULL,
    starts_on                  date,
    ends_on                    date,
    state                      text NOT NULL DEFAULT 'draft'
                               CONSTRAINT hd_contracts_state_check CHECK (state IN ('draft', 'active', 'expired', 'terminated')),
    sla_policy_id              text REFERENCES helpdesk.hd_sla_policies (id),
    support_hours_calendar_id  text REFERENCES helpdesk.hd_calendars (id),
    value                      numeric(14,2) CONSTRAINT hd_contracts_value_check CHECK (value >= 0),
    currency                   text CONSTRAINT hd_contracts_currency_check CHECK (currency ~ '^[A-Z][A-Z][A-Z]$'),
    notes                      text,
    version                    int NOT NULL DEFAULT 1,
    cdatetime                  timestamptz NOT NULL DEFAULT now(),
    created_by                 text,
    updated_at                 timestamptz,
    updated_by                 text,
    CONSTRAINT hd_contracts_holder_check CHECK (num_nonnulls(party_id, client_account_id) = 1),
    CONSTRAINT hd_contracts_dates_check CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on),
    CONSTRAINT hd_contracts_value_currency_check CHECK (value IS NULL OR currency IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_contracts_number_uq ON helpdesk.hd_contracts (tenant_id, bus_id, number);
CREATE INDEX IF NOT EXISTS hd_contracts_party_idx ON helpdesk.hd_contracts (tenant_id, bus_id, party_id, state);
CREATE INDEX IF NOT EXISTS hd_contracts_client_idx ON helpdesk.hd_contracts (tenant_id, bus_id, client_account_id, state);

CREATE TABLE IF NOT EXISTS helpdesk.hd_entitlements (
    id               text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id        text NOT NULL,
    bus_id           text NOT NULL,
    contract_id      text NOT NULL REFERENCES helpdesk.hd_contracts (id),
    kind             text NOT NULL CONSTRAINT hd_entitlements_kind_check CHECK (kind IN ('tickets', 'hours', 'unlimited')),
    quantity         numeric(10,2) CONSTRAINT hd_entitlements_quantity_check CHECK (quantity > 0),
    period           text NOT NULL DEFAULT 'contract'
                     CONSTRAINT hd_entitlements_period_check CHECK (period IN ('contract', 'month', 'year')),
    catalog_item_id  text REFERENCES helpdesk.hd_catalog_items (id),
    department_id    text REFERENCES helpdesk.hd_departments (id),
    cdatetime        timestamptz NOT NULL DEFAULT now(),
    created_by       text,
    updated_at       timestamptz,
    updated_by       text,
    -- A counted entitlement says how much.
    CONSTRAINT hd_entitlements_counted_check CHECK (kind = 'unlimited' OR quantity IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_entitlements_contract_idx ON helpdesk.hd_entitlements (contract_id);

-- A correction is a new row with a negative quantity.
CREATE TABLE IF NOT EXISTS helpdesk.hd_entitlement_usage (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    entitlement_id  text NOT NULL REFERENCES helpdesk.hd_entitlements (id),
    ticket_id       text REFERENCES helpdesk.hd_tickets (id),
    quantity        numeric(10,2) NOT NULL CONSTRAINT hd_entitlement_usage_quantity_check CHECK (quantity <> 0),
    kind            text NOT NULL CONSTRAINT hd_entitlement_usage_kind_check CHECK (kind IN ('ticket', 'time')),
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz,
    updated_by      text
);
CREATE INDEX IF NOT EXISTS hd_entitlement_usage_entitlement_idx ON helpdesk.hd_entitlement_usage (entitlement_id, cdatetime);
CREATE INDEX IF NOT EXISTS hd_entitlement_usage_ticket_idx ON helpdesk.hd_entitlement_usage (ticket_id);
DROP TRIGGER IF EXISTS hd_entitlement_usage_append_only ON helpdesk.hd_entitlement_usage;
CREATE TRIGGER hd_entitlement_usage_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_entitlement_usage
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- =========================================================================== tickets
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS requester_contact_id text REFERENCES helpdesk.hd_contacts (id);
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS customer_party_id text;
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS contract_id text REFERENCES helpdesk.hd_contracts (id);
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS client_account_id text;
ALTER TABLE helpdesk.hd_tickets ADD COLUMN IF NOT EXISTS channel_thread_key text;
CREATE INDEX IF NOT EXISTS hd_tickets_contact_idx ON helpdesk.hd_tickets (tenant_id, bus_id, requester_contact_id);
CREATE INDEX IF NOT EXISTS hd_tickets_customer_idx ON helpdesk.hd_tickets (tenant_id, bus_id, customer_party_id);
CREATE INDEX IF NOT EXISTS hd_tickets_contract_idx ON helpdesk.hd_tickets (contract_id);
CREATE INDEX IF NOT EXISTS hd_tickets_thread_idx ON helpdesk.hd_tickets (tenant_id, bus_id, channel_thread_key) WHERE channel_thread_key IS NOT NULL;

ALTER TABLE helpdesk.hd_tickets DROP CONSTRAINT IF EXISTS hd_tickets_requester_check;
ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_requester_check
    CHECK (requester_user_id IS NOT NULL OR requester_email IS NOT NULL OR requester_contact_id IS NOT NULL);

-- ====================================================================== SLA policies
ALTER TABLE helpdesk.hd_sla_policies ADD COLUMN IF NOT EXISTS match_contract_id text REFERENCES helpdesk.hd_contracts (id);
ALTER TABLE helpdesk.hd_sla_policies ADD COLUMN IF NOT EXISTS match_customer_group_id text REFERENCES helpdesk.hd_customer_groups (id);

-- ===================================================================== number series
ALTER TABLE helpdesk.hd_number_series DROP CONSTRAINT IF EXISTS hd_number_series_kind_check;
ALTER TABLE helpdesk.hd_number_series ADD CONSTRAINT hd_number_series_kind_check
    -- 'work_order' (WO-) and 'disposal' (DSP-) since 20261110-61/-62: this file owns the list, edited in place,
    -- because a narrower list re-added here on a later deploy would fail on rows of the newer kinds.
    CHECK (kind IN ('problem', 'change', 'asset', 'contract', 'work_order', 'disposal'));

-- ==================================================================== party columns
INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('helpdesk.hd_contacts',               'party_id',          false),
    ('helpdesk.hd_contracts',              'party_id',          false),
    ('helpdesk.hd_tickets',                'customer_party_id', false),
    ('helpdesk.hd_customer_group_members', 'party_id',          true)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE missing text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_entitlement_usage'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_entitlement_usage is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO missing
      FROM information_schema.columns c
     WHERE c.table_schema = 'helpdesk' AND c.column_name LIKE '%party_id'
       AND NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references r
                        WHERE r.table_name = 'helpdesk.' || c.table_name AND r.column_name = c.column_name);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Help Desk party column(s) not in cp_party_references: %', missing;
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_contacts c JOIN core_platform.cp_parties p ON p.id = c.party_id
                WHERE p.tenant_id <> c.tenant_id OR p.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk contact belongs to a company of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_contracts c JOIN core_platform.cp_parties p ON p.id = c.party_id
                WHERE p.tenant_id <> c.tenant_id OR p.bus_id <> c.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk contract is with a company of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_customer_group_members m
                 JOIN helpdesk.hd_customer_groups g ON g.id = m.group_id
                 JOIN core_platform.cp_parties p ON p.id = m.party_id
                WHERE g.tenant_id <> m.tenant_id OR g.bus_id <> m.bus_id OR p.tenant_id <> m.tenant_id OR p.bus_id <> m.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk customer group mixes businesses';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_entitlements e JOIN helpdesk.hd_contracts c ON c.id = e.contract_id
                WHERE c.tenant_id <> e.tenant_id OR c.bus_id <> e.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk entitlement belongs to a contract of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_entitlement_usage u JOIN helpdesk.hd_entitlements e ON e.id = u.entitlement_id
                WHERE e.tenant_id <> u.tenant_id OR e.bus_id <> u.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk entitlement usage row belongs to an entitlement of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tickets t JOIN helpdesk.hd_contacts c ON c.id = t.requester_contact_id
                WHERE c.tenant_id <> t.tenant_id OR c.bus_id <> t.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket names a contact of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_tickets t JOIN helpdesk.hd_contracts c ON c.id = t.contract_id
                WHERE c.tenant_id <> t.tenant_id OR c.bus_id <> t.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket is under a contract of another business';
    END IF;
END $$;

COMMIT;
