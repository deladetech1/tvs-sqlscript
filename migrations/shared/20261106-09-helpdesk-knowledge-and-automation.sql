-- Help Desk R2: the knowledge base and automation rules.
--
--   hd_kb_categories     knowledge base categories, business-wide or per department
--   hd_articles          an article: audience, state, the published title and body (searched), its
--                        review and expiry dates, counters and tags
--   hd_article_versions  drafts, reviews and publications. Once a version is published its title
--                        and body never change; it may only move to superseded (its own trigger)
--   hd_article_feedback  one helpful / not helpful per user and article
--   hd_ticket_articles   articles suggested for, used on, or resolving a ticket
--   hd_automation_rules  trigger, conditions and actions, versioned, with run counters
--   hd_automation_runs   append-only: one run per rule and triggering event (the dedupe key), with
--                        its depth for the loop guard
--
-- CHECK lists are defined here, inline; a later change goes in a newer file. No grants.
-- Design: tvs-shared-apps-bk docs/helpdesk/contracts/R2.md §3. Idempotent; safe to re-run.

BEGIN;

-- ======================================================================== categories
CREATE TABLE IF NOT EXISTS helpdesk.hd_kb_categories (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    department_id  text REFERENCES helpdesk.hd_departments (id),
    parent_id      text REFERENCES helpdesk.hd_kb_categories (id),
    name           text NOT NULL,
    position       int NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text,
    CONSTRAINT hd_kb_categories_not_own_parent CHECK (parent_id IS DISTINCT FROM id)
);
CREATE INDEX IF NOT EXISTS hd_kb_categories_business_idx ON helpdesk.hd_kb_categories (tenant_id, bus_id, position);

