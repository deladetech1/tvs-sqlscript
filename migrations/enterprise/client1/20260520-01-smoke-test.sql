-- Smoke test for enterprise client1 migrations runner. Idempotent.
INSERT INTO core_platform._migration_smoke_test (id, note)
VALUES ('client1-20260520-01', 'applied by migrations/enterprise/client1/')
ON CONFLICT (id) DO NOTHING;
