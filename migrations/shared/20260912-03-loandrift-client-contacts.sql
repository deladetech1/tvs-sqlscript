-- Keep every client contact, in order. contact remains the primary number for existing loan flows.
ALTER TABLE loandrift.ld_clients
    ADD COLUMN IF NOT EXISTS contacts text[] NOT NULL DEFAULT ARRAY[]::text[];

UPDATE loandrift.ld_clients
SET contacts = ARRAY[contact]
WHERE cardinality(contacts) = 0 AND NULLIF(btrim(contact), '') IS NOT NULL;
