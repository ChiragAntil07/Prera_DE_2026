
-- =====================================================
-- ZOMATO FOOD DELIVERY PROJECT
-- PHASE 2: LOAD SEED DATA
-- =====================================================

SET search_path TO zomato;

-- 1. Cities
\copy zomato.cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)

-- 2. Localities
\copy zomato.localities FROM 'seed_data/localities.csv' WITH (FORMAT csv, HEADER true)

-- 3. Customers
\copy zomato.customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true)

-- 4. Restaurants
\copy zomato.restaurants FROM 'seed_data/restaurants.csv' WITH (FORMAT csv, HEADER true)

-- 5. Menu Items
\copy zomato.menu_items FROM 'seed_data/menu_items.csv' WITH (FORMAT csv, HEADER true)

-- 6. Delivery Partners
\copy zomato.delivery_partners FROM 'seed_data/delivery_partners.csv' WITH (FORMAT csv, HEADER true)

-- 7. Coupons
\copy zomato.coupons FROM 'seed_data/coupons.csv' WITH (FORMAT csv, HEADER true)

-- 8. Orders
\copy zomato.orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true)

-- 9. Order Items
\copy zomato.order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true)

-- 10. Payments
\copy zomato.payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true)

-- 11. Reviews
\copy zomato.reviews FROM 'seed_data/reviews.csv' WITH (FORMAT csv, HEADER true)
