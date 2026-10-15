-- CRM: MyStoreGuard prices exactly as MyStoreGuard works them out.
--
-- 20261015-03 read a product's price from its GLOBAL price row only. Most businesses have
-- none: their price is the base selling price on the product's latest delivery (batch),
-- which MyStoreGuard falls back to. Every such product reached the CRM at 0. Nor did it
-- apply pricing rules or tax.
--
-- crm.msg_product_price(tenant, business, product, quantity, at) is MyStoreGuard's own
-- calculation, as its product screen and till do it (tvs-mystoreguard-bk:
-- utils/pricing_calculator.calculate_all_prices -> product_price_calculator, with the
-- checkout's rule engine sales_price_calculator.apply_pricing_rules, and rule_targets):
--
--   1. The price: the best STORE price row -- a "stops other prices" row first, then
--      SKU > TAG/CATEGORY/BRAND/LABEL > GLOBAL, higher priority first -- else the latest
--      batch's base selling price, else 0. (No branch: the CRM prices for the business.)
--   2. One pricing rule: the most specific active STORE rule in its date window --
--      UNIT > BATCH > SKU > PRODUCT > TAG/LABEL/CATEGORY/BRAND > LOCATION > ALL_PRODUCTS,
--      then priority, then newest -- skipping quantity rules whose range does not hold the
--      quantity. Fixed price, amount or percentage off, amount or percentage markup, or a
--      quantity break.
--   3. Every tax rule that targets the product, each with its tax's rate and whether the
--      price already includes it; a rule's conditions (item price, line total, quantity)
--      can exempt the line or reduce the tax. Inclusive taxes are taken out of the price
--      together; exclusive taxes are added to it.
--   4. The currency: the latest batch's.
--
-- The quantity matters: a quantity break, and a tax condition on quantity or the line
-- total, change the price of a line of 20 from a line of 1. The CRM prices each quote
-- line at its own quantity.
--
-- Parity with the Python is tested by running both on the same database
-- (tvs-shared-apps-bk: internal/apps/crm/testdata/msg_price_parity.py).
--
-- SECURITY DEFINER, like the views 20261015-02 reads through: the CRM's login needs no
-- grant on MyStoreGuard's tables, and the contract is this function's columns.
--
-- Idempotent; safe to re-run on every deploy.

BEGIN;

-- ------------------------------------------------------------------ CRM columns
-- A product's price as MyStoreGuard reports it, and how its tax works.
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS list_price     numeric(18,2);
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS price_rule     text;
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS tax_inclusive  boolean NOT NULL DEFAULT false;
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS tax_names      text;
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS final_price    numeric(18,2);
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS has_price      boolean NOT NULL DEFAULT true;
ALTER TABLE crm.crm_products ADD COLUMN IF NOT EXISTS priced_at      timestamptz;
-- An effective rate (several taxes, a reduction) needs more than three decimals to come
-- back to the same cedi on a large order.
ALTER TABLE crm.crm_products   ALTER COLUMN tax_rate TYPE numeric(12,6);
ALTER TABLE crm.crm_deal_lines  ALTER COLUMN tax_rate TYPE numeric(12,6);
ALTER TABLE crm.crm_quote_lines ALTER COLUMN tax_rate TYPE numeric(12,6);
ALTER TABLE crm.crm_deal_lines  ADD COLUMN IF NOT EXISTS tax_inclusive boolean NOT NULL DEFAULT false;
ALTER TABLE crm.crm_quote_lines ADD COLUMN IF NOT EXISTS tax_inclusive boolean NOT NULL DEFAULT false;
ALTER TABLE crm.crm_deal_lines  ADD COLUMN IF NOT EXISTS price_note text;
ALTER TABLE crm.crm_quote_lines ADD COLUMN IF NOT EXISTS price_note text;
-- Tax already inside inclusive prices, shown on a quote as "includes".
ALTER TABLE crm.crm_quotes ADD COLUMN IF NOT EXISTS tax_included numeric(18,2) NOT NULL DEFAULT 0;

-- ------------------------------------------------------------- the calculation
DO $$
BEGIN
    IF to_regclass('mystoreguard.msg_products') IS NULL
       OR to_regclass('mystoreguard.msg_product_prices') IS NULL
       OR to_regclass('mystoreguard.msg_purchase_batches') IS NULL
       OR to_regclass('mystoreguard.msg_pricing_rule') IS NULL
       OR to_regclass('mystoreguard.msg_tax_rule') IS NULL
       OR to_regclass('mystoreguard.msg_taxes') IS NULL
       OR to_regclass('mystoreguard.tax_rule_conditions') IS NULL THEN
        RETURN; -- no MyStoreGuard in this database: nothing to price from
    END IF;

    EXECUTE $fn$
    CREATE OR REPLACE FUNCTION crm.msg_product_price(
        p_tenant  text,
        p_bus     text,
        p_product text,
        p_qty     numeric     DEFAULT 1,
        p_at      timestamptz DEFAULT now()
    ) RETURNS TABLE (
        has_price     boolean,  -- a price row or a batch price exists
        list_price    numeric,  -- step 1
        selling_price numeric,  -- step 2: what the till charges before tax
        rule_name     text,
        rule_type     text,
        tax_included  numeric,  -- tax inside the selling price (inclusive taxes)
        tax_added     numeric,  -- tax on top of it (exclusive taxes)
        tax_amount    numeric,  -- both
        tax_names     text,
        final_price   numeric,  -- what the customer pays for one
        currency_id   text
    )
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $body$
    DECLARE
        v_org text; v_sku text;
        v_cat text[]; v_tag text[]; v_brand text[]; v_label text[];
        v_base numeric; v_currency text;
        v_actual numeric; v_found boolean := false;
        v_price numeric; v_rule record;
        v_tax record; v_cond record;
        v_conds jsonb; v_i int; v_n int; v_met boolean; v_final boolean; v_prev_op text;
        v_apply boolean; v_red numeric; v_red_pct numeric; v_val numeric;
        v_taxes jsonb := '[]'::jsonb;
        v_incl_rate numeric := 0; v_pre numeric; v_amt numeric;
        v_total numeric := 0; v_incl numeric := 0; v_excl numeric := 0; v_current numeric;
        v_names text[] := ARRAY[]::text[];
        v_item jsonb;
    BEGIN
        SELECT p.org_id, NULLIF(p.sku, '') INTO v_org, v_sku
          FROM mystoreguard.msg_products p
         WHERE p.id = p_product AND p.tenant_id = p_tenant AND p.bus_id = p_bus;
        IF NOT FOUND THEN
            RETURN;
        END IF;

        -- The groups the product belongs to (category, tag, brand, label).
        SELECT array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'CATEGORY'),
               array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'TAG'),
               array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'BRAND'),
               array_agg(pm.id) FILTER (WHERE upper(pm.of_type) = 'LABEL')
          INTO v_cat, v_tag, v_brand, v_label
          FROM mystoreguard.msg_assign_metadata_to_products amp
          JOIN mystoreguard.msg_product_metadata pm
            ON pm.id = amp.product_metadata_id AND pm.tenant_id = amp.tenant_id
           AND pm.org_id = amp.org_id AND pm.bus_id = amp.bus_id
         WHERE amp.tenant_id = p_tenant AND amp.org_id = v_org AND amp.bus_id = p_bus
           AND amp.product_id = p_product AND pm.delete_status = 'NOT_DELETED';

        -- The latest delivery: its base selling price is the fallback, its currency the currency.
        SELECT b.base_selling_price, b.currency_id INTO v_base, v_currency
          FROM mystoreguard.msg_purchase_batches b
         WHERE b.product_id = p_product AND b.tenant_id = p_tenant AND b.org_id = v_org AND b.bus_id = p_bus
           AND b.delete_status = 'NOT_DELETED'
         ORDER BY b.cdatetime DESC
         LIMIT 1;

        -- 1. The price.
        SELECT x.price INTO v_actual
          FROM mystoreguard.msg_product_prices x
         WHERE x.product_id = p_product AND x.tenant_id = p_tenant AND x.org_id = v_org AND x.bus_id = p_bus
           AND x.channel = 'STORE' AND (x.deleted_by IS NULL OR x.deleted_by = '')
           AND (   x.of_type = 'GLOBAL'
                OR (x.of_type = 'SKU' AND x.target_id = v_sku)
                OR (x.of_type = 'CATEGORY' AND x.target_id = ANY(v_cat))
                OR (x.of_type = 'TAG' AND x.target_id = ANY(v_tag))
                OR (x.of_type = 'BRAND' AND x.target_id = ANY(v_brand))
                OR (x.of_type = 'LABEL' AND x.target_id = ANY(v_label)))
         ORDER BY coalesce(x.stops_other_prices, false) DESC,
                  CASE x.of_type WHEN 'SKU' THEN 1 WHEN 'LOCATION' THEN 2
                       WHEN 'TAG' THEN 3 WHEN 'CATEGORY' THEN 3 WHEN 'BRAND' THEN 3 WHEN 'LABEL' THEN 3
                       WHEN 'GLOBAL' THEN 4 END,
                  x.priority DESC
         LIMIT 1;
        v_found := FOUND;
        IF v_found THEN
            v_actual := round(v_actual, 2);
        ELSIF v_base IS NOT NULL THEN
            v_actual := round(v_base, 2);
        ELSE
            v_actual := 0;
        END IF;
        has_price := v_found OR v_base IS NOT NULL;
        list_price := v_actual;
        currency_id := v_currency;

        -- 2. One pricing rule.
        v_price := v_actual;
        FOR v_rule IN
            SELECT r.name, r.rule_type, r.rule_category, r.quantity_min, r.quantity_max, r.discount_value, r.discount_percent
              FROM mystoreguard.msg_pricing_rule r
             WHERE r.tenant_id = p_tenant AND r.org_id = v_org AND r.bus_id = p_bus
               AND r.channel = 'STORE' AND r.is_active = TRUE
               AND (r.start_datetime IS NULL OR r.start_datetime <= p_at)
               AND (r.end_datetime IS NULL OR r.end_datetime >= p_at)
               AND (   r.rule_target_type = 'ALL_PRODUCTS'
                    OR (r.rule_target_type = 'SKU' AND r.rule_target_id = v_sku)
                    OR (r.rule_target_type = 'PRODUCT' AND r.rule_target_id = p_product)
                    OR (r.rule_target_type = 'CATEGORY' AND r.rule_target_id = ANY(v_cat))
                    OR (r.rule_target_type = 'TAG' AND r.rule_target_id = ANY(v_tag))
                    OR (r.rule_target_type = 'BRAND' AND r.rule_target_id = ANY(v_brand))
                    OR (r.rule_target_type = 'LABEL' AND r.rule_target_id = ANY(v_label)))
             ORDER BY CASE r.rule_target_type WHEN 'UNIT' THEN 1 WHEN 'BATCH' THEN 2 WHEN 'SKU' THEN 3 WHEN 'PRODUCT' THEN 4
                           WHEN 'TAG' THEN 5 WHEN 'LABEL' THEN 5 WHEN 'CATEGORY' THEN 5 WHEN 'BRAND' THEN 5
                           WHEN 'LOCATION' THEN 6 WHEN 'ALL_PRODUCTS' THEN 7 ELSE 99 END,
                      r.priority DESC, r.cdatetime DESC
        LOOP
            IF v_rule.rule_category = 'QUANTITY_BASED'
               AND ((v_rule.quantity_min IS NOT NULL AND p_qty < v_rule.quantity_min)
                 OR (v_rule.quantity_max IS NOT NULL AND p_qty > v_rule.quantity_max)) THEN
                CONTINUE;
            END IF;
            -- A rule missing the number it needs: MyStoreGuard's calculation fails on it and
            -- keeps the price as it was, with no rule applied. So does this.
            IF (v_rule.rule_type IN ('FIXED_PRICE', 'FIXED_AMOUNT', 'PRICE_DISCOUNT', 'PRICE_MARKUP') AND v_rule.discount_value IS NULL)
               OR (v_rule.rule_type IN ('PERCENTAGE_DISCOUNT', 'PERCENTAGE_MARKUP') AND v_rule.discount_percent IS NULL) THEN
                EXIT;
            END IF;
            rule_name := v_rule.name;
            rule_type := v_rule.rule_type;
            CASE v_rule.rule_type
                WHEN 'FIXED_PRICE', 'FIXED_AMOUNT' THEN v_price := greatest(0, v_rule.discount_value);
                WHEN 'PRICE_DISCOUNT' THEN v_price := greatest(0, v_price - v_rule.discount_value);
                WHEN 'PERCENTAGE_DISCOUNT' THEN v_price := greatest(0, v_price - v_price * v_rule.discount_percent / 100);
                WHEN 'PRICE_MARKUP' THEN v_price := v_price + v_rule.discount_value;
                WHEN 'PERCENTAGE_MARKUP' THEN v_price := v_price + v_price * v_rule.discount_percent / 100;
                WHEN 'QUANTITY_BREAK' THEN
                    IF v_rule.discount_value IS NOT NULL THEN
                        v_price := greatest(0, v_price - v_rule.discount_value);
                    ELSIF v_rule.discount_percent IS NOT NULL THEN
                        v_price := greatest(0, v_price - v_price * v_rule.discount_percent / 100);
                    END IF;
                ELSE NULL;
            END CASE;
            EXIT; -- only the first applicable rule
        END LOOP;
        v_price := greatest(0, round(v_price, 2));
        selling_price := v_price;

        -- 3. Every tax that targets the product, with its conditions.
        FOR v_tax IN
            SELECT r.id AS rule_id, t.name AS tax_name, t.rate, coalesce(t.is_inclusive, false) AS inclusive
              FROM mystoreguard.msg_tax_rule r
              JOIN mystoreguard.msg_taxes t
                ON t.id = r.tax_id AND t.tenant_id = r.tenant_id AND t.org_id = r.org_id AND t.bus_id = r.bus_id
             WHERE r.tenant_id = p_tenant AND r.org_id = v_org AND r.bus_id = p_bus
               AND r.is_active = TRUE AND t.is_active = TRUE
               AND (   r.rule_type = 'ALL_PRODUCTS'
                    OR (r.rule_type = 'SKU' AND r.rule_target_id = v_sku)
                    OR (r.rule_type = 'PRODUCT' AND r.rule_target_id = p_product)
                    OR (r.rule_type = 'CATEGORY' AND r.rule_target_id = ANY(v_cat))
                    OR (r.rule_type = 'TAG' AND r.rule_target_id = ANY(v_tag))
                    OR (r.rule_type = 'BRAND' AND r.rule_target_id = ANY(v_brand))
                    OR (r.rule_type = 'LABEL' AND r.rule_target_id = ANY(v_label)))
             ORDER BY CASE r.rule_type WHEN 'UNIT' THEN 1 WHEN 'BATCH' THEN 2 WHEN 'SKU' THEN 3 WHEN 'PRODUCT' THEN 4
                           WHEN 'TAG' THEN 5 WHEN 'LABEL' THEN 5 WHEN 'CATEGORY' THEN 5 WHEN 'BRAND' THEN 5
                           WHEN 'LOCATION' THEN 6 WHEN 'ALL_PRODUCTS' THEN 7 ELSE 99 END,
                      r.priority DESC
        LOOP
            -- Conditions only ever relieve tax. They are chained with the operator on the
            -- condition BEFORE each one ('AND'; anything else, NULL included, is OR).
            v_apply := true; v_red := 0; v_red_pct := 0;
            SELECT coalesce(jsonb_agg(jsonb_build_object(
                        'met', CASE c.comparison_operator
                                 WHEN 'EQUALS' THEN cv.v = c.comparison_value
                                 WHEN 'NOT_EQUALS' THEN cv.v <> c.comparison_value
                                 WHEN 'GREATER_THAN' THEN cv.v > c.comparison_value
                                 WHEN 'LESS_THAN' THEN cv.v < c.comparison_value
                                 WHEN 'GREATER_THAN_OR_EQUALS' THEN cv.v >= c.comparison_value
                                 WHEN 'LESS_THAN_OR_EQUALS' THEN cv.v <= c.comparison_value
                                 ELSE false END,
                        'type', c.condition_type, 'op', c.logical_operator,
                        'value', c.adjustment_value, 'pct', c.adjustment_percentage)
                    ORDER BY c.priority ASC), '[]'::jsonb)
              INTO v_conds
              FROM mystoreguard.tax_rule_conditions c
              CROSS JOIN LATERAL (SELECT CASE c.condition
                                    WHEN 'IF_ITEM_PRICE' THEN v_price
                                    WHEN 'IF_TOTAL_PRICE' THEN v_price * p_qty
                                    WHEN 'IF_ITEM_QTY' THEN p_qty END AS v) cv
             WHERE c.tax_rule_id = v_tax.rule_id AND c.tenant_id = p_tenant AND c.org_id = v_org AND c.bus_id = p_bus
               AND cv.v IS NOT NULL;
            -- A condition with no comparison value breaks MyStoreGuard's whole tax step: it then
            -- shows the price with no tax at all. Faithfully the same here.
            IF EXISTS (SELECT 1 FROM mystoreguard.tax_rule_conditions c
                        WHERE c.tax_rule_id = v_tax.rule_id AND c.tenant_id = p_tenant AND c.org_id = v_org AND c.bus_id = p_bus
                          AND c.comparison_value IS NULL) THEN
                v_taxes := '[]'::jsonb; v_incl_rate := 0;
                EXIT;
            END IF;
            v_n := jsonb_array_length(v_conds);
            IF v_n > 0 THEN
                v_final := (v_conds -> 0 ->> 'met')::boolean;
                FOR v_i IN 1 .. v_n - 1 LOOP
                    v_prev_op := v_conds -> (v_i - 1) ->> 'op';
                    v_met := (v_conds -> v_i ->> 'met')::boolean;
                    IF v_prev_op = 'AND' THEN v_final := v_final AND v_met; ELSE v_final := v_final OR v_met; END IF;
                END LOOP;
                IF v_final THEN
                    FOR v_item IN SELECT * FROM jsonb_array_elements(v_conds) LOOP
                        CONTINUE WHEN NOT (v_item ->> 'met')::boolean;
                        IF v_item ->> 'type' = 'TAX_EXEMPTION' THEN
                            v_apply := false;
                            EXIT;
                        ELSIF v_item ->> 'type' = 'TAX_REDUCTION' THEN
                            v_val := NULLIF(v_item ->> 'value', '')::numeric;
                            IF v_val IS NOT NULL AND v_val <> 0 THEN
                                v_red := v_red + v_val;
                            ELSE
                                v_val := NULLIF(v_item ->> 'pct', '')::numeric;
                                IF v_val IS NOT NULL AND v_val <> 0 THEN
                                    v_red_pct := v_red_pct + v_val;
                                END IF;
                            END IF;
                        END IF;
                    END LOOP;
                END IF;
            END IF;
            CONTINUE WHEN NOT v_apply;
            v_taxes := v_taxes || jsonb_build_object('name', v_tax.tax_name, 'rate', v_tax.rate, 'inclusive', v_tax.inclusive,
                                                     'red', v_red, 'red_pct', v_red_pct);
            IF v_tax.inclusive THEN
                v_incl_rate := v_incl_rate + v_tax.rate;
            END IF;
        END LOOP;

        IF v_incl_rate > 0 THEN
            v_pre := v_price / (1 + v_incl_rate / 100);
        ELSE
            v_pre := v_price;
        END IF;
        v_current := v_price;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_taxes) LOOP
            IF (v_item ->> 'inclusive')::boolean THEN
                v_amt := v_pre * (v_item ->> 'rate')::numeric / 100;
            ELSE
                v_amt := v_price * (v_item ->> 'rate')::numeric / 100;
            END IF;
            IF (v_item ->> 'red_pct')::numeric > 0 THEN
                v_amt := v_amt * (100 - (v_item ->> 'red_pct')::numeric) / 100;
            END IF;
            v_amt := greatest(0, v_amt - (v_item ->> 'red')::numeric);
            v_total := v_total + v_amt;
            IF (v_item ->> 'inclusive')::boolean THEN
                v_incl := v_incl + v_amt;
            ELSE
                v_excl := v_excl + v_amt;
                v_current := v_current + v_amt;
            END IF;
            IF v_amt > 0 THEN
                v_names := v_names || ((v_item ->> 'name') || ' ' ||
                           CASE WHEN (v_item ->> 'rate') LIKE '%.%'
                                THEN rtrim(rtrim(v_item ->> 'rate', '0'), '.') ELSE v_item ->> 'rate' END
                           || '%' || CASE WHEN (v_item ->> 'inclusive')::boolean THEN ' (included)' ELSE '' END)::text;
            END IF;
        END LOOP;
        tax_included := round(v_incl, 2);
        tax_added := round(v_excl, 2);
        tax_amount := round(v_total, 2);
        tax_names := NULLIF(array_to_string(v_names, ', '), '');
        final_price := round(greatest(0, v_current), 2);
        RETURN NEXT;
    END;
    $body$
    $fn$;

END $$;

COMMIT;
