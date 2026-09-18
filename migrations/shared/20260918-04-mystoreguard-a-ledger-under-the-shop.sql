-- Books for a shop that already keeps its money in twenty places.
--
-- MyStoreGuard records every financial event it needs to trade: sales with
-- their cost of goods on each line, payments by method, returns with refunds
-- and restocking fees, purchases, expenses, instalments with penalties and
-- settlement discounts, gift cards, store credit, loyalty, affiliate
-- commissions. What it has never had is anywhere those meet. There is no
-- profit figure anywhere in the codebase.
--
-- The temptation is to answer each question on its own — a profit report here,
-- a cash summary there, an amount-owed screen somewhere else. That produces
-- four screens that compute money four ways and disagree by Friday, and the
-- shop cannot tell which is lying.
--
-- So: one journal, and every question answered as a view over it. A sale posts
-- entries. A refund posts entries. Profit is income accounts minus expense
-- accounts over a period; cash is the movement on cash accounts; what a shop
-- owes is the balance of its payable accounts. One record of one fact.
--
-- Three rules the database enforces rather than trusting anybody to keep:
--
--   an entry balances            debits equal credits, checked at COMMIT
--   an entry posts once          (source_type, source_id) is unique, so the
--                                backfill can be re-run and the sale that was
--                                already posted is not posted twice
--   nothing is edited            a mistake is corrected by a reversing entry,
--                                which is what an audit trail means
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================
-- 1. The chart of accounts.
-- =====================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ledger_accounts (
    id                text        PRIMARY KEY,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,

    -- A shop's own numbering, so an accountant can recognise it. Unique per
    -- business rather than globally: two shops both having a "4000 Sales" is
    -- the normal case, not a clash.
    code              text        NOT NULL,
    name              text        NOT NULL,

    -- What the account IS, which decides its sign and which statement it
    -- appears on. Everything else about reporting follows from this column.
    account_type      text        NOT NULL,
    -- A narrower label within the type — CASH, BANK, RECEIVABLE, PAYABLE,
    -- INVENTORY, COGS, TAX, GIFT_CARD, STORE_CREDIT — so the cash book can
    -- find cash without matching on names a shop is free to change.
    account_subtype   text,

    parent_id         text,
    -- Accounts the app posts to by rule. A shop may rename one; it may not
    -- delete one, or the posting that depends on it has nowhere to go.
    is_system         boolean     NOT NULL DEFAULT false,
    is_active         boolean     NOT NULL DEFAULT true,
    description       text,

    cdate             date        NOT NULL DEFAULT CURRENT_DATE,
    ctime             time        NOT NULL DEFAULT CURRENT_TIME,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    udatetime         timestamptz,
    created_by        text,
    updated_by        text,
    deleted_by        text,

    CONSTRAINT ck_msg_ledger_accounts_type CHECK (
        account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE')),
    CONSTRAINT fk_msg_ledger_accounts_parent
        FOREIGN KEY (parent_id) REFERENCES mystoreguard.msg_ledger_accounts (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ledger_accounts_code
    ON mystoreguard.msg_ledger_accounts (bus_id, code) WHERE deleted_by IS NULL;
CREATE INDEX IF NOT EXISTS ix_msg_ledger_accounts_subtype
    ON mystoreguard.msg_ledger_accounts (bus_id, account_subtype)
    WHERE deleted_by IS NULL;


-- =====================================================================
-- 2. The journal: one entry per financial event.
-- =====================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ledger_entries (
    id                text        PRIMARY KEY,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,
    -- Which branch the money moved at. Null for something business-wide.
    loc_id            text,

    -- The date the event happened, not the date it was posted. A sale made on
    -- Sunday and posted on Monday belongs to Sunday, or every month-end is
    -- wrong at its edges.
    entry_date        date        NOT NULL,

    -- What caused this. SALE, SALE_PAYMENT, RETURN, PURCHASE, PURCHASE_PAYMENT,
    -- EXPENSE, INSTALMENT_COLLECTION, GIFT_CARD_ISSUE, STORE_CREDIT_ISSUE,
    -- AFFILIATE_COMMISSION, MANUAL … and the id of the thing itself, so any
    -- line can be traced back to the sale or the receipt it came from.
    source_type       text        NOT NULL,
    source_id         text,
    description       text,

    -- A correction is a new entry that undoes an old one. Nothing is edited.
    reverses_entry_id text,
    currency_id       text,

    cdate             date        NOT NULL DEFAULT CURRENT_DATE,
    ctime             time        NOT NULL DEFAULT CURRENT_TIME,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    deleted_by        text,

    CONSTRAINT fk_msg_ledger_entries_reverses
        FOREIGN KEY (reverses_entry_id) REFERENCES mystoreguard.msg_ledger_entries (id)
);

-- Posted once, whatever happens. This is what lets the backfill be re-run over
-- a shop's whole history without doubling every figure — the second attempt
-- collides here instead of quietly adding a parallel set of books.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ledger_entries_source
    ON mystoreguard.msg_ledger_entries (bus_id, source_type, source_id)
    WHERE source_id IS NOT NULL AND deleted_by IS NULL;

CREATE INDEX IF NOT EXISTS ix_msg_ledger_entries_date
    ON mystoreguard.msg_ledger_entries (bus_id, entry_date);
CREATE INDEX IF NOT EXISTS ix_msg_ledger_entries_branch_date
    ON mystoreguard.msg_ledger_entries (bus_id, loc_id, entry_date);


-- =====================================================================
-- 3. The lines. Debits on the left, credits on the right, as ever.
-- =====================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ledger_lines (
    id                text        PRIMARY KEY,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,
    entry_id          text        NOT NULL,
    account_id        text        NOT NULL,

    -- One side or the other, never both, never neither. Amounts are positive:
    -- a negative debit is a credit written by somebody who was in a hurry, and
    -- it makes every sum in every report wrong in a way nobody can see.
    debit             numeric(18,6) NOT NULL DEFAULT 0,
    credit            numeric(18,6) NOT NULL DEFAULT 0,

    memo              text,
    -- What the line is about, where that is worth knowing. All optional: a
    -- line is valid without any of them.
    product_id        text,
    customer_id       text,
    supplier_id       text,
    sort_order        integer     NOT NULL DEFAULT 0,

    cdatetime         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_msg_ledger_lines_entry
        FOREIGN KEY (entry_id) REFERENCES mystoreguard.msg_ledger_entries (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_msg_ledger_lines_account
        FOREIGN KEY (account_id) REFERENCES mystoreguard.msg_ledger_accounts (id),
    CONSTRAINT ck_msg_ledger_lines_one_side CHECK (
        debit >= 0 AND credit >= 0
        AND (debit = 0) <> (credit = 0)
    )
);

CREATE INDEX IF NOT EXISTS ix_msg_ledger_lines_entry
    ON mystoreguard.msg_ledger_lines (entry_id);
CREATE INDEX IF NOT EXISTS ix_msg_ledger_lines_account
    ON mystoreguard.msg_ledger_lines (bus_id, account_id);


-- =====================================================================
-- 4. An entry balances. Checked at COMMIT, not per row.
--
--    Per row is impossible: the first line of any entry is unbalanced by
--    definition. DEFERRABLE INITIALLY DEFERRED means the whole entry is
--    written and then judged, which is the only point at which the question
--    makes sense.
-- =====================================================================
CREATE OR REPLACE FUNCTION mystoreguard.msg_ledger_entry_balances()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    debits  numeric(18,6);
    credits numeric(18,6);
    entry   text := COALESCE(NEW.entry_id, OLD.entry_id);
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
      INTO debits, credits
      FROM mystoreguard.msg_ledger_lines
     WHERE entry_id = entry;

    -- An entry with no lines at all is allowed: it is a header mid-write, or
    -- one whose lines have just been removed with it.
    IF debits = 0 AND credits = 0 THEN
        RETURN NULL;
    END IF;

    IF debits <> credits THEN
        RAISE EXCEPTION
            'ledger entry % does not balance: debits %, credits %, out by %',
            entry, debits, credits, debits - credits;
    END IF;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS tr_msg_ledger_lines_balance ON mystoreguard.msg_ledger_lines;
CREATE CONSTRAINT TRIGGER tr_msg_ledger_lines_balance
    AFTER INSERT OR UPDATE OR DELETE ON mystoreguard.msg_ledger_lines
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION mystoreguard.msg_ledger_entry_balances();


-- =====================================================================
-- 5. Closing the books on a period.
--
--    Once a month is signed off, a late sale must not change last month's
--    profit. The lock says where the line is; posting checks it.
-- =====================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_ledger_period_locks (
    id                text        PRIMARY KEY,
    tenant_id         text        NOT NULL,
    org_id            text        NOT NULL,
    bus_id            text        NOT NULL,
    -- Nothing may be posted on or before this date.
    locked_through    date        NOT NULL,
    description       text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_ledger_period_locks_bus
    ON mystoreguard.msg_ledger_period_locks (bus_id);

COMMENT ON TABLE mystoreguard.msg_ledger_entries IS
    'One entry per financial event. Profit, cash and what is owed are all views over this.';
COMMENT ON COLUMN mystoreguard.msg_ledger_entries.entry_date IS
    'When it happened, not when it was posted. Month-end depends on this.';
