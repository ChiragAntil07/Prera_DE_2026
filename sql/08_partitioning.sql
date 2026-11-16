
-- ============================================================
-- ZOMATO FOOD DELIVERY DATABASE
-- CP4: TABLE PARTITIONING DEMONSTRATION
-- Team ID: T0042
-- Database: zomato_db
-- Schema: zomato
-- PostgreSQL 18
-- ============================================================

SET search_path TO zomato, public;

-- This is a separate demonstration table.
-- The original orders table remains unchanged.

-- 1. CREATE PARTITIONED ORDERS TABLE

CREATE TABLE IF NOT EXISTS orders_partitioned_demo (
    order_id INTEGER NOT NULL,
    customer_id INTEGER,
    restaurant_id INTEGER,
    partner_id INTEGER,
    coupon_code VARCHAR(50),
    placed_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    status VARCHAR(50),
    total_amount NUMERIC(10,2),
    delivery_fee NUMERIC(10,2),

    PRIMARY KEY (order_id, placed_at)

) PARTITION BY RANGE (placed_at);


-- 2. CREATE MONTHLY PARTITIONS (JAN 2025 - JUN 2026)

CREATE TABLE IF NOT EXISTS orders_demo_2025_01
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_02
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_03
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_04
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_05
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_06
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_07
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_08
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_09
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_10
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_11
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE IF NOT EXISTS orders_demo_2025_12
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_01
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_02
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_03
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_04
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_05
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS orders_demo_2026_06
PARTITION OF orders_partitioned_demo
FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- 3. DEFAULT PARTITION FOR OTHER DATES

CREATE TABLE IF NOT EXISTS orders_demo_default
PARTITION OF orders_partitioned_demo DEFAULT;

-- Clear previous demonstration data before reloading
TRUNCATE TABLE zomato.orders_partitioned_demo;

-- 4. LOAD EXISTING ORDERS

INSERT INTO zomato.orders_partitioned_demo (
    order_id,
    customer_id,
    restaurant_id,
    partner_id,
    coupon_code,
    placed_at,
    accepted_at,
    delivered_at,
    status,
    total_amount,
    delivery_fee
)
SELECT
    order_id,
    customer_id,
    restaurant_id,
    partner_id,
    coupon_code,
    placed_at,
    accepted_at,
    delivered_at,
    status,
    total_amount,
    delivery_fee
FROM zomato.orders;

-- 5. VERIFY PARTITIONED DATA

SELECT COUNT(*) AS original_orders
FROM zomato.orders;

SELECT COUNT(*) AS partitioned_orders
FROM zomato.orders_partitioned_demo;
