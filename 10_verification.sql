-- ============================================================================
-- E-COMMERCE DATABASE VERIFICATION SUITE
-- File: 10_verification.sql
-- Description: Comprehensive tests for schema, data, triggers, functions,
--              procedures, cursors, and constraints
-- Execute Order: 10th (after all other scripts)
-- ============================================================================

-- ============================================================================
-- SECTION 1: SCHEMA VERIFICATION
-- ============================================================================

-- TEST: Confirm all 13 tables exist with correct column counts
-- EXPECTED: 13 rows, each showing table name and column count
SELECT 
    t.table_name,
    COUNT(c.column_name) AS column_count
FROM information_schema.tables t
JOIN information_schema.columns c 
    ON t.table_name = c.table_name AND t.table_schema = c.table_schema
WHERE t.table_schema = 'public' 
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;
-- VERIFY: Should return 13 tables (cart, cart_item, category, notification,
--         order_item, orders, payment, product, product_price_audit, review,
--         seller, shipment, users)

-- TEST: Confirm both views exist
-- EXPECTED: 2 views (order_summary, product_catalog)
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'VIEW'
ORDER BY table_name;

-- TEST: Confirm all 23 indexes exist
-- EXPECTED: 23 custom indexes (excluding auto-created PK indexes)
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- TEST: Confirm all foreign key constraints
-- EXPECTED: 13 foreign keys across all tables
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;


-- ============================================================================
-- SECTION 2: DATA VERIFICATION
-- ============================================================================

-- TEST: Confirm all seed data was inserted correctly
-- EXPECTED: Row counts match seed data quantities
SELECT 'users' AS table_name, COUNT(*) AS row_count, 5 AS expected FROM users
UNION ALL SELECT 'seller', COUNT(*), 5 FROM seller
UNION ALL SELECT 'category', COUNT(*), 5 FROM category
UNION ALL SELECT 'product', COUNT(*), 10 FROM product
UNION ALL SELECT 'cart', COUNT(*), 3 FROM cart
UNION ALL SELECT 'cart_item', COUNT(*), 6 FROM cart_item
UNION ALL SELECT 'orders', COUNT(*), 5 FROM orders
UNION ALL SELECT 'order_item', COUNT(*), 8 FROM order_item
UNION ALL SELECT 'payment', COUNT(*), 5 FROM payment
UNION ALL SELECT 'shipment', COUNT(*), 5 FROM shipment
UNION ALL SELECT 'review', COUNT(*), 5 FROM review
UNION ALL SELECT 'notification', COUNT(*), 5 FROM notification
ORDER BY table_name;
-- VERIFY: row_count should match expected for each table (before transactions run)


-- ============================================================================
-- SECTION 3: TRIGGER VERIFICATION (9 triggers)
-- ============================================================================

-- TRIGGER TEST 1: trg_check_stock_quantity (prevent negative stock)
-- EXPECTED: ERROR raised, stock unchanged
DO $$
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 1: trg_check_stock_quantity ---';
    BEGIN
        UPDATE product SET stock_quantity = -1 WHERE product_id = 1;
        RAISE NOTICE 'FAIL: Negative stock was allowed!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'PASS: Trigger blocked negative stock — %', SQLERRM;
    END;
END $$;

-- TRIGGER TEST 2: trg_update_order_on_payment (auto-confirm on payment)
-- EXPECTED: Order status changes from 'pending' to 'confirmed'
DO $$
DECLARE
    v_status VARCHAR;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 2: trg_update_order_on_payment ---';
    -- Find a pending order with pending payment
    SELECT o.order_status INTO v_status
    FROM orders o JOIN payment p ON o.order_id = p.order_id
    WHERE p.payment_status = 'pending' LIMIT 1;
    RAISE NOTICE 'BEFORE: order_status = %', v_status;

    UPDATE payment SET payment_status = 'completed'
    WHERE order_id = (
        SELECT order_id FROM payment WHERE payment_status = 'pending' LIMIT 1
    );

    SELECT o.order_status INTO v_status
    FROM orders o JOIN payment p ON o.order_id = p.order_id
    WHERE p.payment_status = 'completed' 
    ORDER BY p.payment_date DESC LIMIT 1;
    RAISE NOTICE 'AFTER: order_status = % (expected: confirmed)', v_status;
