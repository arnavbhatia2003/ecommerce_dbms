-- ============================================================================
-- E-COMMERCE DATABASE SAMPLE DATA
-- File: 03_sample_data.sql
-- Description: Inserts sample data into all tables
-- Execute Order: 3rd (after schema and indexes)
-- ============================================================================

-- ============================================================================
-- INSERT USERS
-- ============================================================================

INSERT INTO users (name, email, phone, address, password) VALUES
('Arnav Bhatia', 'arnav.bhatia@example.com', '9876543210', '123 MG Road, Delhi', 'pass123'),
('Sukhesh Garg', 'sukhesh.garg@example.com', '9876543211', '456 Park Street, Mumbai', 'pass456'),
('Niloy Sharma', 'niloy.sharma@example.com', '9876543212', '789 Brigade Road, Bangalore', 'pass789'),
('Priya Singh', 'priya.singh@example.com', '9876543213', '321 Anna Salai, Chennai', 'pass321'),
('Rahul Verma', 'rahul.verma@example.com', '9876543214', '654 MG Road, Pune', 'pass654');

-- ============================================================================
-- INSERT SELLERS
-- ============================================================================

INSERT INTO seller (seller_name, contact_email, rating) VALUES
('TechGadgets Inc', 'contact@techgadgets.com', 4.5),
('Fashion Hub', 'support@fashionhub.com', 4.2),
('Home Essentials', 'info@homeessentials.com', 4.7),
('Sports World', 'sales@sportsworld.com', 4.0),
('Book Paradise', 'hello@bookparadise.com', 4.8);

-- ============================================================================
-- INSERT CATEGORIES
-- ============================================================================

