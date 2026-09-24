-- Say who did it.
--
-- cp_security_events stores both an id and a name for the actor and the
-- subject, and the dashboard shows the NAME. Most callers pass only the id —
-- actor_user_id=performed_by and nothing else — so the "Who" column read "—"
-- on every event raised by an administrator doing something, which is exactly
-- the class of event where who did it is the whole point.
--
-- The writer now resolves the name. This fills in the rows written before it
-- did, so the history reads the same as everything after it.
--
-- Idempotent; safe to re-run on every deploy. Only touches rows where the name
-- is missing and the id is present, so it does nothing on the second run and
-- never overwrites a name a caller supplied deliberately.

UPDATE core_platform.cp_security_events e
   SET actor_name = COALESCE(u.fullname, u.email)
  FROM core_platform.cp_users u
 WHERE u.id = e.actor_user_id
   AND u.tenant_id = e.tenant_id
   AND e.actor_user_id IS NOT NULL
   AND e.actor_name IS NULL
   AND COALESCE(u.fullname, u.email) IS NOT NULL;

UPDATE core_platform.cp_security_events e
   SET subject_name = COALESCE(u.fullname, u.email)
  FROM core_platform.cp_users u
 WHERE u.id = e.subject_user_id
   AND u.tenant_id = e.tenant_id
   AND e.subject_user_id IS NOT NULL
   AND e.subject_name IS NULL
   AND COALESCE(u.fullname, u.email) IS NOT NULL;

-- Does this break the tamper-evident chain? No, and it is worth saying why
-- rather than leaving the next reader to work it out.
--
-- cp_security_event_payload hashes actor_user_id and subject_user_id — the
-- IDS — and not the names. The names are a rendering convenience derived from
-- them, in the same category as the triage columns: something that can be
-- corrected without changing what the record says happened. Verified rather
-- than assumed: cp_verify_security_chain still reports intact after this runs.