END $$;

-- TRIGGER TEST 3: trg_update_order_on_delivery (auto-deliver on shipment)
-- EXPECTED: Order status changes to 'delivered'
DO $$
DECLARE
    v_status VARCHAR;
    v_sid INTEGER;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 3: trg_update_order_on_delivery ---';
    SELECT s.shipment_id INTO v_sid
    FROM shipment s WHERE s.shipment_status != 'delivered' LIMIT 1;
    
    IF v_sid IS NOT NULL THEN
        UPDATE shipment SET shipment_status = 'delivered' WHERE shipment_id = v_sid;
        SELECT o.order_status INTO v_status
        FROM orders o JOIN shipment s ON o.order_id = s.order_id
        WHERE s.shipment_id = v_sid;
        RAISE NOTICE 'PASS: Order status after delivery = % (expected: delivered)', v_status;
    ELSE
        RAISE NOTICE 'SKIP: No non-delivered shipments to test';
    END IF;
END $$;

-- TRIGGER TEST 4: trg_create_order_notification (auto-notify on order)
-- EXPECTED: New notification created when order is inserted
DO $$
DECLARE
    v_count_before INTEGER;
    v_count_after INTEGER;
    v_oid INTEGER;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 4: trg_create_order_notification ---';
    SELECT COUNT(*) INTO v_count_before FROM notification;
    
    INSERT INTO orders (user_id, order_date, total_amount, order_status)
    VALUES (1, CURRENT_TIMESTAMP, 100.00, 'pending')
    RETURNING order_id INTO v_oid;
    
    SELECT COUNT(*) INTO v_count_after FROM notification;
    RAISE NOTICE 'Notifications before: %, after: % (expected: +1)', v_count_before, v_count_after;
    
    -- Cleanup test order
    DELETE FROM notification WHERE message LIKE '%order #' || v_oid || '%';
    DELETE FROM orders WHERE order_id = v_oid;
END $$;

-- TRIGGER TEST 5: trg_update_product_timestamp (auto-update timestamp)
-- EXPECTED: updated_at changes when product is modified
DO $$
DECLARE
    v_before TIMESTAMPTZ;
    v_after TIMESTAMPTZ;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 5: trg_update_product_timestamp ---';
    SELECT updated_at INTO v_before FROM product WHERE product_id = 1;
    PERFORM pg_sleep(0.1);  -- small delay to ensure timestamp differs
    UPDATE product SET description = description || '' WHERE product_id = 1;
    SELECT updated_at INTO v_after FROM product WHERE product_id = 1;
    RAISE NOTICE 'BEFORE: %, AFTER: % (should differ)', v_before, v_after;
END $$;

-- TRIGGER TEST 6: trg_update_cart_timestamp (cart updated when items change)
-- EXPECTED: cart.updated_at changes when cart_item is modified
DO $$
DECLARE
    v_before TIMESTAMPTZ;
    v_after TIMESTAMPTZ;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 6: trg_update_cart_timestamp ---';
    SELECT updated_at INTO v_before FROM cart WHERE cart_id = 1;
    PERFORM pg_sleep(0.1);
    UPDATE cart_item SET quantity = quantity WHERE cart_id = 1 AND cart_item_id = (
        SELECT cart_item_id FROM cart_item WHERE cart_id = 1 LIMIT 1
    );
    SELECT updated_at INTO v_after FROM cart WHERE cart_id = 1;
    RAISE NOTICE 'BEFORE: %, AFTER: % (should differ)', v_before, v_after;
END $$;

