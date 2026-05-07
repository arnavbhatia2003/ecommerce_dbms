-- ============================================================================
-- E-COMMERCE DATABASE PROCEDURES
-- File: 06_procedures.sql
-- Description: Creates stored procedures for complex operations
-- Execute Order: 6th (after functions)
-- ============================================================================

-- ============================================================================
-- PROCEDURE 1: PLACE ORDER
-- ============================================================================

CREATE OR REPLACE FUNCTION place_order(
    p_user_id INTEGER,
    p_payment_method VARCHAR(50),
    p_courier_name VARCHAR(255)
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_cart_id INTEGER;
    v_total_amount NUMERIC(10,2) := 0;
    v_tracking_number VARCHAR(255);
    cart_item_record RECORD;
BEGIN
    -- Get user's cart
    SELECT cart_id INTO v_cart_id FROM cart WHERE user_id = p_user_id;
    
    IF v_cart_id IS NULL THEN
        RAISE EXCEPTION 'No active cart found for user %', p_user_id;
    END IF;
    
    -- Calculate total amount from cart items
    SELECT SUM(ci.quantity * p.price) INTO v_total_amount
    FROM cart_item ci
    JOIN product p ON ci.product_id = p.product_id
    WHERE ci.cart_id = v_cart_id;
    
    IF v_total_amount IS NULL OR v_total_amount = 0 THEN
        RAISE EXCEPTION 'Cart is empty for user %', p_user_id;
    END IF;
    
    -- Create order
    INSERT INTO orders (user_id, order_date, total_amount, order_status)
    VALUES (p_user_id, CURRENT_TIMESTAMP, v_total_amount, 'pending')
    RETURNING order_id INTO v_order_id;
    
    -- Copy cart items to order items and decrement inventory
    FOR cart_item_record IN 
        SELECT ci.product_id, ci.quantity, p.price, p.stock_quantity
        FROM cart_item ci
        JOIN product p ON ci.product_id = p.product_id
        WHERE ci.cart_id = v_cart_id
        FOR UPDATE OF p
    LOOP
        -- Check stock availability
        IF cart_item_record.stock_quantity < cart_item_record.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %',
                cart_item_record.product_id, cart_item_record.stock_quantity, cart_item_record.quantity;
        END IF;
        
        -- Insert order item
        INSERT INTO order_item (order_id, product_id, quantity, price_at_purchase)
        VALUES (v_order_id, cart_item_record.product_id, cart_item_record.quantity, cart_item_record.price);
        
        -- Decrement inventory
        UPDATE product 
        SET stock_quantity = stock_quantity - cart_item_record.quantity
        WHERE product_id = cart_item_record.product_id;
    END LOOP;
    
    -- Create payment record
    INSERT INTO payment (order_id, payment_method, payment_status, payment_date)
    VALUES (v_order_id, p_payment_method, 'pending', CURRENT_TIMESTAMP);
    
    -- Generate tracking number
    v_tracking_number := 'TRK' || v_order_id || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    
    -- Create shipment record
    INSERT INTO shipment (order_id, courier_name, tracking_number, shipment_status)
    VALUES (v_order_id, p_courier_name, v_tracking_number, 'pending');
    
    -- NOTE: Notification is created automatically by trg_create_order_notification trigger
    -- (fires on INSERT INTO orders). Manual INSERT removed to prevent duplicate notifications.
    
    -- Clear cart items
    DELETE FROM cart_item WHERE cart_id = v_cart_id;
    
    RETURN v_order_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Order placement failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION place_order IS 'Places an order from user cart with inventory management and notifications';

-- ============================================================================
-- PROCEDURE 2: UPDATE PRODUCT STOCK
-- ============================================================================

CREATE OR REPLACE FUNCTION update_product_stock(
    p_product_id INTEGER,
    p_quantity_change INTEGER
) RETURNS VOID AS $$
DECLARE
    v_current_stock INTEGER;
    v_new_stock INTEGER;
BEGIN
    -- Get current stock with row lock
    SELECT stock_quantity INTO v_current_stock
    FROM product
    WHERE product_id = p_product_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id;
    END IF;
    
    -- Calculate new stock
    v_new_stock := v_current_stock + p_quantity_change;
    
    IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'Insufficient stock. Current: %, Requested change: %, Result would be: %',
            v_current_stock, p_quantity_change, v_new_stock;
    END IF;
    
    -- Update stock
    UPDATE product
    SET stock_quantity = v_new_stock,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id;
    
    RAISE NOTICE 'Stock updated for product %. Old: %, New: %',
        p_product_id, v_current_stock, v_new_stock;
        
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error updating stock: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_product_stock IS 'Updates product stock with validation and exception handling';

-- ============================================================================
-- PROCEDURE 3: PROCESS PENDING SHIPMENTS (with Cursor)
-- ============================================================================

CREATE OR REPLACE FUNCTION process_pending_shipments()
RETURNS INTEGER AS $$
DECLARE
    shipment_cursor CURSOR FOR 
        SELECT shipment_id, order_id, tracking_number
        FROM shipment
        WHERE shipment_status = 'pending'
        FOR UPDATE;
    shipment_record RECORD;
    processed_count INTEGER := 0;
BEGIN
    OPEN shipment_cursor;
    
    LOOP
        FETCH shipment_cursor INTO shipment_record;
        EXIT WHEN NOT FOUND;
        
        BEGIN
            -- Update shipment status
            UPDATE shipment
            SET shipment_status = 'in_transit'
            WHERE CURRENT OF shipment_cursor;
            
            -- Create notification
            INSERT INTO notification (user_id, event_type, message, timestamp)
            SELECT u.user_id, 'shipment_dispatched',
                   'Your order #' || shipment_record.order_id || ' has been dispatched. Tracking: ' || shipment_record.tracking_number,
                   CURRENT_TIMESTAMP
            FROM orders o
            JOIN users u ON o.user_id = u.user_id
            WHERE o.order_id = shipment_record.order_id;
            
            processed_count := processed_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error processing shipment %: %', shipment_record.shipment_id, SQLERRM;
                -- Continue processing other shipments
        END;
    END LOOP;
    
    CLOSE shipment_cursor;
    
    RETURN processed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Batch processing failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION process_pending_shipments IS 'Batch processes pending shipments using cursor';
