-- 20260829-04-loandrift-receipt-settings.sql
-- What a repayment receipt says.
--
-- A borrower who hands over cash at a branch gets a piece of paper, and that
-- paper is the only evidence they hold that the money was received. Until now
-- LoanDrift printed nothing, so the branch wrote it out by hand or the borrower
-- left with nothing at all.
--
-- Who the lender is comes from core_platform.cp_businesses (name, address,
-- contact, registration number) rather than being retyped here — that is
-- already the source every other document in the suite draws its letterhead
-- from. This table holds only the choices that are about the receipt itself.
--
-- Business-wide. MyStoreGuard's equivalent is per-location because two shops
-- under one business genuinely print different receipts from different tills;
-- a lender's receipt is the lender's, and a branch does not restyle it.
--
-- Every show_* column defaults to what a plain repayment receipt should already
-- carry, so a lender who never opens this screen still gets a complete one.
--
-- Idempotent; safe to re-run on every deploy.

CREATE TABLE IF NOT EXISTS loandrift.ld_receipt_settings (
    id          text PRIMARY KEY,
    tenant_id   text NOT NULL,
    org_id      text NOT NULL,
    bus_id      text NOT NULL,

    -- Paper ------------------------------------------------------------
    -- 80MM for a thermal roll at a branch counter, A4 for a printed and
    -- filed receipt. Both render from the same component.
    paper_size  text NOT NULL DEFAULT 'A4',

    -- Header -----------------------------------------------------------
    show_logo             boolean NOT NULL DEFAULT false,
    -- Points at a file in the app's document store; NULL means none chosen.
    logo_document_id      text,
    show_business_name    boolean NOT NULL DEFAULT true,
    show_business_address boolean NOT NULL DEFAULT true,
    show_business_contact boolean NOT NULL DEFAULT true,
    show_registration_no  boolean NOT NULL DEFAULT false,
    header_text           text,

    -- The payment ------------------------------------------------------
    show_receipt_number   boolean NOT NULL DEFAULT true,
    show_date             boolean NOT NULL DEFAULT true,
    show_time             boolean NOT NULL DEFAULT true,
    -- Who took the money. Off by default: a borrower does not need the
    -- clerk's name, and a lender who wants it for accountability turns it on.
    show_received_by      boolean NOT NULL DEFAULT false,
    show_client           boolean NOT NULL DEFAULT true,
    show_client_contact   boolean NOT NULL DEFAULT false,
    show_loan_reference   boolean NOT NULL DEFAULT true,
    show_payment_method   boolean NOT NULL DEFAULT true,

    -- The money --------------------------------------------------------
    -- How the payment was split. The borrower's money does not all reduce
    -- what they owe — some of it clears penalties, some is interest — and a
    -- receipt that hides that is how a borrower comes to believe a payment
    -- did less than it did, or more.
    show_penalty_portion  boolean NOT NULL DEFAULT true,
    show_principal_interest_split boolean NOT NULL DEFAULT false,
    show_amount_paid      boolean NOT NULL DEFAULT true,
    show_total_payable    boolean NOT NULL DEFAULT true,
    show_balance          boolean NOT NULL DEFAULT true,
    show_next_payment_date boolean NOT NULL DEFAULT true,

    -- Footer -----------------------------------------------------------
    footer_text           text,
    show_powered_by       boolean NOT NULL DEFAULT true,

    -- Audit ------------------------------------------------------------
    cdate      date,
    ctime      time,
    cdatetime  timestamptz NOT NULL DEFAULT now(),
    udatetime  timestamptz,
    created_by text,
    updated_by text
);

-- A whitelist, so a bad value cannot reach the renderer and print nothing.
ALTER TABLE loandrift.ld_receipt_settings
    DROP CONSTRAINT IF EXISTS ck_ld_receipt_settings_paper_size;
ALTER TABLE loandrift.ld_receipt_settings
    ADD CONSTRAINT ck_ld_receipt_settings_paper_size
    CHECK (paper_size IN ('80MM', 'A4'));

-- One row per business. The service upserts on this.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ld_receipt_settings_business
    ON loandrift.ld_receipt_settings (tenant_id, org_id, bus_id);
