-- Projects: colours for a project's statuses, chosen in Settings → Statuses.
--
--   column_color: the board column's colour (its strip and a tint behind its cards).
--   card_color:   the colour of a card while it is in that status (black for To do, pink for
--                 In progress -- whatever the team likes). The text on it is made readable.
--
-- Both are #rrggbb, or NULL for the board's own look. Idempotent; safe to re-run every deploy.

BEGIN;

ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS column_color text;
ALTER TABLE projects.prj_statuses ADD COLUMN IF NOT EXISTS card_color text;

ALTER TABLE projects.prj_statuses DROP CONSTRAINT IF EXISTS prj_statuses_column_color_check;
ALTER TABLE projects.prj_statuses ADD CONSTRAINT prj_statuses_column_color_check CHECK (column_color IS NULL OR column_color ~ '^#[0-9a-f]{6}$');
ALTER TABLE projects.prj_statuses DROP CONSTRAINT IF EXISTS prj_statuses_card_color_check;
ALTER TABLE projects.prj_statuses ADD CONSTRAINT prj_statuses_card_color_check CHECK (card_color IS NULL OR card_color ~ '^#[0-9a-f]{6}$');

COMMIT;
