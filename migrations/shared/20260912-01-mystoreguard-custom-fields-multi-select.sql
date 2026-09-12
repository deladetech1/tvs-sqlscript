-- A custom field can offer more than one answer.
--
-- SELECT asks a question with one answer: which colour, which grade. Plenty of
-- the questions a shop actually asks are not like that — which networks a
-- handset is unlocked for, which rooms a curtain suits, what a fault covers —
-- and until now the only way to record them was a free-text field that nobody
-- can report on, because "Vodafone, MTN" and "MTN and Vodafone" are two
-- different strings.
--
-- MULTI_SELECT is the same field with the same `options`; only the number of
-- answers changes.
--
-- The VALUE stays in the text column it has always used, holding the chosen
-- options separated by " | ". A separator rather than a new column or a JSON
-- type, because:
--
--   * every reader of this table — the forms, the chips on a product, the
--     export — already reads text, and a second shape would mean each of them
--     learning which type it was looking at before it could show anything;
--   * the pipe cannot appear inside an option: options are typed into a form
--     that trims them, and a shop that types one is choosing a separator, not
--     an option;
--   * a single answer is still exactly the string it was, so switching a field
--     from SELECT to MULTI_SELECT leaves every answer already given readable,
--     and switching back leaves the first answer standing.

ALTER TABLE mystoreguard.msg_custom_fields
    DROP CONSTRAINT IF EXISTS ck_msg_custom_fields_type;

ALTER TABLE mystoreguard.msg_custom_fields
    ADD CONSTRAINT ck_msg_custom_fields_type
    CHECK (field_type IN ('TEXT', 'TEXTAREA', 'NUMBER', 'DATE',
                          'SELECT', 'MULTI_SELECT', 'BOOLEAN'));

COMMENT ON COLUMN mystoreguard.msg_custom_fields.options IS
    'Choices for SELECT and MULTI_SELECT. Empty for every other type.';

COMMENT ON COLUMN mystoreguard.msg_custom_field_values.value IS
    'What was entered. For MULTI_SELECT, the chosen options separated by " | " — '
    'a single answer is the plain string, so SELECT and MULTI_SELECT read the same.';
