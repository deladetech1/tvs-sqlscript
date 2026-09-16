-- Permissions that describe what they actually grant.
--
-- Every MyStoreGuard "get" permission claimed it could view statistics, view
-- deletion chat history and export data. Every "update" claimed it could
-- restore soft-deleted records and approve or reject deletion requests.
--
-- None of that exists. Across the whole backend there is not one restore
-- route, not one export route, and not one deletion-request route. Statistics
-- is real but has its OWN permission on every resource, so a "get" grant does
-- not include it either.
--
-- It matters because these sentences are what somebody reads while deciding
-- who gets what. "Can approve or reject deletion requests" tells an owner that
-- deletions at their shop go through an approval step. They do not — a delete
-- is immediate — and somebody granting update on that basis is being told the
-- opposite of the truth.
--
-- Only the two sentences that were copied wholesale are rewritten, matched on
-- their exact shape. A permission that genuinely is about deletion chat
-- history — Loandrift has one, and it is a real feature there — does not match
-- and is left alone.

UPDATE core_platform.cp_permissions
   SET description = regexp_replace(
           description,
           '^Can view, list, read (.+), view statistics, view deletion chat history, and export data$',
           'Can view, list and read \1')
 WHERE description ~ '^Can view, list, read (.+), view statistics, view deletion chat history, and export data$';

UPDATE core_platform.cp_permissions
   SET description = regexp_replace(
           description,
           '^Can update (.+), restore soft-deleted .+, approve or reject deletion requests$',
           'Can update \1')
 WHERE description ~ '^Can update (.+), restore soft-deleted .+, approve or reject deletion requests$';
