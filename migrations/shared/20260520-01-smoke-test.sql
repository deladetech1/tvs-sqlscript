-- Smoke test for shared migrations runner. Idempotent.
CREATE TABLE IF NOT EXISTS core_platform._migration_smoke_test (
    id          TEXT PRIMARY KEY,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    note        TEXT
);

INSERT INTO core_platform._migration_smoke_test (id, note)
VALUES ('shared-20260520-01', 'applied by migrations/shared/')
ON CONFLICT (id) DO NOTHING;
