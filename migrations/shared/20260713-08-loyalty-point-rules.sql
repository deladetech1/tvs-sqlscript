-- Loyalty points earning rules. Each rule is a condition (on the whole sale or
-- on individual line items) plus a reward (bonus points). Businesses choose
-- whether matching rules STACK (add up) or only the HIGHEST priority wins.
-- Idempotent.

CREATE TABLE IF NOT EXISTS mystoreguard.msg_loyalty_point_rules (
    id                 text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id          text NOT NULL,
    org_id             text NOT NULL,
    bus_id             text NOT NULL,
    name               text NOT NULL,
    is_active          boolean NOT NULL DEFAULT true,
    priority           integer NOT NULL DEFAULT 0,   -- higher wins / evaluated first
    scope              text NOT NULL DEFAULT 'SALE', -- SALE | ITEM
    condition_field    text NOT NULL,                -- SALE_TOTAL | SALE_ITEM_COUNT | ITEM_QTY | ITEM_PRICE | ITEM_LINE_TOTAL
    condition_operator text NOT NULL DEFAULT 'GTE',  -- GTE | LTE | GT | LT | EQ | BETWEEN
    condition_value    numeric(18, 2) NOT NULL DEFAULT 0,
    condition_value2   numeric(18, 2),               -- upper bound for BETWEEN
    target_type        text NOT NULL DEFAULT 'ANY',  -- ANY | PRODUCT  (item scope)
    target_id          text,                         -- product id when target_type = PRODUCT
    reward_type        text NOT NULL DEFAULT 'FIXED',-- FIXED | PER_UNIT | PERCENT | MULTIPLIER
    reward_value       numeric(18, 2) NOT NULL DEFAULT 0,
    stop_after         boolean NOT NULL DEFAULT false,-- in STACK mode, stop after this rule matches
    delete_status      text NOT NULL DEFAULT 'NOT_DELETED',
    cdate              text,
    ctime              text,
    cdatetime          timestamptz NOT NULL DEFAULT NOW(),
    created_by         text,
    updated_by         text,
    deleted_by         text
);

ALTER TABLE mystoreguard.msg_loyalty_point_rules
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_point_rules_scope;
ALTER TABLE mystoreguard.msg_loyalty_point_rules
    ADD CONSTRAINT ck_msg_loyalty_point_rules_scope CHECK (scope IN ('SALE', 'ITEM'));

ALTER TABLE mystoreguard.msg_loyalty_point_rules
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_point_rules_operator;
ALTER TABLE mystoreguard.msg_loyalty_point_rules
    ADD CONSTRAINT ck_msg_loyalty_point_rules_operator
    CHECK (condition_operator IN ('GTE', 'LTE', 'GT', 'LT', 'EQ', 'BETWEEN'));

ALTER TABLE mystoreguard.msg_loyalty_point_rules
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_point_rules_reward;
ALTER TABLE mystoreguard.msg_loyalty_point_rules
    ADD CONSTRAINT ck_msg_loyalty_point_rules_reward
    CHECK (reward_type IN ('FIXED', 'PER_UNIT', 'PERCENT', 'MULTIPLIER'));

CREATE INDEX IF NOT EXISTS ix_msg_loyalty_point_rules_lookup
    ON mystoreguard.msg_loyalty_point_rules (tenant_id, org_id, bus_id, delete_status);

-- How matching rules combine, per business.
ALTER TABLE mystoreguard.msg_loyalty_settings
    ADD COLUMN IF NOT EXISTS rules_combine_mode text NOT NULL DEFAULT 'STACK';
ALTER TABLE mystoreguard.msg_loyalty_settings
    DROP CONSTRAINT IF EXISTS ck_msg_loyalty_settings_combine_mode;
ALTER TABLE mystoreguard.msg_loyalty_settings
    ADD CONSTRAINT ck_msg_loyalty_settings_combine_mode
    CHECK (rules_combine_mode IN ('STACK', 'HIGHEST'));
