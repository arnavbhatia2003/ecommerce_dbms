-- ============================================================================
-- PGADMIN VIVA WORKING PROTOTYPE DEMO
-- File: 14_pgadmin_viva_user_flow_demo.sql
-- Purpose:
--   Demonstrates a full e-commerce user flow using the actual project schema,
--   views, utility functions, transactional/operational functions, and triggers.
--
-- How to run in pgAdmin:
--   1. First run files 01 to 07 in order.
--   2. Open this file in Query Tool.
--   3. Highlight and execute one section at a time during viva.
-- ============================================================================

-- ============================================================================
-- SECTION 0: DEMO SAFETY PATCH FOR CART TIMESTAMP TRIGGER
-- ============================================================================
-- The original trigger function uses NEW.cart_id even for DELETE events.
-- DELETE triggers use OLD, so this version supports INSERT, UPDATE, and DELETE.

SELECT 'SECTION 0: Ensure cart timestamp trigger works for INSERT/UPDATE/DELETE' AS demo_step;

CREATE OR REPLACE FUNCTION update_cart_timestamp()
RETURNS TRIGGER AS $$
DECLARE
    v_cart_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cart_id := OLD.cart_id;
    ELSE
        v_cart_id := NEW.cart_id;
    END IF;

    UPDATE cart
    SET updated_at = CURRENT_TIMESTAMP
    WHERE cart_id = v_cart_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_cart_timestamp IS
'Updates cart timestamp when cart items change; supports INSERT, UPDATE, and DELETE';

SELECT 'SECTION 0 COMPLETE: update_cart_timestamp() is ready for INSERT, UPDATE, and DELETE' AS status;


-- ============================================================================
-- SECTION 1: CONFIRM SEED DATA AFTER 03_sample_data.sql
-- ============================================================================

SELECT 'SECTION 1: Seed data row counts' AS demo_step;

SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'seller', COUNT(*) FROM seller
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'product', COUNT(*) FROM product
UNION ALL SELECT 'cart', COUNT(*) FROM cart
UNION ALL SELECT 'cart_item', COUNT(*) FROM cart_item
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'shipment', COUNT(*) FROM shipment
UNION ALL SELECT 'review', COUNT(*) FROM review
UNION ALL SELECT 'notification', COUNT(*) FROM notification
UNION ALL SELECT 'product_price_audit', COUNT(*) FROM product_price_audit
ORDER BY table_name;


-- ============================================================================
-- SECTION 2: SHOW VIEWS FOR READABLE APPLICATION OUTPUT
-- ============================================================================

SELECT 'SECTION 2A: Product catalog view' AS demo_step;

SELECT product_id, product_name, price, stock_quantity, seller_name, category_name
FROM product_catalog
ORDER BY product_id
LIMIT 10;

SELECT 'SECTION 2B: Order summary view' AS demo_step;

SELECT order_id, customer_name, total_amount, order_status,
       payment_status, courier_name, shipment_status
FROM order_summary
ORDER BY order_id
LIMIT 10;


-- ============================================================================
-- SECTION 3: CREATE A FRESH DEMO USER AND CART
-- ============================================================================

SELECT 'SECTION 3: Create demo user and cart' AS demo_step;

CREATE TEMP TABLE IF NOT EXISTS viva_demo_context (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

TRUNCATE viva_demo_context;

INSERT INTO viva_demo_context (key, value)
VALUES ('run_label', TO_CHAR(clock_timestamp(), 'YYYYMMDDHH24MISSMS'));

INSERT INTO viva_demo_context (key, value)
SELECT 'demo_email', 'viva.demo.' || value || '@example.com'
FROM viva_demo_context
WHERE key = 'run_label';

WITH new_user AS (
    INSERT INTO users (name, email, phone, address, password)
    SELECT 'Viva Demo Customer',
           value,
           '9999999999',
           'Demo Address, Viva City',
           'demo123'
    FROM viva_demo_context
    WHERE key = 'demo_email'
    RETURNING user_id
)
INSERT INTO viva_demo_context (key, value)
SELECT 'demo_user_id', user_id::TEXT
FROM new_user;

WITH new_cart AS (
    INSERT INTO cart (user_id, created_date)
    SELECT value::INTEGER, CURRENT_TIMESTAMP
    FROM viva_demo_context
    WHERE key = 'demo_user_id'
    RETURNING cart_id
)
INSERT INTO viva_demo_context (key, value)
SELECT 'demo_cart_id', cart_id::TEXT
FROM new_cart;

INSERT INTO viva_demo_context (key, value)
SELECT 'mouse_product_id', product_id::TEXT
FROM product
WHERE product_name = 'Wireless Mouse'
LIMIT 1;

INSERT INTO viva_demo_context (key, value)
SELECT 'yoga_product_id', product_id::TEXT
FROM product
WHERE product_name = 'Yoga Mat'
LIMIT 1;

-- Make sure demo products have enough stock for repeated viva runs.
UPDATE product
SET stock_quantity = GREATEST(stock_quantity, 20)
WHERE product_id IN (
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'yoga_product_id')
);

