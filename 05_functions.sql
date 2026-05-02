-- ============================================================================
-- E-COMMERCE DATABASE FUNCTIONS
-- File: 05_functions.sql
-- Description: Creates stored functions for calculations and checks
-- Execute Order: 5th (after views)
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: CALCULATE ORDER TOTAL
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INTEGER)
RETURNS NUMERIC(10,2) AS $$
DECLARE
    v_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(quantity * price_at_purchase), 0)
    INTO v_total
    FROM order_item
    WHERE order_id = p_order_id;
    
    RETURN v_total;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error calculating order total: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_order_total IS 'Calculates total amount for an order';

-- ============================================================================
-- FUNCTION 2: GET PRODUCT AVERAGE RATING
-- ============================================================================

CREATE OR REPLACE FUNCTION get_product_avg_rating(p_product_id INTEGER)
RETURNS NUMERIC(3,2) AS $$
DECLARE
    v_avg_rating NUMERIC(3,2);
BEGIN
    SELECT COALESCE(AVG(rating), 0)
    INTO v_avg_rating
    FROM review
    WHERE product_id = p_product_id;
    
    RETURN ROUND(v_avg_rating, 2);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_product_avg_rating IS 'Returns average rating for a product';

-- ============================================================================
-- FUNCTION 3: GET SELLER TOTAL REVENUE
-- ============================================================================

CREATE OR REPLACE FUNCTION get_seller_revenue(p_seller_id INTEGER)
RETURNS NUMERIC(10,2) AS $$
DECLARE
    v_revenue NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(oi.quantity * oi.price_at_purchase), 0)
    INTO v_revenue
    FROM order_item oi
    JOIN product p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE p.seller_id = p_seller_id
      AND o.order_status NOT IN ('cancelled', 'pending');
    
    RETURN v_revenue;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error calculating seller revenue: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_seller_revenue IS 'Calculates total revenue for a seller';

-- ============================================================================
-- FUNCTION 4: CHECK PRODUCT AVAILABILITY
-- ============================================================================

CREATE OR REPLACE FUNCTION check_product_availability(
    p_product_id INTEGER,
    p_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock_quantity INTO v_stock
    FROM product
    WHERE product_id = p_product_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    RETURN v_stock >= p_quantity;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_product_availability IS 'Checks if product has sufficient stock';

-- ============================================================================
-- FUNCTION 5: GET USER ORDER COUNT
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_order_count(p_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM orders
    WHERE user_id = p_user_id;
    
    RETURN v_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_user_order_count IS 'Returns total order count for a user';
