-- Keep the order of the client's identification array when editing/reloading.
ALTER TABLE loandrift.ld_client_identifications
    ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;
