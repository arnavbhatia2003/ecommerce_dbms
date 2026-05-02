-- ============================================================================
-- E-COMMERCE DATABASE ANALYTICAL QUERIES
-- File: 08_analytical_queries.sql
-- Description: 23 analytical queries demonstrating joins, subqueries, aggregates, and window functions
-- Execute Order: 8th (for testing and reporting)
-- ============================================================================

-- Query 1: Product Catalog with Seller and Category Information
SELECT 
    p.product_id,
    p.product_name,
    p.description,
    p.price,
    p.stock_quantity,
    s.seller_name,
    c.category_name,
    p.image_url
FROM product p
JOIN seller s ON p.seller_id = s.seller_id
JOIN category c ON p.category_id = c.category_id
ORDER BY p.product_id;

-- Query 2: Complete Order Details for a User
SELECT 
    o.order_id,
    o.order_date,
    o.total_amount,
    o.order_status,
    p.payment_method,
    p.payment_status,
    s.courier_name,
    s.tracking_number,
    s.shipment_status
FROM orders o
JOIN payment p ON o.order_id = p.order_id
JOIN shipment s ON o.order_id = s.order_id
WHERE o.user_id = 1
ORDER BY o.order_date DESC;

-- Query 3: Order Items with Product Details
SELECT 
    oi.order_item_id,
    p.product_name,
    oi.quantity,
    oi.price_at_purchase,
    (oi.quantity * oi.price_at_purchase) AS line_total
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
WHERE oi.order_id = 1;

-- Query 4: Total Sales by Category
SELECT 
    c.category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.price_at_purchase) AS total_revenue
FROM category c
JOIN product p ON c.category_id = p.category_id
JOIN order_item oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'cancelled'
GROUP BY c.category_name
ORDER BY total_revenue DESC;

-- Query 5: Average Rating per Product
SELECT 
    p.product_id,
    p.product_name,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.rating), 2) AS average_rating
FROM product p
LEFT JOIN review r ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(r.review_id) > 0
ORDER BY average_rating DESC;

-- Query 6: Seller Performance Metrics
SELECT 
    s.seller_id,
    s.seller_name,
    s.rating AS seller_rating,
    COUNT(DISTINCT p.product_id) AS total_products,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COALESCE(SUM(oi.quantity * oi.price_at_purchase), 0) AS total_revenue
FROM seller s
LEFT JOIN product p ON s.seller_id = p.seller_id
LEFT JOIN order_item oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'cancelled'
GROUP BY s.seller_id, s.seller_name, s.rating
ORDER BY total_revenue DESC NULLS LAST;

-- Query 7: Users Who Have Not Placed Any Orders
SELECT 
    user_id,
    name,
    email,
    phone
FROM users
WHERE user_id NOT IN (
    SELECT DISTINCT user_id FROM orders
);

-- Query 8: Products with Low Stock Levels
SELECT 
    p.product_id,
    p.product_name,
    p.stock_quantity,
    s.seller_name,
    s.contact_email
FROM product p
JOIN seller s ON p.seller_id = s.seller_id
WHERE p.stock_quantity < 25
ORDER BY p.stock_quantity ASC;

-- Query 9: Customers with Above-Average Order Values
SELECT 
    u.user_id,
    u.name,
    u.email,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value,
    (SELECT ROUND(AVG(total_amount), 2) FROM orders WHERE order_status != 'cancelled') AS overall_avg
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.order_status != 'cancelled'
GROUP BY u.user_id, u.name, u.email
HAVING AVG(o.total_amount) > (
    SELECT AVG(total_amount) FROM orders WHERE order_status != 'cancelled'
)
ORDER BY avg_order_value DESC;

-- Query 10: Top 5 Best-Selling Products
SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS total_quantity_sold,
    COUNT(DISTINCT oi.order_id) AS number_of_orders
FROM product p
JOIN order_item oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'cancelled'
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC
LIMIT 5;

-- Query 11: Rank Products by Sales Within Each Category (Window Function)
SELECT 
    c.category_name,
    p.product_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.price_at_purchase) AS total_revenue,
    RANK() OVER (
        PARTITION BY c.category_id 
        ORDER BY SUM(oi.quantity) DESC
    ) AS sales_rank_in_category,
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY c.category_id 
            ORDER BY SUM(oi.quantity) DESC
        )::NUMERIC, 
        2
    ) AS percentile_rank
FROM category c
JOIN product p ON c.category_id = p.category_id
JOIN order_item oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status != 'cancelled'
GROUP BY c.category_name, c.category_id, p.product_name
ORDER BY c.category_name, sales_rank_in_category;