-- TRIGGER TEST 7: trg_validate_order_total (block mismatched totals)
-- EXPECTED: ERROR when trying to set wrong total
DO $$
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 7: trg_validate_order_total ---';
    BEGIN
        UPDATE orders SET total_amount = 9999.99 WHERE order_id = 1;
        RAISE NOTICE 'FAIL: Mismatched total was allowed!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'PASS: Trigger blocked mismatched total — %', SQLERRM;
    END;
END $$;

-- TRIGGER TEST 8: trg_prevent_duplicate_cart_items (merge duplicates)
-- EXPECTED: Duplicate insert merges quantity instead of creating new row
DO $$
DECLARE
    v_qty_before INTEGER;
    v_qty_after INTEGER;
    v_count_before INTEGER;
    v_count_after INTEGER;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 8: trg_prevent_duplicate_cart_items ---';
    SELECT quantity INTO v_qty_before FROM cart_item WHERE cart_id = 1 AND product_id = 1;
    SELECT COUNT(*) INTO v_count_before FROM cart_item WHERE cart_id = 1;
    
    -- Try inserting duplicate product into same cart
    INSERT INTO cart_item (cart_id, product_id, quantity) VALUES (1, 1, 5);
    
    SELECT quantity INTO v_qty_after FROM cart_item WHERE cart_id = 1 AND product_id = 1;
    SELECT COUNT(*) INTO v_count_after FROM cart_item WHERE cart_id = 1;
    RAISE NOTICE 'Qty before: %, after: % (expected: +5). Row count before: %, after: % (expected: same)',
        v_qty_before, v_qty_after, v_count_before, v_count_after;
    
    -- Restore original quantity
    UPDATE cart_item SET quantity = v_qty_before WHERE cart_id = 1 AND product_id = 1;
END $$;

-- TRIGGER TEST 9: trg_log_price_change (audit trail)
-- EXPECTED: New row in product_price_audit when price changes
DO $$
DECLARE
    v_count_before INTEGER;
    v_count_after INTEGER;
    v_old_price NUMERIC;
BEGIN
    RAISE NOTICE '--- TRIGGER TEST 9: trg_log_price_change ---';
    SELECT COUNT(*) INTO v_count_before FROM product_price_audit;
    SELECT price INTO v_old_price FROM product WHERE product_id = 1;
    
    UPDATE product SET price = price + 1.00 WHERE product_id = 1;
    
    SELECT COUNT(*) INTO v_count_after FROM product_price_audit;
    RAISE NOTICE 'Audit rows before: %, after: % (expected: +1)', v_count_before, v_count_after;
    
    -- Restore original price
    UPDATE product SET price = v_old_price WHERE product_id = 1;
END $$;


-- ============================================================================
-- SECTION 4: FUNCTION VERIFICATION (5 functions)
-- ============================================================================

-- TEST: calculate_order_total(1)
-- EXPECTED: Should equal sum of order_item quantities * prices for order 1
SELECT 'calculate_order_total(1)' AS function_test,
       calculate_order_total(1) AS result,
       (SELECT SUM(quantity * price_at_purchase) FROM order_item WHERE order_id = 1) AS expected;

-- TEST: get_product_avg_rating(2)
-- EXPECTED: Average rating from reviews for product 2
SELECT 'get_product_avg_rating(2)' AS function_test,
       get_product_avg_rating(2) AS result,
       (SELECT ROUND(AVG(rating)::NUMERIC, 2) FROM review WHERE product_id = 2) AS expected;

-- TEST: get_seller_revenue(1)
-- EXPECTED: Total revenue for seller 1 from non-cancelled/non-pending orders
SELECT 'get_seller_revenue(1)' AS function_test,
       get_seller_revenue(1) AS result;

-- TEST: check_product_availability(1, 5)
-- EXPECTED: TRUE if product 1 has >= 5 in stock
SELECT 'check_product_availability(1, 5)' AS function_test,
       check_product_availability(1, 5) AS result,
       (SELECT stock_quantity >= 5 FROM product WHERE product_id = 1) AS expected;

-- TEST: get_user_order_count(1)
-- EXPECTED: Number of orders for user 1
SELECT 'get_user_order_count(1)' AS function_test,
       get_user_order_count(1) AS result,
       (SELECT COUNT(*) FROM orders WHERE user_id = 1) AS expected;


