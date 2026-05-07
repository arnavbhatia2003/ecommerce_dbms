-- ============================================================================
-- E-COMMERCE DATABASE TRANSACTION DEMONSTRATIONS
-- File: 09_transactions.sql
-- Description: 10 transaction demonstrations showing COMMIT, ROLLBACK, SAVEPOINT, and isolation levels
-- Execute Order: 9th (for testing ACID properties)
-- ============================================================================

-- ============================================================================
-- TRANSACTION 1: ORDER PLACEMENT WITH INVENTORY DEDUCTION (COMMIT)
-- ============================================================================

-- Uses DO block to capture RETURNING order_id into a variable dynamically,
-- avoiding hardcoded IDs that break on non-fresh databases.
BEGIN;

DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    -- Step 1: Create order and capture the dynamically assigned order_id
    INSERT INTO orders (user_id, order_date, total_amount, order_status)
    VALUES (5, CURRENT_TIMESTAMP, 1798.00, 'pending')
    RETURNING order_id INTO v_order_id;

    -- Step 2: Insert order items using captured order_id
    INSERT INTO order_item (order_id, product_id, quantity, price_at_purchase)
    VALUES 
        (v_order_id, 7, 2, 799.00),   -- 2 Yoga Mats
        (v_order_id, 1, 1, 599.00);   -- 1 Wireless Mouse

    -- Step 3: Decrement inventory
    UPDATE product SET stock_quantity = stock_quantity - 2 WHERE product_id = 7;
    UPDATE product SET stock_quantity = stock_quantity - 1 WHERE product_id = 1;

    -- Step 4: Create payment record using captured order_id
    INSERT INTO payment (order_id, payment_method, payment_status, payment_date)
    VALUES (v_order_id, 'upi', 'pending', CURRENT_TIMESTAMP);

    -- Step 5: Create shipment record using captured order_id
    INSERT INTO shipment (order_id, courier_name, tracking_number, shipment_status)
    VALUES (v_order_id, 'DTDC', 'DT' || FLOOR(RANDOM() * 1000000)::TEXT, 'pending');

    -- Step 6: Notification created automatically by trg_create_order_notification
    RAISE NOTICE 'Order placed with order_id: %', v_order_id;
END $$;

COMMIT;  -- All steps successful, changes are permanent

-- ============================================================================
-- TRANSACTION 2: PAYMENT PROCESSING WITH ORDER STATUS UPDATE (COMMIT)
-- ============================================================================

BEGIN;

-- Dynamically find the most recent pending order by user 5 (created in Transaction 1)
-- instead of hardcoding order_id = 6
UPDATE payment
SET payment_status = 'completed',
    payment_date = CURRENT_TIMESTAMP
WHERE order_id = (
    SELECT o.order_id FROM orders o
    JOIN payment p ON o.order_id = p.order_id
    WHERE o.user_id = 5 AND p.payment_status = 'pending'
    ORDER BY o.order_date DESC LIMIT 1
);

-- Verify changes before commit (dynamically fetch the same order)
SELECT o.order_id, o.order_status, p.payment_status
FROM orders o
JOIN payment p ON o.order_id = p.order_id
WHERE o.user_id = 5
ORDER BY o.order_date DESC LIMIT 1;

COMMIT;  -- Payment and order status updated atomically

-- ============================================================================
-- TRANSACTION 3: BULK PRODUCT PRICE UPDATE (COMMIT)
-- ============================================================================

BEGIN;

-- Update prices for all electronics products
UPDATE product
SET price = price * 1.10,  -- 10% price increase
    updated_at = CURRENT_TIMESTAMP
WHERE category_id = (SELECT category_id FROM category WHERE category_name = 'Electronics');

-- Verify changes before commit
SELECT product_id, product_name, price, updated_at
FROM product
WHERE category_id = (SELECT category_id FROM category WHERE category_name = 'Electronics');

COMMIT;

-- Check audit trail
SELECT * FROM product_price_audit ORDER BY changed_at DESC LIMIT 5;

-- ============================================================================
-- TRANSACTION 4: ROLLBACK SCENARIO — INSUFFICIENT STOCK
-- ============================================================================

-- Uses DO block with EXCEPTION handler to demonstrate automatic rollback
-- when a constraint violation occurs (insufficient stock).
DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    -- Step 1: Create order and capture dynamic order_id
    INSERT INTO orders (user_id, order_date, total_amount, order_status)
    VALUES (4, CURRENT_TIMESTAMP, 2499.00, 'pending')
    RETURNING order_id INTO v_order_id;

    -- Step 2: Insert order item using captured order_id
    INSERT INTO order_item (order_id, product_id, quantity, price_at_purchase)
    VALUES (v_order_id, 2, 1, 2499.00);  -- 1 Bluetooth Keyboard

    -- Step 3: Check current stock
    RAISE NOTICE 'Attempting to deduct 100 units from product 2...';

    -- Step 4: Attempt to decrement inventory by MORE than available
    -- This will fail due to check constraint or trigger — entire block rolls back
    UPDATE product SET stock_quantity = stock_quantity - 100 WHERE product_id = 2;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Transaction 4 ROLLED BACK: % (Atomicity demonstrated)', SQLERRM;
