-- =====================================================================================
-- Remember which alerts a person has already dealt with.
--
-- The bell computes everything live from the tables that already hold the answer -- there
-- is no notifications table and deliberately so, because an alert is a state, not a
-- message: an account is locked or it is not. That leaves nowhere to record "I have seen
-- this", which is what this table is for, and nothing more.
--
-- Read state is PER PERSON, not per tenant. One admin dismissing a locked account must not
-- take it off everybody else's list -- the lock is still there, and the next person to look
-- should be told about it. That is why user_id is part of the key.
--
-- alert_key identifies the underlying thing, not the rendering of it: a security event's id,
-- a credential's id, a webhook plus the moment it started failing, a user plus the moment
-- they were locked out. So a webhook that recovers and fails again, or an account locked a
-- second time, comes back as something new rather than staying hidden behind a key that was
-- marked read a month ago. The provider decides its own key; this table only stores it.
--
-- Nothing here is authoritative: losing every row shows everybody every outstanding alert
-- again, which is annoying and safe. The opposite -- an alert hidden that should not be --
-- is the failure worth avoiding, and is why marking read never deletes or resolves anything.
--
-- Safe to rerun.
-- =====================================================================================

CREATE TABLE IF NOT EXISTS core_platform.cp_alert_reads (
    tenant_id   text        NOT NULL,
    user_id     text        NOT NULL,
    alert_key   text        NOT NULL,

    cdate       text,
    ctime       text,
    cdatetime   timestamptz,
    created_by  text,

    CONSTRAINT pk_cp_alert_reads PRIMARY KEY (tenant_id, user_id, alert_key)
);

-- The only read path: every key this person has marked, for one tenant. The primary key
-- already serves it; named here so the intent survives a future change to the key.
CREATE INDEX IF NOT EXISTS ix_cp_alert_reads_tenant_user
    ON core_platform.cp_alert_reads (tenant_id, user_id);

-- Rows outlive the alert they refer to -- the event is resolved, the key is never asked
-- about again, and the row sits there. They are tiny and harmless, but not free forever,
-- so they are purged on the same schedule as the audit tables.
CREATE INDEX IF NOT EXISTS ix_cp_alert_reads_cdatetime
    ON core_platform.cp_alert_reads (cdatetime);
