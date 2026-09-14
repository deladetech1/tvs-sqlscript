-- Changing how much a delivery holds is not the same right as editing it.
--
-- ProductsService.adjust_batch_quantity lets a shop take more in on a delivery
-- already recorded — two more pairs found in the same bale — instead of raising
-- a second delivery for the same arrival. That is an everyday correction, and
-- without it a product topped up a few times grows six batches at one price for
-- the till to ask a cashier to choose between.
--
-- But it MAKES STOCK EXIST. Editing a delivery changes what was written down
-- about it: its supplier, its description, its photographs. This changes what
-- the business owns, and the money follows the quantity. Folding it into
-- Products Update would mean anybody who can fix a typo in a description can
-- also add fifty phones to the shelf.
--
-- Held apart for the same reason as Products Move Batch, and granted the same
-- way: inserting the permission fires the trigger that gives it to the roles
-- that hold the rest of the product set, so an owner who wants to withhold it
-- takes it away rather than having to know to grant it.

INSERT INTO core_platform.cp_permissions
    (id, permission_name, description, resource_type_id,
     delete_status, is_active, cdate, ctime, cdatetime)
VALUES
    ('permission-msg-products-adjust-delivery',
     'Mystoreguard Products Adjust Delivery',
     'Can change how much a delivery already recorded holds — take more in on '
     'it, or correct it down. Held apart from Products Update because it makes '
     'stock exist rather than correcting what was written about it',
     'rt-product',
     'NOT_DELETED', true,
     CURRENT_DATE::TEXT, CURRENT_TIME::TEXT, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;
