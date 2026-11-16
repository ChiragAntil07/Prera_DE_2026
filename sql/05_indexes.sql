-- =====================================================================
-- ZOMATO FOOD DELIVERY DATABASE — CP3 OPTIMIZATION
-- Deliverable 1: sql/05_indexes.sql
--
-- Team ID: T0042
-- Target Database: zomato_db (PostgreSQL 18)
-- Schema: zomato
-- =====================================================================

SET search_path TO zomato, public;

-- Enable trigram extension for efficient substring ILIKE searches (R02, R18)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =====================================================================
-- 1. LOCALITIES & RESTAURANTS
-- =====================================================================

-- Supports: R02, R08, R09, R19, R22, R25
-- Why B-Tree on city_id: Enables rapid index scan/lookup for city-level filtering
-- (e.g., city_id = 1 for Bengaluru, city_id = 6 for Pune) avoiding full table scans.
CREATE INDEX IF NOT EXISTS idx_localities_city_id
ON zomato.localities (city_id);

-- Supports: R01
-- Why B-Tree on locality_name: Equality filter 'Koramangala' instantly resolves
-- locality_id to join restaurants without scanning the localities table.
CREATE INDEX IF NOT EXISTS idx_localities_name
ON zomato.localities (locality_name);

-- Supports: R01, R08, R09, R19, R22, R25
-- Why Composite B-Tree (locality_id, status, rating DESC):
-- Places equality filter on locality_id first, then status ('OPEN'), followed by
-- rating DESC to fulfill ORDER BY rating DESC without an explicit sort step.
CREATE INDEX IF NOT EXISTS idx_restaurants_locality_status
ON zomato.restaurants (locality_id, status, rating DESC);

-- Supports: R25
-- Why GIN Index on cuisines (TEXT[]):
-- R25 checks 'Chinese' = ANY (r.cuisines). A GIN index on array elements enables
-- bitmap index scan on specific cuisines rather than sequentially scanning all restaurants.
CREATE INDEX IF NOT EXISTS idx_restaurants_cuisines_gin
ON zomato.restaurants USING gin (cuisines);

-- =====================================================================
-- 2. MENU ITEMS
-- =====================================================================

-- Supports: R03, R07, W03
-- Why Composite B-Tree (restaurant_id, category, is_bestseller DESC, item_name):
-- restaurant_id is an equality filter, followed by category and sort columns.
-- This index satisfies R03's WHERE and ORDER BY completely and speeds up W03's category updates.
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant
ON zomato.menu_items (restaurant_id, category, is_bestseller DESC, item_name);

-- Supports: R02
-- Why Partial GIN Trigram Index on item_name WHERE is_available:
-- Accelerates ILIKE '%paneer%' substring pattern matching. Restricted to available items
-- (is_available = true) to minimize index size and maintenance overhead.
CREATE INDEX IF NOT EXISTS idx_menu_items_name_trgm
ON zomato.menu_items USING gin (item_name gin_trgm_ops)
WHERE is_available;

-- =====================================================================
-- 3. ORDERS
-- =====================================================================

-- Supports: R04, R14, R20, R21
-- Why Composite B-Tree (customer_id, placed_at DESC):
-- Matches the customer order history lookup pattern (customer_id = X ORDER BY placed_at DESC)
-- allowing index scan directly delivering top-10 rows with zero in-memory sort.
CREATE INDEX IF NOT EXISTS idx_orders_customer_placed
ON zomato.orders (customer_id, placed_at DESC);

-- Supports: R06, R07, R08, R09, R19, R22
-- Why Composite B-Tree (restaurant_id, placed_at DESC):
-- Restricts scans to orders belonging to a single restaurant ordered chronologically,
-- eliminating 150,000-row sequential scans for restaurant analytics and partner portals.
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_placed
ON zomato.orders (restaurant_id, placed_at DESC);

-- Supports: R09, R10, R21, R22, R23
-- Why B-Tree (placed_at DESC):
-- Supports system-wide date range filtering and provides pre-sorted order traversal
-- for high-offset pagination (R23) without needing in-memory sorting of 150k rows.
CREATE INDEX IF NOT EXISTS idx_orders_placed_at_desc
ON zomato.orders (placed_at DESC);

-- Supports: R11, R13
-- Why Covering B-Tree (partner_id, status, placed_at) INCLUDE (delivery_fee):
-- Equality on partner_id and status ('DELIVERED'), range on placed_at, with delivery_fee
-- included as payload to enable an Index Only Scan without visiting table heap.
CREATE INDEX IF NOT EXISTS idx_orders_partner_status_placed
ON zomato.orders (partner_id, status, placed_at)
INCLUDE (delivery_fee);

-- Supports: R05
-- Why Partial B-Tree (accepted_at) WHERE status = 'PREPARING':
-- Active orders in 'PREPARING' represent a tiny fraction (37 out of 150,000 rows, <0.03%).
-- Indexing only this rare status produces a microscopic 16 kB index for instant alerts.
CREATE INDEX IF NOT EXISTS idx_orders_preparing_partial
ON zomato.orders (accepted_at)
WHERE status = 'PREPARING';

