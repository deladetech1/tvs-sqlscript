-- Say what broke, in English.
--
-- The verifier reported a break like this:
--
--   altered content: this row no longer matches its own hash
--   (row sec_d7bb2d88c87ec72faf86b36f15f3b89b9fcef7fbe0b19f4937008f867b6,
--    position 13).
--
-- Every word of that is true and none of it tells a reader what happened,
-- which event it happened to, or whether they should be worried. "Row",
-- "hash" and "position" are how the mechanism works, not what went wrong; the
-- id names nothing a person has ever seen; and the sentence never says the one
-- thing that matters, which is that a security event was changed after it was
-- recorded and that this is not something the application can do.
--
-- The fix is a division of labour. This function keeps returning the precise,
-- stable facts — WHICH kind of break, and enough about the affected event to
-- describe it — and the application turns them into a sentence. Prose in a
-- database function cannot be changed without a migration and cannot be
-- translated; prose built from a code can be both.
--
-- Idempotent; safe to re-run on every deploy.


-- The OUT columns change, so the old signature has to go first: Postgres
-- refuses CREATE OR REPLACE when the result type differs. Dropping and
-- recreating in one transaction means no deploy ever sees it missing.
DROP FUNCTION IF EXISTS core_platform.cp_verify_security_chain(text, integer);

CREATE FUNCTION core_platform.cp_verify_security_chain(
    p_tenant_id text, p_limit integer DEFAULT 100000
)
RETURNS TABLE (
    checked        bigint,
    intact         boolean,
    first_bad_id   text,
    first_bad_seq  bigint,
    -- A stable machine code: ALTERED, DELETED or REORDERED. The application
    -- maps it to a sentence. Kept separate from `reason` so that improving the
    -- wording never needs a migration, and so that a caller switching on the
    -- kind of break is not matching against prose.
    reason_code    text,
    reason         text,
    anchor_seq     bigint,
    -- Enough to describe the affected event without a second query, and
    -- without the caller having to trust an id it cannot resolve. "The
    -- sign-in from 154.162.102.136 on 24 September" is something a person can
    -- go and look at; sec_d7bb2d88… is not.
    first_bad_title     text,
    first_bad_occurred  timestamptz,
    -- For a deletion there is no bad row to name — the row is gone. These
    -- bracket the gap instead: the last event that still verifies, and the
    -- first one after the hole.
    gap_after_seq       bigint,
    gap_before_seq      bigint
) AS $$
DECLARE
    r              record;
    v_expected     text;
    v_prev         text := NULL;
    v_prev_seq     bigint := NULL;
    v_checked      bigint := 0;
    v_anchor       bigint := NULL;
BEGIN
    intact := true;
    reason_code := NULL;
    first_bad_title := NULL;
    first_bad_occurred := NULL;
    gap_after_seq := NULL;
    gap_before_seq := NULL;

    FOR r IN
        SELECT * FROM core_platform.cp_security_events
         WHERE tenant_id = p_tenant_id AND chain_seq IS NOT NULL
         ORDER BY chain_seq ASC
         LIMIT p_limit
    LOOP
        v_checked := v_checked + 1;

        IF v_prev IS NULL THEN
            -- The first row we can see. Its predecessor may have been purged
            -- by retention, so its link is taken on trust and reported as the
            -- anchor rather than treated as a break.
            v_anchor := r.chain_seq;
        ELSE
            -- Sequence continuity BEFORE the hash link, deliberately. Deleting
            -- a row from the middle breaks both — the next row's prev_hash
            -- points at something that is no longer there — and whichever
            -- check runs first names the fault. "An event is missing" sends an
            -- investigator looking for a deletion; "this row does not follow
            -- the one before it" sends them looking for an edit that never
            -- happened.
            IF r.chain_seq <> v_prev_seq + 1 THEN
                checked := v_checked; intact := false;
                first_bad_id := r.id; first_bad_seq := r.chain_seq;
                reason_code := 'DELETED';
                reason := format(
                    'the sequence jumps from %s to %s', v_prev_seq, r.chain_seq
                );
                gap_after_seq := v_prev_seq;
                gap_before_seq := r.chain_seq;
                first_bad_title := r.title;
                first_bad_occurred := r.occurred_at;
                anchor_seq := v_anchor;
                RETURN NEXT; RETURN;
            END IF;

            IF r.prev_hash IS DISTINCT FROM v_prev THEN
                checked := v_checked; intact := false;
                first_bad_id := r.id; first_bad_seq := r.chain_seq;
                reason_code := 'REORDERED';
                reason := 'this row does not follow the one before it';
                first_bad_title := r.title;
                first_bad_occurred := r.occurred_at;
                anchor_seq := v_anchor;
                RETURN NEXT; RETURN;
            END IF;
        END IF;

        v_expected := encode(
            sha256(convert_to(
                core_platform.cp_security_event_payload(
                    r.id, r.tenant_id, r.app_id, r.category, r.event_type,
                    r.severity, r.title, r.description, r.actor_user_id,
                    r.subject_user_id, r.ip_address, r.user_agent,
                    r.metadata, r.occurred_at
                ) || E'\x1f' || r.prev_hash,
                'UTF8'
            )), 'hex'
        );

        IF v_expected IS DISTINCT FROM r.row_hash THEN
            checked := v_checked; intact := false;
            first_bad_id := r.id; first_bad_seq := r.chain_seq;
            reason_code := 'ALTERED';
            reason := 'this row no longer matches its own hash';
            first_bad_title := r.title;
            first_bad_occurred := r.occurred_at;
            anchor_seq := v_anchor;
            RETURN NEXT; RETURN;
        END IF;

        v_prev := r.row_hash;
        v_prev_seq := r.chain_seq;
    END LOOP;

    checked := v_checked;
    first_bad_id := NULL; first_bad_seq := NULL; reason := NULL;
    anchor_seq := v_anchor;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
