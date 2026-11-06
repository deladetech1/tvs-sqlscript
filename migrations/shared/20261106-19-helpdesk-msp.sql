-- Help Desk R4: MSP client accounts.
--
--   hd_client_accounts  a client served by the business: a record inside the business, never a
--                       tenant or a Core organisation (owner decision D9, provisional)
--   hd_client_agents    users scoped to one or more clients; a user listed here sees only their
--                       clients' records (R4.md §4)
--   hd_assets, hd_cis, hd_problems, hd_changes  + client_account_id
--
-- Also the FKs from 20261106-16's client_account_id columns (hd_contacts, hd_contracts,
-- hd_tickets), now that hd_client_accounts exists. hd_client_accounts.party_id is registered in
-- core_platform.cp_party_references. CHECK lists are defined here, inline. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R4.md §3, §4. Idempotent; safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS helpdesk.hd_client_accounts (
    id                     text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id              text NOT NULL,
    bus_id                 text NOT NULL,
    name                   text NOT NULL,
    code                   text NOT NULL,
    party_id               text,
    state                  text NOT NULL DEFAULT 'active'
                           CONSTRAINT hd_client_accounts_state_check CHECK (state IN ('active', 'suspended', 'offboarded')),
    brand_name             text,
    brand_color            text,
    logo_attachment_id     text REFERENCES helpdesk.hd_attachments (id),
    default_sla_policy_id  text REFERENCES helpdesk.hd_sla_policies (id),
    notes                  text,
    version                int NOT NULL DEFAULT 1,
    cdatetime              timestamptz NOT NULL DEFAULT now(),
    created_by             text,
    updated_at             timestamptz,
    updated_by             text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_client_accounts_code_uq ON helpdesk.hd_client_accounts (tenant_id, bus_id, lower(code));

CREATE TABLE IF NOT EXISTS helpdesk.hd_client_agents (
    tenant_id          text NOT NULL,
    bus_id             text NOT NULL,
    client_account_id  text NOT NULL REFERENCES helpdesk.hd_client_accounts (id),
    user_id            text NOT NULL,
    role               text NOT NULL DEFAULT 'agent' CONSTRAINT hd_client_agents_role_check CHECK (role IN ('agent', 'lead')),
    cdatetime          timestamptz NOT NULL DEFAULT now(),
    created_by         text,
    updated_at         timestamptz,
    updated_by         text,
    PRIMARY KEY (client_account_id, user_id)
);
-- clientScopeSQL asks, per request, which clients a user is scoped to.
CREATE INDEX IF NOT EXISTS hd_client_agents_user_idx ON helpdesk.hd_client_agents (tenant_id, bus_id, user_id);

-- ================================================================== client columns
ALTER TABLE helpdesk.hd_assets   ADD COLUMN IF NOT EXISTS client_account_id text REFERENCES helpdesk.hd_client_accounts (id);
ALTER TABLE helpdesk.hd_cis      ADD COLUMN IF NOT EXISTS client_account_id text REFERENCES helpdesk.hd_client_accounts (id);
ALTER TABLE helpdesk.hd_problems ADD COLUMN IF NOT EXISTS client_account_id text REFERENCES helpdesk.hd_client_accounts (id);
ALTER TABLE helpdesk.hd_changes  ADD COLUMN IF NOT EXISTS client_account_id text REFERENCES helpdesk.hd_client_accounts (id);
CREATE INDEX IF NOT EXISTS hd_assets_client_idx   ON helpdesk.hd_assets (tenant_id, bus_id, client_account_id);
CREATE INDEX IF NOT EXISTS hd_cis_client_idx      ON helpdesk.hd_cis (tenant_id, bus_id, client_account_id);
CREATE INDEX IF NOT EXISTS hd_problems_client_idx ON helpdesk.hd_problems (tenant_id, bus_id, client_account_id);
CREATE INDEX IF NOT EXISTS hd_changes_client_idx  ON helpdesk.hd_changes (tenant_id, bus_id, client_account_id);
CREATE INDEX IF NOT EXISTS hd_tickets_client_idx  ON helpdesk.hd_tickets (tenant_id, bus_id, client_account_id);

-- The 20261106-16 columns, tied now that the table exists.
ALTER TABLE helpdesk.hd_contacts DROP CONSTRAINT IF EXISTS hd_contacts_client_account_fk;
ALTER TABLE helpdesk.hd_contacts ADD CONSTRAINT hd_contacts_client_account_fk
    FOREIGN KEY (client_account_id) REFERENCES helpdesk.hd_client_accounts (id);
ALTER TABLE helpdesk.hd_contracts DROP CONSTRAINT IF EXISTS hd_contracts_client_account_fk;
ALTER TABLE helpdesk.hd_contracts ADD CONSTRAINT hd_contracts_client_account_fk
    FOREIGN KEY (client_account_id) REFERENCES helpdesk.hd_client_accounts (id);
ALTER TABLE helpdesk.hd_tickets DROP CONSTRAINT IF EXISTS hd_tickets_client_account_fk;
ALTER TABLE helpdesk.hd_tickets ADD CONSTRAINT hd_tickets_client_account_fk
    FOREIGN KEY (client_account_id) REFERENCES helpdesk.hd_client_accounts (id);

INSERT INTO core_platform.cp_party_references (table_name, column_name, is_extension) VALUES
    ('helpdesk.hd_client_accounts', 'party_id', false)
ON CONFLICT (table_name, column_name) DO UPDATE SET is_extension = EXCLUDED.is_extension;

-- ===================================================================== invariants
DO $$
DECLARE t text;
        hit boolean;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core_platform.cp_party_references
                    WHERE table_name = 'helpdesk.hd_client_accounts' AND column_name = 'party_id') THEN
        RAISE EXCEPTION 'helpdesk.hd_client_accounts.party_id is not in cp_party_references; a party merge would miss it';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_client_accounts a JOIN core_platform.cp_parties p ON p.id = a.party_id
                WHERE p.tenant_id <> a.tenant_id OR p.bus_id <> a.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk client account is on a party of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_client_agents g JOIN helpdesk.hd_client_accounts a ON a.id = g.client_account_id
                WHERE a.tenant_id <> g.tenant_id OR a.bus_id <> g.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk client agent row names a client of another business';
    END IF;
    -- Every record that carries a client names a client of its own business.
    FOREACH t IN ARRAY ARRAY['hd_tickets', 'hd_contacts', 'hd_contracts', 'hd_assets', 'hd_cis', 'hd_problems', 'hd_changes'] LOOP
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM helpdesk.%I r JOIN helpdesk.hd_client_accounts a ON a.id = r.client_account_id
                                         WHERE a.tenant_id <> r.tenant_id OR a.bus_id <> r.bus_id)', t) INTO hit;
        IF hit THEN
            RAISE EXCEPTION 'helpdesk.% names an MSP client of another business', t;
        END IF;
    END LOOP;
END $$;

COMMIT;
