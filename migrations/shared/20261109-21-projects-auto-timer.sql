-- Projects: time work automatically.
--
--   prj_projects.auto_timer  A project setting, off by default. When on, moving a work item
--                            INTO an In progress status starts the clock of its assignee (or,
--                            with nobody assigned, of whoever moved it); moving it OUT of In
--                            progress stops every clock on it and logs the time, the same way
--                            the stop button does.
--   prj_timers.auto          The clock was started that way (the running-clock UI says so).
--   prj_timers.started_by    Who made the move that started it (null: the person themselves,
--                            or a rule with nobody behind it). A user id, no FK, like the
--                            table's user_id.
--
-- Only adds columns with defaults: every project keeps working exactly as before. Idempotent;
-- safe to re-run on every deploy.

BEGIN;

ALTER TABLE projects.prj_projects ADD COLUMN IF NOT EXISTS auto_timer boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_timers   ADD COLUMN IF NOT EXISTS auto       boolean NOT NULL DEFAULT false;
ALTER TABLE projects.prj_timers   ADD COLUMN IF NOT EXISTS started_by text;

-- Finding the clocks on a work item (a move out of In progress, a delete) reads by task.
CREATE INDEX IF NOT EXISTS prj_timers_task_idx ON projects.prj_timers (task_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'projects' AND table_name = 'prj_projects' AND column_name = 'auto_timer') THEN
        RAISE EXCEPTION 'prj_projects has no auto_timer';
    END IF;
    IF (SELECT count(*) FROM information_schema.columns
         WHERE table_schema = 'projects' AND table_name = 'prj_timers' AND column_name IN ('auto', 'started_by')) <> 2 THEN
        RAISE EXCEPTION 'prj_timers is missing auto or started_by';
    END IF;
END $$;

COMMIT;
