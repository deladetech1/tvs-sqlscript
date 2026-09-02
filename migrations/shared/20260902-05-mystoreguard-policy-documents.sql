-- 20260902-05-mystoreguard-policy-documents.sql
-- The agreement a customer signs when they buy on instalments.
--
-- Every shop's is different, and the shop writes it — we cannot ship one,
-- because the terms are the shop's own trade and, in places, its lawyer's. So
-- this stores a document the shop composes: headings, paragraphs, lists, and
-- placeholders that fill themselves in from the plan it is printed for.
--
-- Two tables, and the split is the whole point.
--
-- msg_policy_templates is what the shop writes and keeps editing. It is a
-- living thing: wording gets fixed, clauses get added.
--
-- msg_issued_policies is what one customer was actually handed. It carries the
-- resolved content, frozen — not a reference to the template. A signed
-- agreement that reads differently next month because somebody edited a clause
-- is not a record of anything, and it is exactly the kind of thing that matters
-- when a plan goes wrong and the two sides disagree about what was agreed. The
-- sale's guarantors are already snapshotted for the same reason.
--
-- Idempotent; safe to re-run on every deploy.


-- =====================================================================================
-- 1. The document the shop writes.
--
--    Content is a JSON array of blocks rather than HTML. A block is one of a
--    small set — heading, paragraph, bullets, numbers, signature, page break —
--    each carrying runs of text with bold/italic/underline. That is enough for
--    an agreement and it is not enough to be dangerous: nothing a shop types
--    can become markup, a script, or a layout the renderer cannot draw.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_policy_templates (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,

    name            text        NOT NULL,
    description     text,

    -- What this document is for. INSTALLMENT is the case that prompted it; the
    -- column exists so a shop can add a cash-sale receipt of terms or a
    -- delivery waiver later without a second table.
    applies_to      text        NOT NULL DEFAULT 'INSTALLMENT',

    blocks          jsonb       NOT NULL DEFAULT '[]'::jsonb,

    -- Blanks the shop invents for itself: a witness's name, a collection
    -- address, a clause it types fresh each time. Declared here as
    -- {key, label, type, required}, written into the document as {{var.key}},
    -- and answered when the document is issued.
    --
    -- Deliberately not custom fields. A custom field is a question about the
    -- customer or the plan, asked once and stored against them; a variable is a
    -- blank on this piece of paper. Storing one against the plan would be
    -- inventing a fact about the plan out of something somebody typed onto a
    -- form.
    variables       jsonb       NOT NULL DEFAULT '[]'::jsonb,

    -- Which document a sale gets when nobody picks one. A shop may keep several
    -- — one per branch's wording, one for high-value plans — but exactly one
    -- can be the default, enforced below.
    is_default      boolean     NOT NULL DEFAULT false,
    is_active       boolean     NOT NULL DEFAULT true,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    udatetime       timestamptz,
    created_by      text,
    updated_by      text,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    deleted_at      timestamptz,
    deleted_by      text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_policy_templates_applies_to') THEN
        ALTER TABLE mystoreguard.msg_policy_templates
            ADD CONSTRAINT ck_msg_policy_templates_applies_to CHECK (
                applies_to IN ('INSTALLMENT', 'SALE')
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_policy_templates_blocks') THEN
        ALTER TABLE mystoreguard.msg_policy_templates
            ADD CONSTRAINT ck_msg_policy_templates_blocks CHECK (
                jsonb_typeof(blocks) = 'array'
                AND jsonb_typeof(variables) = 'array'
            );
    END IF;
END $$;

-- One default per business per kind of document. Two defaults is a coin toss
-- over which agreement a customer signs.
CREATE UNIQUE INDEX IF NOT EXISTS ux_msg_policy_templates_default
    ON mystoreguard.msg_policy_templates (tenant_id, org_id, bus_id, applies_to)
    WHERE is_default = true AND delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_policy_templates_shop
    ON mystoreguard.msg_policy_templates (tenant_id, org_id, bus_id, applies_to)
    WHERE delete_status = 'NOT_DELETED';


-- =====================================================================================
-- 2. What one customer was actually given.
--
--    `content` is the resolved document — the shop's blocks with every
--    placeholder already replaced by the value it had that day. Not a template
--    id and a promise to re-render: re-rendering later would quietly restate
--    the agreement using today's wording and today's figures, and the whole
--    reason a customer signs a piece of paper is that it does not change.
--
--    `document_path` is the stored PDF, so the exact file that was printed can
--    be fetched again rather than regenerated and hoped to match.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS mystoreguard.msg_issued_policies (
    id              text        PRIMARY KEY,
    tenant_id       text        NOT NULL,
    org_id          text        NOT NULL,
    bus_id          text        NOT NULL,
    loc_id          text,

    -- What it was issued against. A sale always; the plan too when there is
    -- one, because an instalment agreement belongs to the plan and the plan is
    -- what somebody looks up when the payments stop.
    sale_id         text        NOT NULL,
    plan_id         text,

    -- Kept for reporting — "which of our agreements is in use" — never for
    -- re-rendering. The template may since have been edited or deleted.
    template_id     text,
    template_name   text        NOT NULL,

    content         jsonb       NOT NULL,
    -- What was typed into the document's own blanks, kept beside the resolved
    -- content so a shop can see what somebody answered without reading it back
    -- out of the prose.
    variable_values jsonb       NOT NULL DEFAULT '{}'::jsonb,
    document_path   text,

    -- Signed and returned. The shop marks this when the paper comes back, and
    -- may attach the scan. Null means issued but not yet signed, which is a
    -- real and common state: printed at the counter, signed at home.
    signed_at       timestamptz,
    signed_document_path text,
    signed_note     text,

    cdatetime       timestamptz NOT NULL DEFAULT now(),
    created_by      text,
    delete_status   text        NOT NULL DEFAULT 'NOT_DELETED',
    deleted_at      timestamptz,
    deleted_by      text
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_msg_issued_policies_content') THEN
        ALTER TABLE mystoreguard.msg_issued_policies
            ADD CONSTRAINT ck_msg_issued_policies_content CHECK (
                jsonb_typeof(content) = 'array'
            );
    END IF;
END $$;

-- "What did this customer sign", from the sale and from the plan. Both are
-- asked: the counter works in sales, collections works in plans.
CREATE INDEX IF NOT EXISTS ix_msg_issued_policies_sale
    ON mystoreguard.msg_issued_policies (tenant_id, sale_id, cdatetime DESC)
    WHERE delete_status = 'NOT_DELETED';

CREATE INDEX IF NOT EXISTS ix_msg_issued_policies_plan
    ON mystoreguard.msg_issued_policies (tenant_id, plan_id, cdatetime DESC)
    WHERE plan_id IS NOT NULL AND delete_status = 'NOT_DELETED';

-- Outstanding paperwork: issued, never signed. The list a shop chases.
CREATE INDEX IF NOT EXISTS ix_msg_issued_policies_unsigned
    ON mystoreguard.msg_issued_policies (tenant_id, org_id, bus_id, cdatetime DESC)
    WHERE signed_at IS NULL AND delete_status = 'NOT_DELETED';
