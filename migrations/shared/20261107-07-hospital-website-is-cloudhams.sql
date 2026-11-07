-- The hospital app's website is served at cloudhams.dev.trovesuite.com. Its API keeps
-- api.hospital.dev.trovesuite.com, and the old hospital.dev route stays so old links still answer.
-- Safe to re-run.

INSERT INTO control_plane.ctl_reserved_labels (label, reason, created_by)
SELECT v.label, v.reason, 'migration:20261107-07'
  FROM (VALUES ('cloudhams', 'a product: cloudhams.dev.trovesuite.com, the hospital app''s website')) AS v(label, reason)
 WHERE NOT EXISTS (SELECT 1 FROM control_plane.ctl_reserved_labels r WHERE r.label = v.label);

-- Dev only: the WHERE EXISTS on the dev cell keeps this row out of production.
INSERT INTO control_plane.ctl_tenant_routes (host, tenant_id, tier, cell_key, status, is_wildcard, cdate, ctime, cdatetime, created_by)
SELECT h.host, NULL, 'POOLED', h.cell, 'ACTIVE', false, CURRENT_DATE::text, CURRENT_TIME::text, now(), 'migration 20261107-07'
  FROM (VALUES ('cloudhams.dev.trovesuite.com', 'uksouth-dev')) AS h(host, cell)
 WHERE EXISTS (SELECT 1 FROM control_plane.ctl_cells c WHERE c.cell_key = h.cell)
ON CONFLICT (host) DO NOTHING;
