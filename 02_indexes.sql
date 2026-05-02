-- ============================================================================
-- E-COMMERCE DATABASE INDEXES
-- File: 02_indexes.sql
-- Description: Creates indexes for performance optimization
-- Execute Order: 2nd (after schema creation)
-- ============================================================================

-- ============================================================================
-- INDEXES ON FOREIGN KEYS (for JOIN performance)
-- ============================================================================

CREATE INDEX idx_product_seller ON product(seller_id);
CREATE INDEX idx_product_category ON product(category_id);
CREATE INDEX idx_cart_user ON cart(user_id);
CREATE INDEX idx_cart_item_cart ON cart_item(cart_id);
CREATE INDEX idx_cart_item_product ON cart_item(product_id);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_order_item_order ON order_item(order_id);
CREATE INDEX idx_order_item_product ON order_item(product_id);
CREATE INDEX idx_payment_order ON payment(order_id);
CREATE INDEX idx_shipment_order ON shipment(order_id);
CREATE INDEX idx_review_product ON review(product_id);
CREATE INDEX idx_review_user ON review(user_id);
CREATE INDEX idx_notification_user ON notification(user_id);

-- ============================================================================
-- INDEXES ON FREQUENTLY FILTERED COLUMNS
-- ============================================================================

CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_payment_status ON payment(payment_status);
CREATE INDEX idx_shipment_status ON shipment(shipment_status);
CREATE INDEX idx_shipment_tracking ON shipment(tracking_number);
CREATE INDEX idx_notification_timestamp ON notification(timestamp);
CREATE INDEX idx_notification_read ON notification(is_read);

-- ============================================================================
-- COMPOSITE INDEXES (for common query patterns)
-- ============================================================================

CREATE INDEX idx_product_category_price ON product(category_id, price);
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date DESC);
CREATE INDEX idx_notification_user_read ON notification(user_id, is_read);
