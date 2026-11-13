
-- =====================================================
-- ZOMATO FOOD DELIVERY PROJECT
-- PHASE 2: DATABASE SCHEMA
-- =====================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS zomato;

SET search_path TO zomato;

-- =====================================================
-- 1. CITIES
-- =====================================================

CREATE TABLE cities (
    city_id INTEGER PRIMARY KEY,
    city_name VARCHAR(100),
    state VARCHAR(100)
);

-- =====================================================
-- 2. LOCALITIES
-- =====================================================

CREATE TABLE localities (
    locality_id INTEGER PRIMARY KEY,
    city_id INTEGER REFERENCES cities(city_id),
    locality_name VARCHAR(150),
    pincode VARCHAR(10)
);

-- =====================================================
-- 3. CUSTOMERS
-- =====================================================

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150),
    email VARCHAR(255),
    phone VARCHAR(20),
    city_id INTEGER REFERENCES cities(city_id),
    signup_date DATE,
    is_gold_member BOOLEAN,
    gold_expires_on DATE,
    is_active BOOLEAN
);

-- =====================================================
-- 4. RESTAURANTS
-- =====================================================

CREATE TABLE restaurants (
    restaurant_id INTEGER PRIMARY KEY,
    name VARCHAR(200),
    locality_id INTEGER REFERENCES localities(locality_id),
    cuisines TEXT,
    avg_cost_for_two NUMERIC(10,2),
    rating NUMERIC(3,1),
    rating_count INTEGER,
    opens_at TIME,
    closes_at TIME,
    is_pure_veg BOOLEAN,
    status VARCHAR(50),
    onboarded_on DATE
);

-- =====================================================
-- 5. MENU ITEMS
-- =====================================================

CREATE TABLE menu_items (
    item_id INTEGER PRIMARY KEY,
    restaurant_id INTEGER REFERENCES restaurants(restaurant_id),
    item_name VARCHAR(200),
    category VARCHAR(100),
    price NUMERIC(10,2),
    is_veg BOOLEAN,
    is_bestseller BOOLEAN,
    is_available BOOLEAN
);

-- =====================================================
-- 6. DELIVERY PARTNERS
-- =====================================================

CREATE TABLE delivery_partners (
    partner_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150),
    phone VARCHAR(20),
    city_id INTEGER REFERENCES cities(city_id),
    vehicle_type VARCHAR(50),
    joined_on DATE,
    rating NUMERIC(3,1),
    status VARCHAR(50)
);

-- =====================================================
-- 7. COUPONS
-- =====================================================

CREATE TABLE coupons (
    coupon_code VARCHAR(50) PRIMARY KEY,
    discount_pct NUMERIC(5,2),
    max_discount NUMERIC(10,2),
    min_order_value NUMERIC(10,2),
    valid_from DATE,
    valid_to DATE
);

-- =====================================================
-- 8. ORDERS
-- =====================================================

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    restaurant_id INTEGER REFERENCES restaurants(restaurant_id),
    partner_id INTEGER REFERENCES delivery_partners(partner_id),
    coupon_code VARCHAR(50) REFERENCES coupons(coupon_code),
    placed_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    distance_km NUMERIC(10,2),
    item_total NUMERIC(12,2),
    delivery_fee NUMERIC(10,2),
    discount NUMERIC(10,2),
    total_amount NUMERIC(12,2),
    status VARCHAR(50)
);

-- =====================================================
-- 9. ORDER ITEMS
-- =====================================================

CREATE TABLE order_items (
    order_id INTEGER REFERENCES orders(order_id),
    item_id INTEGER REFERENCES menu_items(item_id),
    quantity INTEGER,
    unit_price NUMERIC(10,2)
);

-- =====================================================
-- 10. PAYMENTS
-- =====================================================

CREATE TABLE payments (
    payment_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    amount NUMERIC(12,2),
    method VARCHAR(50),
    payment_status VARCHAR(50),
    attempted_at TIMESTAMPTZ
);

-- =====================================================
-- 11. REVIEWS
-- =====================================================

CREATE TABLE reviews (
    review_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    customer_id INTEGER REFERENCES customers(customer_id),
    restaurant_id INTEGER REFERENCES restaurants(restaurant_id),
    food_rating INTEGER,
    delivery_rating INTEGER,
    review_text TEXT,
    created_at TIMESTAMPTZ
);

-- =====================================================
-- END OF SCHEMA
-- =====================================================