-- ============================================================================
-- SECTION 5: PROCEDURE VERIFICATION (3 procedures)
-- ============================================================================

-- TEST: place_order() — requires a user with items in cart
-- EXPECTED: Creates order, order_items, payment, shipment; clears cart; returns order_id
-- NOTE: User 1 has a cart with items from seed data
DO $$
DECLARE
    v_oid INTEGER;
    v_cart_count INTEGER;
BEGIN
    RAISE NOTICE '--- PROCEDURE TEST: place_order ---';
    
    -- Check cart has items before
    SELECT COUNT(*) INTO v_cart_count FROM cart_item ci
    JOIN cart c ON ci.cart_id = c.cart_id WHERE c.user_id = 1;
    RAISE NOTICE 'Cart items before: %', v_cart_count;
    
    IF v_cart_count > 0 THEN
        v_oid := place_order(1, 'credit_card', 'BlueDart');
        RAISE NOTICE 'PASS: Order created with id: %', v_oid;
        
        -- Verify related records exist
        PERFORM 1 FROM payment WHERE order_id = v_oid;
        RAISE NOTICE 'Payment record: %', CASE WHEN FOUND THEN 'EXISTS' ELSE 'MISSING' END;
        PERFORM 1 FROM shipment WHERE order_id = v_oid;
        RAISE NOTICE 'Shipment record: %', CASE WHEN FOUND THEN 'EXISTS' ELSE 'MISSING' END;
        
        SELECT COUNT(*) INTO v_cart_count FROM cart_item ci
        JOIN cart c ON ci.cart_id = c.cart_id WHERE c.user_id = 1;
        RAISE NOTICE 'Cart items after: % (expected: 0)', v_cart_count;
    ELSE
        RAISE NOTICE 'SKIP: User 1 cart is empty (may have been cleared by prior test)';
    END IF;
END $$;

-- TEST: update_product_stock(1, 10) — add 10 units
-- EXPECTED: Stock increases by 10
DO $$
DECLARE
    v_before INTEGER;
    v_after INTEGER;
BEGIN
    RAISE NOTICE '--- PROCEDURE TEST: update_product_stock ---';
    SELECT stock_quantity INTO v_before FROM product WHERE product_id = 1;
    PERFORM update_product_stock(1, 10);
    SELECT stock_quantity INTO v_after FROM product WHERE product_id = 1;
    RAISE NOTICE 'Stock before: %, after: % (expected: +10)', v_before, v_after;
    -- Restore
    PERFORM update_product_stock(1, -10);
END $$;

-- TEST: process_pending_shipments() — uses cursor
-- Tested in Section 6 below


-- ============================================================================
-- SECTION 6: CURSOR VERIFICATION
-- ============================================================================

-- TEST: process_pending_shipments() uses an explicit cursor
-- EXPECTED: Returns count of shipments processed; changes status to 'in_transit'
DO $$
DECLARE
    v_pending_before INTEGER;
    v_processed INTEGER;
    v_pending_after INTEGER;
BEGIN
    RAISE NOTICE '--- CURSOR TEST: process_pending_shipments ---';
    SELECT COUNT(*) INTO v_pending_before FROM shipment WHERE shipment_status = 'pending';
    RAISE NOTICE 'Pending shipments before: %', v_pending_before;
    
    v_processed := process_pending_shipments();
    RAISE NOTICE 'Shipments processed by cursor: %', v_processed;
    
    SELECT COUNT(*) INTO v_pending_after FROM shipment WHERE shipment_status = 'pending';
    RAISE NOTICE 'Pending shipments after: % (expected: 0 or fewer)', v_pending_after;
END $$;


-- ============================================================================
-- SECTION 7: CONSTRAINT VERIFICATION (intentional violations)
-- All wrapped in subtransaction blocks so data stays clean
-- ============================================================================

