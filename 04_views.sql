-- ============================================================================
-- E-COMMERCE DATABASE VIEWS
-- File: 04_views.sql
-- Description: Creates views for simplified data access
-- Execute Order: 4th (after sample data)
-- ============================================================================

-- ============================================================================
-- VIEW 1: ORDER SUMMARY
-- ============================================================================

CREATE VIEW order_summary AS
SELECT 
    o.order_id,
    u.user_id,
    u.name AS customer_name,
    u.email AS customer_email,
    o.order_date,
    o.total_amount,
    o.order_status,
    p.payment_method,
    p.payment_status,
    s.courier_name,
    s.tracking_number,
    s.shipment_status,
    s.delivery_date
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN payment p ON o.order_id = p.order_id
JOIN shipment s ON o.order_id = s.order_id;

COMMENT ON VIEW order_summary IS 'Consolidated view of orders with payment and shipment details';

-- ============================================================================
-- VIEW 2: PRODUCT CATALOG
-- ============================================================================

CREATE VIEW product_catalog AS
SELECT 
    p.product_id,
    p.product_name,
    p.description,
    p.price,
    p.stock_quantity,
    p.image_url,
    s.seller_id,
    s.seller_name,
    s.rating AS seller_rating,
    c.category_id,
    c.category_name
FROM product p
JOIN seller s ON p.seller_id = s.seller_id
JOIN category c ON p.category_id = c.category_id;

COMMENT ON VIEW product_catalog IS 'Complete product listing with seller and category information';
