-- SCM: the lists for a lot's quality status and a serial's status (20261029-22). The lists live
-- only here: to change one, edit this file. Idempotent; safe to re-run.

BEGIN;

ALTER TABLE scm.scm_lots DROP CONSTRAINT IF EXISTS scm_lots_quality_status_check;
ALTER TABLE scm.scm_lots ADD CONSTRAINT scm_lots_quality_status_check CHECK (quality_status IN
    ('available', 'quarantine', 'hold', 'rejected'));

ALTER TABLE scm.scm_serials DROP CONSTRAINT IF EXISTS scm_serials_status_check;
ALTER TABLE scm.scm_serials ADD CONSTRAINT scm_serials_status_check CHECK (status IN
    ('in_stock', 'consumed', 'shipped', 'scrapped', 'returned'));

COMMIT;
