-- Approval workflow: who approves a loan, in how many steps, and a record of
-- every decision.
--
-- 1. ld_approval_workflow_settings: per business, whether the person who
--    captured a loan may approve it (maker-checker), and the approval levels.
--    Each level applies from an amount upward and names the roles and/or
--    users who may decide it. With no levels, one approval by anyone holding
--    the approve permission is enough, as before.
-- 2. ld_loan_approval_steps: each decision at each level (approved or
--    rejected, by whom, when, with what comment and amount). Earlier rounds
--    are kept, marked superseded, when a loan is rejected or re-captured.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_approval_workflow_settings (
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    maker_checker BOOLEAN NOT NULL DEFAULT false,
    -- [{name, min_amount, role_ids: [], user_ids: [], applies_to: ["LOAN","RESTRUCTURE","REFINANCE","TOPUP"]}]
    levels JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_by TEXT,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    udatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, org_id, bus_id)
);

CREATE TABLE IF NOT EXISTS loandrift.ld_loan_approval_steps (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    bus_id TEXT NOT NULL,
    loc_id TEXT NOT NULL,
    loan_id TEXT NOT NULL,
    request_type TEXT NOT NULL DEFAULT 'LOAN' CHECK (request_type IN ('LOAN', 'RESTRUCTURE', 'REFINANCE', 'TOPUP', 'GROUP')),
    level_no INTEGER NOT NULL,
    level_count INTEGER NOT NULL,
    level_name TEXT,
    status TEXT NOT NULL CHECK (status IN ('APPROVED', 'REJECTED')),
    decided_by TEXT NOT NULL,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comment TEXT,
    amount NUMERIC,
    -- The levels in force when this round began, so a settings change does not
    -- move the goalposts for a loan already part-way through.
    levels_snapshot JSONB,
    superseded BOOLEAN NOT NULL DEFAULT false,
    cdatetime TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ld_loan_approval_steps_loan ON loandrift.ld_loan_approval_steps (tenant_id, loan_id, cdatetime);
-- One decision per level per round.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_loan_approval_steps_level
    ON loandrift.ld_loan_approval_steps (tenant_id, loan_id, level_no) WHERE NOT superseded;

-- Everyone who can see loans can see how an approval is going; changing the
-- workflow uses the settings permission.
