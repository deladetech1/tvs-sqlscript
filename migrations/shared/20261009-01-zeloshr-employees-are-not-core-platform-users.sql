-- ---------------------------------------------------------------------------
-- People added in ZelosHR are not Core Platform users.
--
-- Core Platform lists, and signs in, only its members: a cp_members row is what
-- makes someone a Core Platform user. ZelosHR's employee portal used to sign
-- employees in through Core Platform's login, and since that login refuses
-- non-members, the portal gave every employee who activated (or reset) their
-- portal password a cp_members row. The effect: everyone HR added showed up in
-- Core Platform's Users list, and could sign in to the Core Platform hub.
--
-- The portal now checks the password itself and issues its own session, so the
-- membership is no longer needed. This removes the rows ZelosHR created, which
-- are the ones carrying its description. A person who was already a Core
-- Platform member before activating kept their own row (ZelosHR only added one
-- when none existed), so real Core Platform users are untouched.
--
-- Idempotent: once the rows are gone there is nothing left to delete.
-- ---------------------------------------------------------------------------

DELETE FROM core_platform.cp_members
 WHERE description = 'ZelosHR employee portal';