SELECT u.user_id, u.name, u.email, c.cart_id, c.created_date, c.updated_at
FROM users u
JOIN cart c ON u.user_id = c.user_id
WHERE u.user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id');


-- ============================================================================
-- SECTION 4: ADD CART ITEMS AND DEMONSTRATE DUPLICATE MERGE TRIGGER
-- ============================================================================
-- Triggers demonstrated:
--   trg_prevent_duplicate_cart_items
--   trg_update_cart_timestamp

SELECT 'SECTION 4: Add cart items and trigger duplicate merge' AS demo_step;

SELECT cart_id, updated_at AS cart_updated_before
FROM cart
WHERE cart_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id');

-- First insert: Wireless Mouse quantity 1.
INSERT INTO cart_item (cart_id, product_id, quantity)
VALUES (
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id'),
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
    1
);

-- Second insert: same product quantity 2.
-- The trigger should merge this into the existing row instead of creating a duplicate.
INSERT INTO cart_item (cart_id, product_id, quantity)
VALUES (
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id'),
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
    2
);

-- Add a second product to make the order multi-item.
INSERT INTO cart_item (cart_id, product_id, quantity)
VALUES (
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id'),
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'yoga_product_id'),
    1
);

SELECT ci.cart_item_id, ci.cart_id, p.product_name, ci.quantity,
       p.price, (ci.quantity * p.price) AS line_total
FROM cart_item ci
JOIN product p ON ci.product_id = p.product_id
WHERE ci.cart_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id')
ORDER BY ci.cart_item_id;

SELECT c.cart_id, c.updated_at AS cart_updated_after,
       COUNT(ci.cart_item_id) AS distinct_cart_rows,
       SUM(ci.quantity) AS total_units,
       SUM(ci.quantity * p.price) AS cart_total
FROM cart c
JOIN cart_item ci ON c.cart_id = ci.cart_id
JOIN product p ON ci.product_id = p.product_id
WHERE c.cart_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id')
GROUP BY c.cart_id, c.updated_at;


-- ============================================================================
-- SECTION 5: DEMONSTRATE ALL UTILITY FUNCTIONS FROM 05_functions.sql
-- ============================================================================

SELECT 'SECTION 5: Utility database functions' AS demo_step;

