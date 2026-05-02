# E-Commerce Database Management System - SQL Scripts

Complete PostgreSQL database implementation for a multi-vendor e-commerce platform.

## 📋 Project Overview

This project implements a comprehensive e-commerce database system with:
- **12 normalized tables** (3NF)
- **23 performance indexes**
- **5 stored functions**
- **3 stored procedures** (including cursor-based batch processing)
- **9 triggers** for automated business rules
- **2 views** for simplified data access
- **23 analytical queries** (joins, subqueries, aggregates, window functions)
- **10 transaction demonstrations** (COMMIT, ROLLBACK, SAVEPOINT, isolation levels)

## 🗂️ File Structure

Execute the SQL files in the following order:

| Order | File | Description |
|-------|------|-------------|
| 1 | `01_schema_creation.sql` | Creates all 12 tables with constraints |
| 2 | `02_indexes.sql` | Creates 23 indexes for performance optimization |
| 3 | `03_sample_data.sql` | Inserts sample data into all tables |
| 4 | `04_views.sql` | Creates 2 views for simplified queries |
| 5 | `05_functions.sql` | Creates 5 stored functions |
| 6 | `06_procedures.sql` | Creates 3 stored procedures |
| 7 | `07_triggers.sql` | Creates 9 triggers for business rules |
| 8 | `08_analytical_queries.sql` | 23 analytical queries for testing |
| 9 | `09_transactions.sql` | 10 transaction demonstrations |

## 🚀 Quick Start

### Prerequisites
- PostgreSQL 12 or higher
- pgAdmin 4 (optional, for GUI)

### Installation Steps

1. **Create Database**
```sql
CREATE DATABASE ecommerce_db;
\c ecommerce_db
```

2. **Execute Scripts in Order**
```bash
psql -U postgres -d ecommerce_db -f 01_schema_creation.sql
psql -U postgres -d ecommerce_db -f 02_indexes.sql
psql -U postgres -d ecommerce_db -f 03_sample_data.sql
psql -U postgres -d ecommerce_db -f 04_views.sql
psql -U postgres -d ecommerce_db -f 05_functions.sql
psql -U postgres -d ecommerce_db -f 06_procedures.sql
psql -U postgres -d ecommerce_db -f 07_triggers.sql
```

3. **Test with Analytical Queries**
```bash
psql -U postgres -d ecommerce_db -f 08_analytical_queries.sql
```

4. **Test Transactions**
```bash
psql -U postgres -d ecommerce_db -f 09_transactions.sql
```

## 📊 Database Schema

### Core Tables
- **users** - Customer accounts
- **seller** - Seller profiles
- **category** - Product categories
- **product** - Product catalog
- **cart** - Shopping carts
- **cart_item** - Cart line items
- **orders** - Customer orders
- **order_item** - Order line items
- **payment** - Payment transactions
- **shipment** - Delivery tracking
- **review** - Product reviews
- **notification** - System notifications

### Audit Tables
- **product_price_audit** - Price change history

## 🔧 Key Features

### Stored Procedures
1. **place_order()** - Complete order placement with inventory management
2. **update_product_stock()** - Stock updates with validation
3. **process_pending_shipments()** - Batch shipment processing with cursor

### Stored Functions
1. **calculate_order_total()** - Calculate order total
2. **get_product_avg_rating()** - Get average product rating
3. **get_seller_revenue()** - Calculate seller revenue
4. **check_product_availability()** - Check stock availability
5. **get_user_order_count()** - Get user's order count

### Triggers
1. **trg_check_stock_quantity** - Prevent negative stock
2. **trg_update_order_on_payment** - Auto-update order status on payment
3. **trg_update_order_on_delivery** - Auto-update order status on delivery
4. **trg_create_order_notification** - Auto-create order notifications
5. **trg_update_product_timestamp** - Auto-update product timestamps
6. **trg_update_cart_timestamp** - Auto-update cart timestamps
7. **trg_validate_order_total** - Validate order totals
8. **trg_prevent_duplicate_cart_items** - Prevent duplicate cart items
9. **trg_log_price_change** - Audit price changes

### Views
1. **order_summary** - Consolidated order information
2. **product_catalog** - Complete product listings

## 📈 Sample Queries

### Get Product Catalog
```sql
SELECT * FROM product_catalog ORDER BY product_id;
```

### Get Order Summary
```sql
SELECT * FROM order_summary WHERE user_id = 1;
```

### Calculate Seller Revenue
```sql
SELECT seller_id, seller_name, get_seller_revenue(seller_id) AS revenue
FROM seller
ORDER BY revenue DESC;
```

### Place an Order
```sql
SELECT place_order(4, 'credit_card', 'BlueDart');
```

## 🧪 Testing

### Test Functions
```sql
SELECT calculate_order_total(1);
SELECT get_product_avg_rating(2);
SELECT check_product_availability(1, 10);
```

### Test Procedures
```sql
SELECT place_order(4, 'credit_card', 'BlueDart');
SELECT update_product_stock(1, 10);
SELECT process_pending_shipments();
```

### Test Triggers
```sql
-- Test stock validation (should fail)
UPDATE product SET stock_quantity = -5 WHERE product_id = 1;

-- Test payment trigger
UPDATE payment SET payment_status = 'completed' WHERE order_id = 4;
```

## 📝 Transaction Examples

### Successful Transaction
```sql
BEGIN;
INSERT INTO orders (user_id, order_date, total_amount, order_status)
VALUES (5, CURRENT_TIMESTAMP, 1798.00, 'pending');
COMMIT;
```

### Rollback Transaction
```sql
BEGIN;
UPDATE product SET price = 9999.99 WHERE product_id = 1;
ROLLBACK;
```

### Savepoint Example
```sql
BEGIN;
UPDATE product SET stock_quantity = stock_quantity + 50 WHERE product_id = 1;
SAVEPOINT after_update;
UPDATE product SET stock_quantity = stock_quantity + 100 WHERE product_id = 2;
ROLLBACK TO SAVEPOINT after_update;
COMMIT;
```

## 🔒 ACID Properties

All transactions demonstrate:
- **Atomicity** - All-or-nothing execution
- **Consistency** - Data integrity maintained
- **Isolation** - Concurrent transaction handling
- **Durability** - Permanent changes after commit

## 📚 Documentation

For detailed documentation, see:
- [Database Creation Guide](../DATABASE_CREATION_GUIDE.md)
- [Complete Project Guide](../COMPLETE_PROJECT_GUIDE.md)
- [ER Diagram](../ER_DIAGRAM.dbml)

## 👥 Contributors

- Arnav Bhatia (1024030420)
- Sukhesh Garg (1024030421)
- Niloy Sharma (1024030422)

## 📄 License

This project is created for educational purposes as part of UCS310 - Database Management Systems course.

## 🤝 Contributing

This is an academic project. For suggestions or improvements, please contact the contributors.

## ⚠️ Notes

- All passwords are stored in plain text for demonstration purposes only
- Sample data uses placeholder URLs for images
- Designed for PostgreSQL 12+
- Execute scripts in the specified order for proper setup
