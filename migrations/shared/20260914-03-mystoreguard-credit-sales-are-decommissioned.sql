-- Credit sales are gone.
--
-- A third kind of sale — goods handed over at the till against a promise to
-- pay later — alongside INSTANT and INSTALLMENT. It is being decommissioned:
-- nobody is using it, and no sale of that kind has ever been made. Checked
-- before any of this was removed:
--
--     DEV          14 INSTANT, 3 INSTALLMENT, 0 CREDIT
--     PRODUCTION   20 INSTALLMENT,            0 CREDIT
--
-- So there is no history to preserve and nothing to migrate. The screens, the
-- sale mode, the branches behind it and its subscription gate have all gone;
-- this closes the last door, so a stale client cannot post one and have the
-- database accept it.
--
-- Narrowing a CHECK, not widening it: the constraint is validated against
-- every existing row as it is created, which would fail loudly if a credit
-- sale existed anywhere after all. That is the outcome to want — better a
-- refused migration than a row the application can no longer read.

ALTER TABLE mystoreguard.msg_sales
    DROP CONSTRAINT IF EXISTS ck_msg_sales_sale_mode;

ALTER TABLE mystoreguard.msg_sales
    ADD CONSTRAINT ck_msg_sales_sale_mode
    CHECK (sale_mode = ANY (ARRAY['INSTANT'::text, 'INSTALLMENT'::text, 'INVOICE'::text]));
