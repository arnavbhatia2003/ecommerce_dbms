-- ============================================================================
-- E-COMMERCE DATABASE SCHEMA CREATION
-- File: 01_schema_creation.sql
-- Description: Creates all 13 tables with constraints and comments
-- Execute Order: 1st
-- ============================================================================

-- ============================================================================
-- DROP EXISTING TABLES (if re-running script)
-- ============================================================================

DROP TABLE IF EXISTS notification CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS shipment CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_item CASCADE;
DROP TABLE IF EXISTS cart CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS seller CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================================
-- CREATE TABLES
-- ============================================================================

-- Table 1: USERS
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'Stores customer account information with authentication credentials';

-- Table 2: SELLER
CREATE TABLE seller (
    seller_id SERIAL PRIMARY KEY,
    seller_name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255) UNIQUE NOT NULL,
    rating NUMERIC(3,2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE seller IS 'Stores seller profiles and ratings';

-- Table 3: CATEGORY
CREATE TABLE category (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE category IS 'Organizes products into classifications';

-- Table 4: PRODUCT
CREATE TABLE product (
    product_id SERIAL PRIMARY KEY,
    seller_id INTEGER NOT NULL REFERENCES seller(seller_id) ON DELETE RESTRICT,
    category_id INTEGER NOT NULL REFERENCES category(category_id) ON DELETE RESTRICT,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    image_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE product IS 'Stores product catalog with pricing and inventory';

-- Table 5: CART
CREATE TABLE cart (
    cart_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE cart IS 'Stores active shopping carts for users (one cart per user)';

-- Table 6: CART_ITEM
CREATE TABLE cart_item (
    cart_item_id SERIAL PRIMARY KEY,
    cart_id INTEGER NOT NULL REFERENCES cart(cart_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    -- NOTE: No UNIQUE(cart_id, product_id) constraint here.
    -- Duplicate prevention is handled by trg_prevent_duplicate_cart_items trigger,
    -- which merges quantities instead of raising an error.
);

COMMENT ON TABLE cart_item IS 'Stores line items in shopping carts';

-- Table 7: ORDERS
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    order_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    order_status VARCHAR(50) NOT NULL DEFAULT 'pending' 
        CHECK (order_status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE orders IS 'Stores customer orders';

-- Table 8: ORDER_ITEM
CREATE TABLE order_item (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_at_purchase NUMERIC(10,2) NOT NULL CHECK (price_at_purchase > 0)
);

COMMENT ON TABLE order_item IS 'Stores line items in orders with historical pricing';

-- Table 9: PAYMENT
CREATE TABLE payment (
    payment_id SERIAL PRIMARY KEY,
    order_id INTEGER UNIQUE NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    payment_method VARCHAR(50) NOT NULL 
        CHECK (payment_method IN ('credit_card', 'debit_card', 'upi', 'net_banking', 'cash_on_delivery')),
    payment_status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    payment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE payment IS 'Records payment transactions (1:1 with orders)';

-- Table 10: SHIPMENT
CREATE TABLE shipment (
    shipment_id SERIAL PRIMARY KEY,
    order_id INTEGER UNIQUE NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    courier_name VARCHAR(255) NOT NULL,
    tracking_number VARCHAR(255) UNIQUE NOT NULL,
    shipment_status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (shipment_status IN ('pending', 'in_transit', 'out_for_delivery', 'delivered', 'returned')),
    delivery_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE shipment IS 'Tracks order deliveries (1:1 with orders)';

-- Table 11: REVIEW
CREATE TABLE review (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    review_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, user_id)
);

COMMENT ON TABLE review IS 'Stores customer product reviews and ratings';

-- Table 12: NOTIFICATION
CREATE TABLE notification (
    notification_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL 
        CHECK (event_type IN ('order_placed', 'payment_received', 'shipment_dispatched', 'order_delivered')),
    message TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE
);

COMMENT ON TABLE notification IS 'Logs system events for audit trail';

-- Audit table for price changes
CREATE TABLE IF NOT EXISTS product_price_audit (
    audit_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    old_price NUMERIC(10,2),
    new_price NUMERIC(10,2),
    changed_by VARCHAR(255),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE product_price_audit IS 'Audit trail for product price changes';