SELECT 'get_product_avg_rating(mouse)' AS function_name,
       get_product_avg_rating((SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'))::TEXT AS result
UNION ALL
SELECT 'get_seller_revenue(1)',
       get_seller_revenue(1)::TEXT
UNION ALL
SELECT 'check_product_availability(mouse, 2)',
       check_product_availability((SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'), 2)::TEXT
UNION ALL
SELECT 'get_user_order_count(demo user) before checkout',
       get_user_order_count((SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id'))::TEXT;


-- ============================================================================
-- SECTION 6: PLACE ORDER USING TRANSACTIONAL FUNCTION place_order()
-- ============================================================================
-- Function demonstrated:
--   place_order(p_user_id, p_payment_method, p_courier_name)
--
-- Internally this creates:
--   orders, order_item, payment, shipment
-- It also updates:
--   product stock, cart_item cleanup
-- Trigger automatically creates:
--   notification row for order_placed

SELECT 'SECTION 6: Checkout using place_order()' AS demo_step;

WITH placed AS (
    SELECT place_order(
        (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id'),
        'upi',
        'BlueDart'
    ) AS order_id
)
INSERT INTO viva_demo_context (key, value)
SELECT 'demo_order_id', order_id::TEXT
FROM placed;

SELECT value::INTEGER AS new_order_id
FROM viva_demo_context
WHERE key = 'demo_order_id';


-- ============================================================================
-- SECTION 7: RETRIEVE INFORMATION AFTER CHECKOUT
-- ============================================================================

SELECT 'SECTION 7A: New order row' AS demo_step;

SELECT order_id, user_id, order_date, total_amount, order_status, updated_at
FROM orders
WHERE order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT 'SECTION 7B: Order items with historical pricing' AS demo_step;

SELECT oi.order_item_id, oi.order_id, p.product_name,
       oi.quantity, oi.price_at_purchase,
       (oi.quantity * oi.price_at_purchase) AS line_total,
       p.price AS current_product_price
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
WHERE oi.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id')
ORDER BY oi.order_item_id;

SELECT 'SECTION 7C: Payment and shipment rows created by place_order()' AS demo_step;

SELECT o.order_id, o.order_status,
       pay.payment_method, pay.payment_status, pay.payment_date,
       sh.courier_name, sh.tracking_number, sh.shipment_status, sh.delivery_date
FROM orders o
JOIN payment pay ON o.order_id = pay.order_id
JOIN shipment sh ON o.order_id = sh.order_id
WHERE o.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT 'SECTION 7D: Cart is cleared after checkout' AS demo_step;

SELECT c.cart_id, COUNT(ci.cart_item_id) AS remaining_cart_items
FROM cart c
LEFT JOIN cart_item ci ON c.cart_id = ci.cart_id
WHERE c.cart_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_cart_id')
GROUP BY c.cart_id;

SELECT 'SECTION 7E: Order placement notification created by trigger' AS demo_step;

SELECT notification_id, event_type, message, timestamp, is_read
FROM notification
WHERE user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY notification_id;

SELECT 'SECTION 7F: calculate_order_total() matches stored total_amount' AS demo_step;

SELECT o.order_id,
       o.total_amount AS stored_total_amount,
       calculate_order_total(o.order_id) AS calculated_total_from_order_items
FROM orders o
WHERE o.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');


-- ============================================================================
-- SECTION 8: PAYMENT STATUS UPDATE TRIGGER
-- ============================================================================
-- Trigger demonstrated:
--   trg_update_order_on_payment

SELECT 'SECTION 8: Complete payment and watch order confirmation trigger' AS demo_step;

UPDATE payment
SET payment_status = 'completed',
    payment_date = CURRENT_TIMESTAMP
WHERE order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT o.order_id, o.order_status, p.payment_status, p.payment_date
FROM orders o
JOIN payment p ON o.order_id = p.order_id
WHERE o.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT notification_id, event_type, message, timestamp
FROM notification
WHERE user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY notification_id;


-- ============================================================================
-- SECTION 9: PROCESS PENDING SHIPMENTS USING EXPLICIT CURSOR FUNCTION
-- ============================================================================
-- Function demonstrated:
--   process_pending_shipments()
--
-- This function processes all currently pending shipments, not only the demo one.

SELECT 'SECTION 9A: Pending shipments before cursor function' AS demo_step;

SELECT COUNT(*) AS pending_shipments_before
FROM shipment
WHERE shipment_status = 'pending';

SELECT 'SECTION 9B: Run process_pending_shipments()' AS demo_step;

SELECT process_pending_shipments() AS shipments_processed;

SELECT 'SECTION 9C: Demo shipment after cursor processing' AS demo_step;

SELECT shipment_id, order_id, tracking_number, shipment_status, delivery_date
FROM shipment
WHERE order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT 'SECTION 9D: Shipment notification after cursor processing' AS demo_step;

SELECT notification_id, event_type, message, timestamp
FROM notification
WHERE user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY notification_id;


-- ============================================================================
-- SECTION 10: SHIPMENT DELIVERY TRIGGER
-- ============================================================================
-- Trigger demonstrated:
--   trg_update_order_on_delivery

SELECT 'SECTION 10: Mark shipment delivered and watch order status update' AS demo_step;

UPDATE shipment
SET shipment_status = 'delivered'
WHERE order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT o.order_id, o.order_status, sh.shipment_status, sh.delivery_date
FROM orders o
JOIN shipment sh ON o.order_id = sh.order_id
WHERE o.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT notification_id, event_type, message, timestamp
FROM notification
WHERE user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY notification_id;


-- ============================================================================
-- SECTION 11: REVIEW FLOW AND AVERAGE RATING FUNCTION
-- ============================================================================

SELECT 'SECTION 11: Insert review and calculate product average rating' AS demo_step;

INSERT INTO review (product_id, user_id, rating, comment, review_date)
VALUES (
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id'),
    5,
    'Great product in the live viva demo.',
    CURRENT_TIMESTAMP
);

SELECT p.product_id, p.product_name,
       get_product_avg_rating(p.product_id) AS product_avg_rating,
       COUNT(r.review_id) AS review_count
FROM product p
LEFT JOIN review r ON p.product_id = r.product_id
WHERE p.product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id')
GROUP BY p.product_id, p.product_name;


-- ============================================================================
-- SECTION 12: UPDATE PRODUCT STOCK USING OPERATIONAL FUNCTION
-- ============================================================================
-- Function demonstrated:
--   update_product_stock()
--
-- Trigger also encountered:
--   trg_update_product_timestamp

SELECT 'SECTION 12A: Product stock before update_product_stock()' AS demo_step;

SELECT product_id, product_name, stock_quantity, updated_at
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');

SELECT update_product_stock(
    (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
    5
);

SELECT 'SECTION 12B: Product stock after update_product_stock()' AS demo_step;

SELECT product_id, product_name, stock_quantity, updated_at
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');


-- ============================================================================
-- SECTION 13: PRODUCT PRICE AUDIT TRIGGER
-- ============================================================================
-- Trigger demonstrated:
--   trg_log_price_change

SELECT 'SECTION 13A: Price before update' AS demo_step;

SELECT product_id, product_name, price, updated_at
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');

UPDATE product
SET price = price + 25.00
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');

SELECT 'SECTION 13B: Price after update and audit row created' AS demo_step;

SELECT product_id, product_name, price, updated_at
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');

SELECT audit_id, product_id, old_price, new_price,
       (new_price - old_price) AS price_change_amount,
       changed_by, changed_at
FROM product_price_audit
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id')
ORDER BY audit_id DESC
LIMIT 5;


-- ============================================================================
-- SECTION 14: HISTORICAL PRICING PROOF
-- ============================================================================

SELECT 'SECTION 14: price_at_purchase remains unchanged after product price changes' AS demo_step;

SELECT oi.order_id, p.product_name,
       oi.price_at_purchase AS historical_order_price,
       p.price AS current_catalog_price
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
WHERE oi.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id')
  AND oi.product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');


-- ============================================================================
-- SECTION 15: VALIDATION AND ERROR-PROTECTION DEMOS
-- ============================================================================
-- These blocks catch errors so the demo script can continue.

SELECT 'SECTION 15A: Invalid total_amount blocked by trg_validate_order_total' AS demo_step;

DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    SELECT value::INTEGER INTO v_order_id
    FROM viva_demo_context
    WHERE key = 'demo_order_id';

    BEGIN
        UPDATE orders
        SET total_amount = total_amount + 999.00
        WHERE order_id = v_order_id;

        RAISE NOTICE 'Unexpected: invalid total update succeeded.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Expected: invalid total update blocked: %', SQLERRM;
    END;
END $$;

SELECT order_id, total_amount, calculate_order_total(order_id) AS correct_total
FROM orders
WHERE order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT 'SECTION 15B: Negative stock blocked by trigger/constraint' AS demo_step;

DO $$
DECLARE
    v_product_id INTEGER;
BEGIN
    SELECT value::INTEGER INTO v_product_id
    FROM viva_demo_context
    WHERE key = 'mouse_product_id';

    BEGIN
        UPDATE product
        SET stock_quantity = -1
        WHERE product_id = v_product_id;

        RAISE NOTICE 'Unexpected: negative stock update succeeded.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Expected: negative stock update blocked: %', SQLERRM;
    END;
END $$;

SELECT product_id, product_name, stock_quantity
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');

SELECT 'SECTION 15C: Duplicate review blocked by UNIQUE(product_id, user_id)' AS demo_step;

DO $$
BEGIN
    BEGIN
        INSERT INTO review (product_id, user_id, rating, comment, review_date)
        VALUES (
            (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id'),
            (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id'),
            4,
            'Second review should fail.',
            CURRENT_TIMESTAMP
        );

        RAISE NOTICE 'Unexpected: duplicate review insert succeeded.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Expected: duplicate review blocked: %', SQLERRM;
    END;
END $$;

SELECT product_id, user_id, rating, comment, review_date
FROM review
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id')
  AND user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id');

SELECT 'SECTION 15D: Availability function returns false for unrealistic quantity' AS demo_step;

SELECT product_id, product_name, stock_quantity,
       check_product_availability(product_id, 999999) AS can_buy_999999_units
FROM product
WHERE product_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'mouse_product_id');


-- ============================================================================
-- SECTION 16: FINAL USER DASHBOARD / END-TO-END RESULT
-- ============================================================================

SELECT 'SECTION 16A: Final demo user summary' AS demo_step;

SELECT u.user_id, u.name, u.email,
       get_user_order_count(u.user_id) AS total_orders_for_user
FROM users u
WHERE u.user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id');

SELECT 'SECTION 16B: Final order summary' AS demo_step;

SELECT os.order_id, os.customer_name, os.total_amount, os.order_status,
       os.payment_status, os.courier_name, os.tracking_number,
       os.shipment_status, os.delivery_date
FROM order_summary os
WHERE os.order_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_order_id');

SELECT 'SECTION 16C: Final notifications timeline' AS demo_step;

SELECT notification_id, event_type, message, timestamp, is_read
FROM notification
WHERE user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY notification_id;

SELECT 'SECTION 16D: Final review and product rating' AS demo_step;

SELECT r.review_id, p.product_name, r.rating, r.comment,
       get_product_avg_rating(p.product_id) AS current_product_avg_rating
FROM review r
JOIN product p ON r.product_id = p.product_id
WHERE r.user_id = (SELECT value::INTEGER FROM viva_demo_context WHERE key = 'demo_user_id')
ORDER BY r.review_id;

-- ============================================================================
-- END OF DEMO
-- ============================================================================

SELECT 'DEMO COMPLETE: full e-commerce database prototype flow demonstrated successfully.' AS final_message;
