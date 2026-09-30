-- =====================================================================================
-- Let a grant say what it grants, instead of pointing at a row that says it.
--
-- cp_role_permissions stores permission_id and nothing else, so every check has to join
-- cp_permissions to find out what the grant actually allows. The id is the tuple with its
-- parts glued together -- permission-msg-store-sales-create IS msg + store-sales + create --
-- so the join recovers information the row could simply carry.
--
-- These columns are that tuple, written onto the grant itself. Nothing reads them yet; the
-- package starts to in a later release. Adding them changes no behaviour at all.
--
-- The trigger is the point of this migration. Thirty places write cp_role_permissions --
-- seeds, five services, the auto-assign triggers, and every grant migration in this folder,
-- including two from yesterday -- and rewriting all of them to fill four more columns would
-- be thirty chances to miss one. Instead the row derives its own tuple from permission_id on
-- the way in, so every existing writer keeps working untouched and cannot produce a grant
-- whose tuple disagrees with its id.
--
-- permission_id stays, still NOT NULL in practice, still the foreign key. This adds a second
-- way to read the same fact; it removes nothing, and every step after it is reversible by
-- ignoring these columns again.
--
-- Safe to rerun.
-- =====================================================================================

ALTER TABLE core_platform.cp_role_permissions
    ADD COLUMN IF NOT EXISTS app_prefix   text,
    ADD COLUMN IF NOT EXISTS resource_key text,
    ADD COLUMN IF NOT EXISTS action       text,
    ADD COLUMN IF NOT EXISTS target       text,
    ADD COLUMN IF NOT EXISTS scope        text;

-- Fill the tuple from the permission a grant points at, on insert and on any change of
-- permission_id. SECURITY DEFINER is deliberately NOT used: this reads a table every writer
-- can already read.
CREATE OR REPLACE FUNCTION core_platform.cp_role_permissions_fill_pair()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.permission_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT p.app_prefix, p.resource_key, p.action, coalesce(p.target, ''), p.scope
      INTO NEW.app_prefix, NEW.resource_key, NEW.action, NEW.target, NEW.scope
      FROM core_platform.cp_permissions p
     WHERE p.id = NEW.permission_id;

    -- A permission id naming nothing is already a foreign key violation, so this only
    -- happens if that constraint is ever dropped. Leave the columns null rather than
    -- refusing the write: the id remains the authority until nothing reads it.
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cp_role_permissions_fill_pair ON core_platform.cp_role_permissions;
CREATE TRIGGER trg_cp_role_permissions_fill_pair
    BEFORE INSERT OR UPDATE OF permission_id ON core_platform.cp_role_permissions
    FOR EACH ROW EXECUTE FUNCTION core_platform.cp_role_permissions_fill_pair();

-- Backfill what is already there. The trigger only fires on new writes, and every rule
-- change in this folder has needed its own backfill for the same reason.
UPDATE core_platform.cp_role_permissions rp
   SET app_prefix   = p.app_prefix,
       resource_key = p.resource_key,
       action       = p.action,
       target       = coalesce(p.target, ''),
       scope        = p.scope
  FROM core_platform.cp_permissions p
 WHERE p.id = rp.permission_id
   AND (rp.resource_key IS DISTINCT FROM p.resource_key
     OR rp.action       IS DISTINCT FROM p.action
     OR rp.app_prefix   IS DISTINCT FROM p.app_prefix
     OR rp.target       IS DISTINCT FROM coalesce(p.target, '')
     OR rp.scope        IS DISTINCT FROM p.scope);

-- What the per-request check will look up: every grant of one role.
CREATE INDEX IF NOT EXISTS ix_cp_role_permissions_role_pair
    ON core_platform.cp_role_permissions (role_id, tenant_id);
