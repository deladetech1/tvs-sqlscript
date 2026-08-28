-- 20260828-07-coreplatform-business-details.sql
-- Who a business actually is, beyond its name.
--
-- A business row held a name and a description, which is enough to pick one
-- from a list and not enough to put on a document. Anything a customer or
-- supplier receives — an invoice, a purchase order, a receipt — has to say who
-- sent it and how to reach them, and every app was left inventing that or
-- leaving it blank.
--
-- All nullable. These are being added to businesses that already exist and
-- trade perfectly well without them, so a required column here would break
-- every save until somebody filled it in.
--
-- Idempotent; safe to re-run on every deploy.

ALTER TABLE core_platform.cp_businesses
    -- On the document, so a supplier can reply and a customer can query a bill.
    ADD COLUMN IF NOT EXISTS email               text,
    ADD COLUMN IF NOT EXISTS contact             text,
    ADD COLUMN IF NOT EXISTS address             text,
    ADD COLUMN IF NOT EXISTS website_url         text,

    -- Named on a purchase order because a supplier opening it wants a person,
    -- not a switchboard.
    ADD COLUMN IF NOT EXISTS contact_person      text,

    -- Printed where it is required of a trading business, and useful to a
    -- supplier setting up an account for a new buyer.
    ADD COLUMN IF NOT EXISTS registration_number text,

    -- Not for documents: it is how the platform can tell a pharmacy from a
    -- boutique when defaults and reporting need to differ.
    ADD COLUMN IF NOT EXISTS industry            text;