-- Query 12: Running Total of Daily Sales (Window Function)
SELECT 
    DATE(order_date) AS sale_date,
    COUNT(order_id) AS daily_orders,
    SUM(total_amount) AS daily_revenue,
    SUM(SUM(total_amount)) OVER (
        ORDER BY DATE(order_date)
    ) AS cumulative_revenue,
    ROUND(
        AVG(SUM(total_amount)) OVER (
            ORDER BY DATE(order_date) 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 
        2
    ) AS moving_avg_7day
FROM orders
WHERE order_status != 'cancelled'
GROUP BY DATE(order_date)
ORDER BY sale_date;

-- Query 13: Customer Lifetime Value with Ranking (Window Function)
SELECT 
    u.user_id,
    u.name,
    u.email,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS lifetime_value,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS customer_rank,
    NTILE(4) OVER (ORDER BY SUM(o.total_amount) DESC) AS customer_quartile
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.order_status != 'cancelled'
GROUP BY u.user_id, u.name, u.email
ORDER BY lifetime_value DESC;

-- Query 14: Orders for a Specific Seller
SELECT DISTINCT
    o.order_id,
    o.order_date,
    u.name AS customer_name,
    u.email AS customer_email,
    o.order_status,
    SUM(oi.quantity * oi.price_at_purchase) AS seller_revenue
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
JOIN users u ON o.user_id = u.user_id
WHERE p.seller_id = 1
GROUP BY o.order_id, o.order_date, u.name, u.email, o.order_status
ORDER BY o.order_date DESC;

-- Query 15: Products Never Ordered
SELECT 
    p.product_id,
    p.product_name,
    p.price,
    p.stock_quantity,
    s.seller_name
FROM product p
JOIN seller s ON p.seller_id = s.seller_id
WHERE NOT EXISTS (
    SELECT 1 
    FROM order_item oi 
    WHERE oi.product_id = p.product_id
)
ORDER BY p.product_id;

-- Query 16: Monthly Sales Report
SELECT 
    TO_CHAR(order_date, 'YYYY-MM') AS month,
    COUNT(order_id) AS total_orders,
    SUM(total_amount) AS monthly_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    COUNT(DISTINCT user_id) AS unique_customers
FROM orders
WHERE order_status != 'cancelled'
GROUP BY TO_CHAR(order_date, 'YYYY-MM')
ORDER BY month DESC;

-- Query 17: Order Status Distribution
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- Query 18: Payment Method Preferences
SELECT 
    payment_method,
    COUNT(*) AS usage_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) AS percentage,
    SUM(o.total_amount) AS total_transaction_value
FROM payment p
JOIN orders o ON p.order_id = o.order_id
WHERE o.order_status != 'cancelled'
GROUP BY payment_method
ORDER BY usage_count DESC;

-- Query 19: Courier Performance Analysis
SELECT 
    courier_name,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN shipment_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_count,
    ROUND(
        SUM(CASE WHEN shipment_status = 'delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS delivery_success_rate,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (delivery_date - o.order_date)) / 86400), 
        1
    ) AS avg_delivery_days
FROM shipment s
JOIN orders o ON s.order_id = o.order_id
WHERE s.delivery_date IS NOT NULL
GROUP BY courier_name
ORDER BY delivery_success_rate DESC;

-- Query 20: Product Review Analysis
SELECT 
    rating,
    COUNT(*) AS review_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) AS percentage
FROM review
GROUP BY rating
ORDER BY rating DESC;

-- Query 21: Cart Abandonment Analysis
SELECT 
    u.user_id,
    u.name,
    u.email,
    COUNT(ci.cart_item_id) AS items_in_cart,
    SUM(ci.quantity * p.price) AS cart_value,
    MAX(ci.added_at) AS last_cart_update,
    COALESCE(MAX(o.order_date), '1970-01-01'::TIMESTAMP) AS last_order_date
FROM users u
JOIN cart c ON u.user_id = c.user_id
JOIN cart_item ci ON c.cart_id = ci.cart_id
JOIN product p ON ci.product_id = p.product_id
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id, u.name, u.email
HAVING COUNT(ci.cart_item_id) > 0
ORDER BY cart_value DESC;

-- Query 22: Product Profitability Analysis
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.price_at_purchase) AS total_revenue,
    ROUND(AVG(oi.price_at_purchase), 2) AS avg_selling_price,
    p.price AS current_price
FROM product p
JOIN category c ON p.category_id = c.category_id
LEFT JOIN order_item oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status != 'cancelled'
GROUP BY p.product_id, p.product_name, c.category_name, p.price
ORDER BY total_revenue DESC NULLS LAST;

-- Query 23: Customer Segmentation by Order Frequency
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spent), 2) AS avg_lifetime_value,
    ROUND(AVG(order_count), 1) AS avg_orders_per_customer
FROM (
    SELECT 
        u.user_id,
        u.name,
        COUNT(o.order_id) AS order_count,
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        CASE 
            WHEN COUNT(o.order_id) >= 5 THEN 'VIP Customer'
            WHEN COUNT(o.order_id) >= 3 THEN 'Regular Customer'
            WHEN COUNT(o.order_id) >= 1 THEN 'Occasional Customer'
            ELSE 'New Customer'
        END AS customer_segment
    FROM users u
    LEFT JOIN orders o ON u.user_id = o.user_id AND o.order_status != 'cancelled'
    GROUP BY u.user_id, u.name
) customer_stats
GROUP BY customer_segment
ORDER BY 
    CASE customer_segment
        WHEN 'VIP Customer' THEN 1
        WHEN 'Regular Customer' THEN 2
        WHEN 'Occasional Customer' THEN 3
        ELSE 4
    END;