END $$;

-- Verify rollback: the order should NOT exist because the entire block rolled back

-- ============================================================================
-- TRANSACTION 5: EXPLICIT ROLLBACK
-- ============================================================================

BEGIN;

-- Make some changes
UPDATE product SET price = 9999.99 WHERE product_id = 1;
INSERT INTO notification (user_id, event_type, message, timestamp)
VALUES (1, 'order_placed', 'Test notification', CURRENT_TIMESTAMP);

-- Check changes (they exist in this transaction)
SELECT product_id, product_name, price FROM product WHERE product_id = 1;

-- Decide to rollback
ROLLBACK;

-- Verify rollback: price should be unchanged
SELECT product_id, product_name, price FROM product WHERE product_id = 1;

-- ============================================================================
-- TRANSACTION 6: CONCURRENT ORDER PLACEMENT WITH ROW LOCKING (ISOLATION)
-- ============================================================================

-- Transaction A (User 1 attempting to buy last unit of product 10)
-- Run this in one query window:
BEGIN;

SELECT stock_quantity FROM product WHERE product_id = 10 FOR UPDATE;
-- Acquires row lock on product 10, blocks other transactions

-- Use CTE to capture dynamic order_id from INSERT and chain to order_item
WITH new_order AS (
    INSERT INTO orders (user_id, order_date, total_amount, order_status)
    VALUES (1, CURRENT_TIMESTAMP, 349.00, 'pending')
    RETURNING order_id
)
INSERT INTO order_item (order_id, product_id, quantity, price_at_purchase)
SELECT order_id, 10, 1, 349.00 FROM new_order;

UPDATE product SET stock_quantity = stock_quantity - 1 WHERE product_id = 10;

COMMIT;  -- Releases lock, Transaction A succeeds

-- Transaction B (User 2 attempting to buy same product, started concurrently)
-- Run this in another query window while Transaction A is running:
BEGIN;

SELECT stock_quantity FROM product WHERE product_id = 10 FOR UPDATE;
-- Waits for Transaction A to release lock
-- After Transaction A commits, Transaction B acquires lock and sees stock_quantity = 0

ROLLBACK;  -- Transaction B fails, no changes made

-- ============================================================================
-- TRANSACTION 7: BATCH UPDATE WITH SAVEPOINTS (PARTIAL ROLLBACK)
-- ============================================================================

BEGIN;

-- Update stock for multiple products
UPDATE product SET stock_quantity = stock_quantity + 50 WHERE product_id = 1;
UPDATE product SET stock_quantity = stock_quantity + 30 WHERE product_id = 2;

SAVEPOINT after_first_two_updates;

-- Attempt risky update
UPDATE product SET stock_quantity = stock_quantity + 100 WHERE product_id = 3;

-- Check if stock exceeds limit
DO $$
BEGIN
    IF (SELECT stock_quantity FROM product WHERE product_id = 3) > 200 THEN
        RAISE EXCEPTION 'Stock limit exceeded for product 3';
    END IF;
END $$;

-- If error occurs, rollback to savepoint
ROLLBACK TO SAVEPOINT after_first_two_updates;

-- Continue with safe updates
UPDATE product SET stock_quantity = stock_quantity + 20 WHERE product_id = 4;

COMMIT;  -- Products 1, 2, 4 updated; product 3 unchanged

-- Verify results
SELECT product_id, product_name, stock_quantity 
FROM product 
WHERE product_id IN (1, 2, 3, 4);

-- ============================================================================
-- TRANSACTION 8: READ COMMITTED (Default Isolation Level)
-- ============================================================================

BEGIN;  -- Uses READ COMMITTED by default

SELECT * FROM product WHERE product_id = 1;

-- Another transaction updates this product and commits
-- (Run in another window: UPDATE product SET price = 700 WHERE product_id = 1; COMMIT;)

-- This query sees the new committed value
SELECT * FROM product WHERE product_id = 1;

COMMIT;

-- ============================================================================
-- TRANSACTION 9: REPEATABLE READ
-- ============================================================================

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT * FROM product WHERE product_id = 1;

-- Another transaction updates this product and commits
-- (Run in another window: UPDATE product SET price = 750 WHERE product_id = 1; COMMIT;)

-- This query still sees the old value (snapshot from transaction start)
SELECT * FROM product WHERE product_id = 1;

COMMIT;

-- ============================================================================
-- TRANSACTION 10: SERIALIZABLE
-- ============================================================================

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Read product stock
SELECT stock_quantity FROM product WHERE product_id = 1;

-- Another transaction modifies the same product
-- (Run in another window: UPDATE product SET stock_quantity = 100 WHERE product_id = 1; COMMIT;)

-- Try to update based on read value
UPDATE product SET stock_quantity = stock_quantity - 10 WHERE product_id = 1;

COMMIT;  -- May fail with serialization error if conflict detected