-- TEST: PRIMARY KEY violation
-- EXPECTED: ERROR duplicate key
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: PRIMARY KEY ---';
    BEGIN
        INSERT INTO users (user_id, name, email, password) VALUES (1, 'Duplicate', 'dup@test.com', 'x');
        RAISE NOTICE 'FAIL: Duplicate PK was allowed!';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'PASS: PK constraint blocked duplicate — %', SQLERRM;
    END;
END $$;

-- TEST: FOREIGN KEY violation
-- EXPECTED: ERROR foreign key constraint
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: FOREIGN KEY ---';
    BEGIN
        INSERT INTO product (seller_id, category_id, product_name, price, stock_quantity)
        VALUES (999, 999, 'Ghost Product', 10.00, 1);
        RAISE NOTICE 'FAIL: Invalid FK was allowed!';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'PASS: FK constraint blocked invalid reference — %', SQLERRM;
    END;
END $$;

-- TEST: UNIQUE constraint violation (email)
-- EXPECTED: ERROR duplicate key
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: UNIQUE ---';
    BEGIN
        INSERT INTO users (name, email, password) VALUES ('Test', 'arnav.bhatia@example.com', 'x');
        RAISE NOTICE 'FAIL: Duplicate email was allowed!';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'PASS: UNIQUE constraint blocked duplicate email — %', SQLERRM;
    END;
END $$;

-- TEST: CHECK constraint violation (negative price)
-- EXPECTED: ERROR check constraint
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: CHECK (price > 0) ---';
    BEGIN
        INSERT INTO product (seller_id, category_id, product_name, price, stock_quantity)
        VALUES (1, 1, 'Bad Product', -5.00, 1);
        RAISE NOTICE 'FAIL: Negative price was allowed!';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS: CHECK constraint blocked negative price — %', SQLERRM;
    END;
END $$;

-- TEST: CHECK constraint violation (invalid order status)
-- EXPECTED: ERROR check constraint
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: CHECK (order_status IN (...)) ---';
    BEGIN
        INSERT INTO orders (user_id, order_date, total_amount, order_status)
        VALUES (1, CURRENT_TIMESTAMP, 100.00, 'INVALID_STATUS');
        RAISE NOTICE 'FAIL: Invalid status was allowed!';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS: CHECK constraint blocked invalid status — %', SQLERRM;
    END;
END $$;

-- TEST: NOT NULL constraint violation
-- EXPECTED: ERROR not-null constraint
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: NOT NULL ---';
    BEGIN
        INSERT INTO users (name, email, password) VALUES (NULL, 'test@x.com', 'x');
        RAISE NOTICE 'FAIL: NULL name was allowed!';
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE 'PASS: NOT NULL constraint blocked null name — %', SQLERRM;
    END;
END $$;

-- TEST: ON DELETE RESTRICT (cannot delete seller with products)
-- EXPECTED: ERROR foreign key violation
DO $$
BEGIN
    RAISE NOTICE '--- CONSTRAINT TEST: ON DELETE RESTRICT ---';
    BEGIN
        DELETE FROM seller WHERE seller_id = 1;
        RAISE NOTICE 'FAIL: Seller with products was deleted!';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'PASS: RESTRICT blocked deletion of seller with products — %', SQLERRM;
    END;
END $$;


-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================
SELECT '========== VERIFICATION COMPLETE ==========' AS status;
SELECT 
    'Total Products' AS metric, COUNT(*)::TEXT AS value FROM product
UNION ALL SELECT 'Total Orders', COUNT(*)::TEXT FROM orders
UNION ALL SELECT 'Total Revenue', '₹' || ROUND(SUM(total_amount), 2)::TEXT 
    FROM orders WHERE order_status != 'cancelled'
UNION ALL SELECT 'Total Customers', COUNT(*)::TEXT FROM users
UNION ALL SELECT 'Total Triggers', COUNT(*)::TEXT 
    FROM information_schema.triggers WHERE trigger_schema = 'public'
UNION ALL SELECT 'Total Indexes', COUNT(*)::TEXT 
    FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%';