-- ========================================================================== articles
CREATE TABLE IF NOT EXISTS helpdesk.hd_articles (
    id                  text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id           text NOT NULL,
    bus_id              text NOT NULL,
    category_id         text REFERENCES helpdesk.hd_kb_categories (id),
    department_id       text REFERENCES helpdesk.hd_departments (id),
    slug                text NOT NULL,
    owner_user_id       text,
    audience            text NOT NULL DEFAULT 'internal'
                        CONSTRAINT hd_articles_audience_check CHECK (audience IN ('internal', 'employees', 'public')),
    state               text NOT NULL DEFAULT 'draft'
                        CONSTRAINT hd_articles_state_check CHECK (state IN ('draft', 'in_review', 'published', 'archived')),
    current_version_id  text,
    published_title     text,
    published_body      text,
    review_due_on       date,
    expires_on          date,
    view_count          int NOT NULL DEFAULT 0,
    helpful_count       int NOT NULL DEFAULT 0,
    not_helpful_count   int NOT NULL DEFAULT 0,
    tags                text[] NOT NULL DEFAULT '{}',
    search              tsvector GENERATED ALWAYS AS (to_tsvector('simple',
                            coalesce(published_title, '') || ' ' || coalesce(published_body, ''))) STORED,
    cdatetime           timestamptz NOT NULL DEFAULT now(),
    created_by          text,
    updated_at          timestamptz,
    updated_by          text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_articles_slug_uq ON helpdesk.hd_articles (tenant_id, bus_id, slug);
CREATE INDEX IF NOT EXISTS hd_articles_search_idx ON helpdesk.hd_articles USING gin (search);
CREATE INDEX IF NOT EXISTS hd_articles_tags_idx ON helpdesk.hd_articles USING gin (tags);
CREATE INDEX IF NOT EXISTS hd_articles_business_idx ON helpdesk.hd_articles (tenant_id, bus_id, state, audience);

CREATE TABLE IF NOT EXISTS helpdesk.hd_article_versions (
    id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id       text NOT NULL,
    bus_id          text NOT NULL,
    article_id      text NOT NULL REFERENCES helpdesk.hd_articles (id),
    version         int NOT NULL CONSTRAINT hd_article_versions_version_check CHECK (version >= 1),
    title           text NOT NULL,
    body            text NOT NULL,
    state           text NOT NULL DEFAULT 'draft'
                    CONSTRAINT hd_article_versions_state_check CHECK (state IN ('draft', 'in_review', 'published', 'rejected', 'superseded')),
    submitted_at    timestamptz,
    reviewed_by     text,
    reviewed_at     timestamptz,
    review_comment  text,
    published_at    timestamptz,
    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    updated_at      timestamptz,
    updated_by      text
);
CREATE UNIQUE INDEX IF NOT EXISTS hd_article_versions_version_uq ON helpdesk.hd_article_versions (article_id, version);

-- Once published_at is set, what was published stays as published: title, body, the article,
-- the version number and published_at never change, and the state may only move to superseded.
-- A published version is deleted only by the unsubscribe purge. Drafts change freely.
CREATE OR REPLACE FUNCTION helpdesk.hd_article_versions_published_guard() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF OLD.published_at IS NULL THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;
    IF TG_OP = 'DELETE' THEN
        IF helpdesk.hd_purge_allowed(OLD.tenant_id, OLD.bus_id) THEN
            RETURN OLD;
        END IF;
        RAISE EXCEPTION 'hd_article_versions: a published version cannot be deleted'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    IF row(NEW.id, NEW.tenant_id, NEW.bus_id, NEW.article_id, NEW.version, NEW.title, NEW.body, NEW.published_at)
       IS DISTINCT FROM
       row(OLD.id, OLD.tenant_id, OLD.bus_id, OLD.article_id, OLD.version, OLD.title, OLD.body, OLD.published_at) THEN
        RAISE EXCEPTION 'hd_article_versions: a published version cannot change; write a new version instead'
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    IF NEW.state IS DISTINCT FROM OLD.state AND NEW.state <> 'superseded' THEN
        RAISE EXCEPTION 'hd_article_versions: a published version may only become superseded, not %', NEW.state
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NEW;
END
$f$;
DROP TRIGGER IF EXISTS hd_article_versions_published_guard ON helpdesk.hd_article_versions;
CREATE TRIGGER hd_article_versions_published_guard BEFORE UPDATE OR DELETE ON helpdesk.hd_article_versions
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_article_versions_published_guard();

ALTER TABLE helpdesk.hd_articles DROP CONSTRAINT IF EXISTS hd_articles_current_version_fk;
ALTER TABLE helpdesk.hd_articles ADD CONSTRAINT hd_articles_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES helpdesk.hd_article_versions (id);

CREATE TABLE IF NOT EXISTS helpdesk.hd_article_feedback (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    article_id  text NOT NULL REFERENCES helpdesk.hd_articles (id),
    user_id     text NOT NULL,
    helpful     boolean NOT NULL,
    comment     text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (article_id, user_id)
);

CREATE TABLE IF NOT EXISTS helpdesk.hd_ticket_articles (
    tenant_id   text NOT NULL,
    bus_id      text NOT NULL,
    ticket_id   text NOT NULL REFERENCES helpdesk.hd_tickets (id),
    article_id  text NOT NULL REFERENCES helpdesk.hd_articles (id),
    kind        text NOT NULL CONSTRAINT hd_ticket_articles_kind_check CHECK (kind IN ('suggested', 'used', 'resolution')),
    linked_by   text,
    cdatetime   timestamptz NOT NULL DEFAULT now(),
    created_by  text,
    updated_at  timestamptz,
    updated_by  text,
    PRIMARY KEY (ticket_id, article_id, kind)
);
CREATE INDEX IF NOT EXISTS hd_ticket_articles_article_idx ON helpdesk.hd_ticket_articles (article_id);

-- ======================================================================== automation
CREATE TABLE IF NOT EXISTS helpdesk.hd_automation_rules (
    id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id      text NOT NULL,
    bus_id         text NOT NULL,
    name           text NOT NULL,
    department_id  text REFERENCES helpdesk.hd_departments (id),
    trigger        text NOT NULL
                   CONSTRAINT hd_automation_rules_trigger_check CHECK (trigger IN ('ticket_created', 'ticket_updated', 'status_changed',
                       'replied', 'sla_warning', 'sla_breach', 'fulfilment_complete', 'approval_decided', 'idle')),
    idle_minutes   int CONSTRAINT hd_automation_rules_idle_minutes_check CHECK (idle_minutes > 0),
    conditions     jsonb NOT NULL DEFAULT '[]',
    actions        jsonb NOT NULL,
    position       int NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true,
    version        int NOT NULL DEFAULT 1,
    run_count      int NOT NULL DEFAULT 0,
    last_run_at    timestamptz,
    cdatetime      timestamptz NOT NULL DEFAULT now(),
    created_by     text,
    updated_at     timestamptz,
    updated_by     text,
    -- An idle rule says how long is idle.
    CONSTRAINT hd_automation_rules_idle_check CHECK (trigger <> 'idle' OR idle_minutes IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS hd_automation_rules_trigger_idx
    ON helpdesk.hd_automation_rules (tenant_id, bus_id, trigger, position) WHERE is_active;

CREATE TABLE IF NOT EXISTS helpdesk.hd_automation_runs (
    id                text PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tenant_id         text NOT NULL,
    bus_id            text NOT NULL,
    rule_id           text NOT NULL REFERENCES helpdesk.hd_automation_rules (id),
    rule_version      int NOT NULL,
    ticket_id         text REFERENCES helpdesk.hd_tickets (id),
    trigger_event_id  text NOT NULL,
    depth             int NOT NULL DEFAULT 0 CONSTRAINT hd_automation_runs_depth_check CHECK (depth >= 0),
    status            text NOT NULL CONSTRAINT hd_automation_runs_status_check CHECK (status IN ('ok', 'skipped', 'failed')),
    actions_done      jsonb NOT NULL DEFAULT '[]',
    error             text,
    cdatetime         timestamptz NOT NULL DEFAULT now(),
    created_by        text,
    updated_at        timestamptz,
    updated_by        text
);
-- The dedupe key: a rule runs at most once per triggering event.
CREATE UNIQUE INDEX IF NOT EXISTS hd_automation_runs_dedupe_uq ON helpdesk.hd_automation_runs (rule_id, trigger_event_id);
CREATE INDEX IF NOT EXISTS hd_automation_runs_ticket_idx ON helpdesk.hd_automation_runs (tenant_id, bus_id, ticket_id, cdatetime DESC);
DROP TRIGGER IF EXISTS hd_automation_runs_append_only ON helpdesk.hd_automation_runs;
CREATE TRIGGER hd_automation_runs_append_only BEFORE UPDATE OR DELETE ON helpdesk.hd_automation_runs
    FOR EACH ROW EXECUTE FUNCTION helpdesk.hd_refuse_change();

-- ===================================================================== invariants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_automation_runs'::regclass AND p.proname = 'hd_refuse_change'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_automation_runs is not append-only: its hd_refuse_change trigger on UPDATE and DELETE is missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_proc p ON p.oid = g.tgfoid
                    WHERE g.tgrelid = 'helpdesk.hd_article_versions'::regclass AND p.proname = 'hd_article_versions_published_guard'
                      AND NOT g.tgisinternal AND (g.tgtype & 8) <> 0 AND (g.tgtype & 16) <> 0) THEN
        RAISE EXCEPTION 'helpdesk.hd_article_versions has no published-version guard on UPDATE and DELETE';
    END IF;
    IF to_regclass('helpdesk.hd_automation_runs_dedupe_uq') IS NULL THEN
        RAISE EXCEPTION 'hd_automation_runs has no dedupe key on (rule_id, trigger_event_id)';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_articles a JOIN helpdesk.hd_kb_categories c ON c.id = a.category_id
                WHERE c.tenant_id <> a.tenant_id OR c.bus_id <> a.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk article is filed in a category of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_articles a JOIN helpdesk.hd_article_versions v ON v.id = a.current_version_id
                WHERE v.article_id <> a.id) THEN
        RAISE EXCEPTION 'a Help Desk article points at a version of another article';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_article_versions v JOIN helpdesk.hd_articles a ON a.id = v.article_id
                WHERE a.tenant_id <> v.tenant_id OR a.bus_id <> v.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk article version belongs to an article of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_ticket_articles l
                 JOIN helpdesk.hd_tickets t ON t.id = l.ticket_id
                 JOIN helpdesk.hd_articles a ON a.id = l.article_id
                WHERE t.tenant_id <> l.tenant_id OR t.bus_id <> l.bus_id OR a.tenant_id <> l.tenant_id OR a.bus_id <> l.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk ticket is linked to an article of another business';
    END IF;
    IF EXISTS (SELECT 1 FROM helpdesk.hd_automation_runs r JOIN helpdesk.hd_automation_rules u ON u.id = r.rule_id
                WHERE u.tenant_id <> r.tenant_id OR u.bus_id <> r.bus_id) THEN
        RAISE EXCEPTION 'a Help Desk automation run belongs to a rule of another business';
    END IF;
END $$;

COMMIT;
