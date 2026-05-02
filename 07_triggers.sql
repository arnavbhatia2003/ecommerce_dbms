-- ============================================================================
-- E-COMMERCE DATABASE TRIGGERS
-- File: 07_triggers.sql
-- Description: Creates triggers for automated business rules
-- Execute Order: 7th (after procedures)
-- ============================================================================

-- ============================================================================
-- TRIGGER 1: PREVENT NEGATIVE STOCK QUANTITY
-- ============================================================================

CREATE OR REPLACE FUNCTION check_stock_quantity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock_quantity < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative for product %. Attempted value: %',
            NEW.product_id, NEW.stock_quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_stock_quantity
BEFORE UPDATE OF stock_quantity ON product
FOR EACH ROW
EXECUTE FUNCTION check_stock_quantity();

COMMENT ON TRIGGER trg_check_stock_quantity ON product IS 'Prevents negative stock quantities';

-- ============================================================================
-- TRIGGER 2: UPDATE ORDER STATUS ON PAYMENT COMPLETION
-- ============================================================================

CREATE OR REPLACE FUNCTION update_order_status_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_status = 'completed' AND OLD.payment_status != 'completed' THEN
        UPDATE orders
        SET order_status = 'confirmed',
            updated_at = CURRENT_TIMESTAMP
        WHERE order_id = NEW.order_id 
          AND order_status = 'pending';
        
        -- Create notification
        INSERT INTO notification (user_id, event_type, message, timestamp)
        SELECT user_id, 'payment_received',
               'Payment received for order #' || NEW.order_id,
               CURRENT_TIMESTAMP
        FROM orders
        WHERE order_id = NEW.order_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_on_payment
AFTER UPDATE OF payment_status ON payment
FOR EACH ROW
EXECUTE FUNCTION update_order_status_on_payment();

COMMENT ON TRIGGER trg_update_order_on_payment ON payment IS 'Updates order status when payment completes';

-- ============================================================================
-- TRIGGER 3: UPDATE ORDER STATUS ON SHIPMENT DELIVERY
-- ============================================================================

CREATE OR REPLACE FUNCTION update_order_on_delivery()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.shipment_status = 'delivered' AND OLD.shipment_status != 'delivered' THEN
        UPDATE orders
        SET order_status = 'delivered',
            updated_at = CURRENT_TIMESTAMP
        WHERE order_id = NEW.order_id;
        
        -- Set delivery date if not already set
        IF NEW.delivery_date IS NULL THEN
            NEW.delivery_date := CURRENT_TIMESTAMP;
        END IF;
        
        -- Create notification
        INSERT INTO notification (user_id, event_type, message, timestamp)
        SELECT user_id, 'order_delivered',
               'Your order #' || NEW.order_id || ' has been delivered.',
               CURRENT_TIMESTAMP
        FROM orders
        WHERE order_id = NEW.order_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_on_delivery
BEFORE UPDATE OF shipment_status ON shipment
FOR EACH ROW
EXECUTE FUNCTION update_order_on_delivery();

COMMENT ON TRIGGER trg_update_order_on_delivery ON shipment IS 'Updates order status when shipment is delivered';

-- ============================================================================
-- TRIGGER 4: CREATE NOTIFICATION ON ORDER PLACEMENT
-- ============================================================================

CREATE OR REPLACE FUNCTION create_order_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification (user_id, event_type, message, timestamp)
    VALUES (NEW.user_id, 'order_placed',
            'Your order #' || NEW.order_id || ' has been placed successfully.',
            CURRENT_TIMESTAMP);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_create_order_notification
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION create_order_notification();

COMMENT ON TRIGGER trg_create_order_notification ON orders IS 'Creates notification when order is placed';

-- ============================================================================
-- TRIGGER 5: UPDATE PRODUCT TIMESTAMP
-- ============================================================================

CREATE OR REPLACE FUNCTION update_product_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_product_timestamp
BEFORE UPDATE ON product
FOR EACH ROW
EXECUTE FUNCTION update_product_timestamp();

COMMENT ON TRIGGER trg_update_product_timestamp ON product IS 'Updates timestamp when product is modified';

-- ============================================================================
-- TRIGGER 6: UPDATE CART TIMESTAMP
-- ============================================================================

CREATE OR REPLACE FUNCTION update_cart_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE cart
    SET updated_at = CURRENT_TIMESTAMP
    WHERE cart_id = NEW.cart_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_cart_timestamp
AFTER INSERT OR UPDATE OR DELETE ON cart_item
FOR EACH ROW
EXECUTE FUNCTION update_cart_timestamp();

COMMENT ON TRIGGER trg_update_cart_timestamp ON cart_item IS 'Updates cart timestamp when items change';

-- ============================================================================
-- TRIGGER 7: VALIDATE ORDER TOTAL
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_order_total()
RETURNS TRIGGER AS $$
DECLARE
    v_calculated_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(quantity * price_at_purchase), 0)
    INTO v_calculated_total
    FROM order_item
    WHERE order_id = NEW.order_id;
    
    IF ABS(NEW.total_amount - v_calculated_total) > 0.01 THEN
        RAISE EXCEPTION 'Order total mismatch. Expected: %, Got: %',
            v_calculated_total, NEW.total_amount;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_order_total
BEFORE UPDATE OF total_amount ON orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_total();

COMMENT ON TRIGGER trg_validate_order_total ON orders IS 'Validates order total matches order items';

-- ============================================================================
-- TRIGGER 8: PREVENT DUPLICATE CART ITEMS
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_duplicate_cart_items()
RETURNS TRIGGER AS $$
DECLARE
    v_existing_quantity INTEGER;
BEGIN
    -- Check if product already exists in cart
    SELECT quantity INTO v_existing_quantity
    FROM cart_item
    WHERE cart_id = NEW.cart_id 
      AND product_id = NEW.product_id
      AND cart_item_id != NEW.cart_item_id;
    
    IF FOUND THEN
        -- Update existing item quantity instead of inserting
        UPDATE cart_item
        SET quantity = quantity + NEW.quantity
        WHERE cart_id = NEW.cart_id 
          AND product_id = NEW.product_id
          AND cart_item_id != NEW.cart_item_id;
        
        -- Return NULL to cancel the insert
        RETURN NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_duplicate_cart_items
BEFORE INSERT ON cart_item
FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_cart_items();

COMMENT ON TRIGGER trg_prevent_duplicate_cart_items ON cart_item IS 'Prevents duplicate products in cart';

-- ============================================================================
-- TRIGGER 9: LOG PRICE CHANGES (AUDIT TRIGGER)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price != NEW.price THEN
        INSERT INTO product_price_audit (product_id, old_price, new_price, changed_by)
        VALUES (NEW.product_id, OLD.price, NEW.price, current_user);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_price_change
AFTER UPDATE OF price ON product
FOR EACH ROW
EXECUTE FUNCTION log_price_change();

COMMENT ON TRIGGER trg_log_price_change ON product IS 'Logs product price changes for audit';