-- Supports: R12, W02
-- Why Partial B-Tree (status, placed_at) WHERE partner_id IS NULL:
-- Unassigned orders needing partner dispatch are rare. Indexing only rows where
-- partner_id IS NULL enables sub-millisecond retrieval of oldest unassigned orders.
CREATE INDEX IF NOT EXISTS idx_orders_unassigned_dispatch
ON zomato.orders (status, placed_at)
WHERE partner_id IS NULL;

-- Supports: R15
-- Why Partial B-Tree (coupon_code) WHERE status = 'DELIVERED':
-- Filters out non-delivered orders and null coupons, accelerating marketing coupon aggregation.
CREATE INDEX IF NOT EXISTS idx_orders_delivered_coupons
ON zomato.orders (coupon_code)
WHERE status = 'DELIVERED';

-- =====================================================================
-- 4. ORDER ITEMS
-- =====================================================================

-- Supports: R07, R08, R24
-- Why Covering B-Tree on (order_id) INCLUDE (item_id, quantity, unit_price):
-- The order_items table (375,000 rows) had zero non-PK indexes in baseline, forcing full
-- sequential scans on every join from orders. Adding this covering index enables direct index
-- seeks with payload included, avoiding heap fetches.
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
ON zomato.order_items (order_id)
INCLUDE (item_id, quantity, unit_price);

-- =====================================================================
-- 5. PAYMENTS
-- =====================================================================

-- Supports: R24
-- Why Covering Partial B-Tree on (order_id) INCLUDE (method) WHERE payment_status = 'SUCCESS':
-- Bill generation looks up successful payment details for a specific order_id.
-- This partial covering index provides direct single-page index lookup.
CREATE INDEX IF NOT EXISTS idx_payments_order_id_success
ON zomato.payments (order_id)
INCLUDE (method)
WHERE payment_status = 'SUCCESS';

-- Supports: R16
-- Why Partial B-Tree on (attempted_at, method) WHERE payment_status = 'FAILED':
-- Failed payments represent only ~5% of transactions (6,965 rows). This partial index
-- avoids scanning the entire 137k-row payments table for failed payment reports.
CREATE INDEX IF NOT EXISTS idx_payments_failed_partial
ON zomato.payments (attempted_at, method)
WHERE payment_status = 'FAILED';

-- Supports: R17
-- Why Partial B-Tree on (order_id) WHERE payment_status = 'FAILED':
-- Risk team query joins orders and payments on order_id for failed attempts.
-- Indexing order_id on failed rows dramatically speeds up join and aggregation.
CREATE INDEX IF NOT EXISTS idx_payments_failed_order
ON zomato.payments (order_id)
WHERE payment_status = 'FAILED';

-- =====================================================================
-- 6. REVIEWS
-- =====================================================================

-- Supports: R19, W04
-- Why Composite B-Tree on (restaurant_id, food_rating):
-- Groups reviews by restaurant and includes food_rating to compute restaurant average ratings
-- without table heap scans.
CREATE INDEX IF NOT EXISTS idx_reviews_restaurant
ON zomato.reviews (restaurant_id, food_rating);

-- Supports: R18
-- Why GIN Trigram Index on review_text:
-- Moderation query filters for ILIKE '%cold%' OR ILIKE '%late%'. Standard B-trees cannot
-- index leading wildcards. pg_trgm GIN index allows fast bitmap index scans on text patterns.
CREATE INDEX IF NOT EXISTS idx_reviews_text_trgm
ON zomato.reviews USING gin (review_text gin_trgm_ops);

-- =====================================================================
-- 7. CUSTOMERS
-- =====================================================================

-- Supports: R14, W05
-- Why Partial B-Tree on (gold_expires_on) WHERE is_gold_member:
-- Indexes only active Gold members (~1,230 rows), enabling instant identification of expiring
-- memberships for marketing outreach and nightly deactivation jobs.
CREATE INDEX IF NOT EXISTS idx_customers_gold_expires
ON zomato.customers (gold_expires_on)
WHERE is_gold_member;

-- Supports: R20, R21
-- Why Composite B-Tree on (city_id, customer_id):
-- Supports customer lookups by city for regional growth analytics.
CREATE INDEX IF NOT EXISTS idx_customers_city_id
ON zomato.customers (city_id, customer_id);

-- =====================================================================
-- RE-ANALYZE SCHEMA TO UPDATE PLANNER STATISTICS
-- =====================================================================
ANALYZE zomato.cities;
ANALYZE zomato.localities;
ANALYZE zomato.customers;
ANALYZE zomato.restaurants;
ANALYZE zomato.menu_items;
ANALYZE zomato.delivery_partners;
ANALYZE zomato.coupons;
ANALYZE zomato.orders;
ANALYZE zomato.order_items;
ANALYZE zomato.payments;
ANALYZE zomato.reviews;