INSERT INTO category (category_name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Clothing', 'Fashion and apparel'),
('Home & Kitchen', 'Home appliances and kitchen items'),
('Sports & Fitness', 'Sports equipment and fitness gear'),
('Books', 'Books and literature');

-- ============================================================================
-- INSERT PRODUCTS
-- ============================================================================

INSERT INTO product (seller_id, category_id, product_name, description, price, stock_quantity, image_url) VALUES
(1, 1, 'Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 599.00, 50, 'https://example.com/images/mouse.jpg'),
(1, 1, 'Bluetooth Keyboard', 'Mechanical keyboard with RGB backlight', 2499.00, 30, 'https://example.com/images/keyboard.jpg'),
(2, 2, 'Cotton T-Shirt', 'Premium cotton t-shirt in multiple colors', 499.00, 100, 'https://example.com/images/tshirt.jpg'),
(2, 2, 'Denim Jeans', 'Slim fit denim jeans', 1299.00, 75, 'https://example.com/images/jeans.jpg'),
(3, 3, 'Non-Stick Pan', '24cm non-stick frying pan', 899.00, 40, 'https://example.com/images/pan.jpg'),
(3, 3, 'Mixer Grinder', '750W mixer grinder with 3 jars', 3499.00, 20, 'https://example.com/images/mixer.jpg'),
(4, 4, 'Yoga Mat', 'Anti-slip yoga mat with carrying strap', 799.00, 60, 'https://example.com/images/yogamat.jpg'),
(4, 4, 'Dumbbells Set', '5kg dumbbells pair', 1499.00, 35, 'https://example.com/images/dumbbells.jpg'),
(5, 5, 'The Great Gatsby', 'Classic novel by F. Scott Fitzgerald', 299.00, 80, 'https://example.com/images/gatsby.jpg'),
(5, 5, 'To Kill a Mockingbird', 'Pulitzer Prize winning novel', 349.00, 70, 'https://example.com/images/mockingbird.jpg');

-- ============================================================================
-- INSERT CARTS
-- ============================================================================

INSERT INTO cart (user_id, created_date) VALUES
(1, CURRENT_TIMESTAMP),
(2, CURRENT_TIMESTAMP),
(3, CURRENT_TIMESTAMP);

-- ============================================================================
-- INSERT CART ITEMS
-- ============================================================================

INSERT INTO cart_item (cart_id, product_id, quantity) VALUES
(1, 1, 2),
(1, 3, 1),
(2, 5, 1),
(2, 7, 2),
(3, 9, 3),
(3, 10, 1);

-- ============================================================================
-- INSERT ORDERS
-- ============================================================================

INSERT INTO orders (user_id, order_date, total_amount, order_status) VALUES
(1, CURRENT_TIMESTAMP - INTERVAL '5 days', 2997.00, 'delivered'),
(2, CURRENT_TIMESTAMP - INTERVAL '3 days', 1598.00, 'shipped'),
(3, CURRENT_TIMESTAMP - INTERVAL '2 days', 1198.00, 'confirmed'),
(4, CURRENT_TIMESTAMP - INTERVAL '1 day', 3499.00, 'pending'),
(5, CURRENT_TIMESTAMP, 648.00, 'pending');

-- ============================================================================
-- INSERT ORDER ITEMS
-- ============================================================================

INSERT INTO order_item (order_id, product_id, quantity, price_at_purchase) VALUES
(1, 2, 1, 2499.00),
(1, 3, 1, 499.00),
(2, 5, 1, 899.00),
(2, 7, 1, 799.00),
(3, 1, 2, 599.00),
(4, 6, 1, 3499.00),
(5, 9, 1, 299.00),
(5, 10, 1, 349.00);

-- ============================================================================
-- INSERT PAYMENTS
-- ============================================================================

INSERT INTO payment (order_id, payment_method, payment_status, payment_date) VALUES
(1, 'credit_card', 'completed', CURRENT_TIMESTAMP - INTERVAL '5 days'),
(2, 'upi', 'completed', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(3, 'debit_card', 'completed', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(4, 'net_banking', 'pending', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(5, 'cash_on_delivery', 'pending', CURRENT_TIMESTAMP);

-- ============================================================================
-- INSERT SHIPMENTS
-- ============================================================================

INSERT INTO shipment (order_id, courier_name, tracking_number, shipment_status, delivery_date) VALUES
(1, 'BlueDart', 'BD123456789', 'delivered', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(2, 'DTDC', 'DT987654321', 'in_transit', NULL),
(3, 'Delhivery', 'DL456789123', 'pending', NULL),
(4, 'FedEx', 'FX789123456', 'pending', NULL),
(5, 'India Post', 'IP321654987', 'pending', NULL);

-- ============================================================================
-- INSERT REVIEWS
-- ============================================================================

INSERT INTO review (product_id, user_id, rating, comment, review_date) VALUES
(2, 1, 5, 'Excellent keyboard, great build quality!', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(3, 1, 4, 'Good quality t-shirt, fits well.', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(5, 2, 5, 'Best non-stick pan I have used!', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(7, 2, 4, 'Comfortable yoga mat, good grip.', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(1, 3, 3, 'Mouse works fine but battery drains quickly.', CURRENT_TIMESTAMP);

-- ============================================================================
-- INSERT NOTIFICATIONS
-- ============================================================================

INSERT INTO notification (user_id, event_type, message, timestamp, is_read) VALUES
(1, 'order_placed', 'Your order #1 has been placed successfully.', CURRENT_TIMESTAMP - INTERVAL '5 days', TRUE),
(1, 'order_delivered', 'Your order #1 has been delivered.', CURRENT_TIMESTAMP - INTERVAL '2 days', TRUE),
(2, 'order_placed', 'Your order #2 has been placed successfully.', CURRENT_TIMESTAMP - INTERVAL '3 days', TRUE),
(2, 'shipment_dispatched', 'Your order #2 has been dispatched.', CURRENT_TIMESTAMP - INTERVAL '3 days', FALSE),
(3, 'payment_received', 'Payment received for order #3.', CURRENT_TIMESTAMP - INTERVAL '2 days', FALSE);
