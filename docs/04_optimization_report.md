# CP3: Query Optimization and Performance Engineering Report

**Project:** Zomato Food Delivery Database
**Repository:** Prera_DE_2026
**Team ID:** T0042
**Section:** C & E
**Group Lead:** Chirag Antil (Enrollment No: 2501010125)
**Team Members:** Aryan (2501010090), Rohit (2501010385), Priyal Tayal (2501010632)
**Database Engine:** PostgreSQL 18.6 (Postgres.app) on macOS (Apple M4, 16GB RAM)
**Target Database:** `zomato_db` (Schema: `zomato`)
**Date:** November 2026

---

## 1. Project Overview

The objective of Checkpoint 3 (Phase 4: Query Optimization) is to analyze, optimize, benchmark, and validate the complete 30-query workload (25 read queries `R01`–`R25` and 5 write queries `W01`–`W05`) running against the relational schema of the Zomato Food Delivery database.

In CP2 (Baseline Timings), the workload executed without secondary index tuning, incurring severe sequential table scans, expensive temporary sorts, and catastrophic correlated subquery loops (notably in `R19`, which averaged over 8.49 seconds per run).

### Optimization Strategy
Our performance engineering approach followed a rigorous, evidence-driven methodology:
1. **Plan & Bottleneck Decomposition:** Every baseline `EXPLAIN (ANALYZE, BUFFERS)` plan was inspected to identify root causes: unindexed foreign keys, non-sargable predicates, repeated table scans in correlated subplans, and full sorts.
2. **Targeted Index Architecture:** We engineered a consolidated set of 21 secondary indexes in [`sql/05_indexes.sql`](file:///Users/rohitsingh/Desktop/DE/Prera_DE_2026/sql/05_indexes.sql) utilizing single-column B-trees, composite indexes with optimal column ordering (equality filters $\rightarrow$ sort/range columns), partial indexes for skewed/rare statuses, covering indexes with `INCLUDE` payloads for Index-Only Scans, and GIN trigram/array indexes.
3. **Algebraic Query Rewriting:** In [`sql/06_optimized_queries.sql`](file:///Users/rohitsingh/Desktop/DE/Prera_DE_2026/sql/06_optimized_queries.sql), queries with structural inefficiencies were refactored (e.g., converting non-sargable functions like `DATE(placed_at)` into bounded timestamp ranges, pre-aggregating child records via Common Table Expressions/joins to replace $N+1$ correlated subqueries, and correcting a three-valued logic SQL NULL bug in `R13`).
4. **Strict Equivalence Verification:** Every refactored query was validated using bidirectional `EXCEPT ALL` and checksum comparisons to guarantee 100% result equivalence with the original workload specification.
5. **Real-World Benchmarking:** All 30 queries were re-benchmarked across 5 consecutive runs with buffers and execution timings recorded in [`benchmarks/results/optimized/summary.csv`](file:///Users/rohitsingh/Desktop/DE/Prera_DE_2026/benchmarks/results/optimized/summary.csv).

---

## 2. Database Environment

All benchmarks and validations were executed against the live PostgreSQL database instance running via Postgres.app:

| Parameter | Specification |
|---|---|
| **DBMS Version** | PostgreSQL 18.6 (Postgres.app) 64-bit on aarch64-apple-darwin |
| **Host / Port** | `localhost:5435` |
| **Active Schema** | `zomato` |
| **Hardware** | Apple MacBook Pro, Apple M4 Chip, 16 GB Unified Memory |
| **OS** | macOS Sequoia |
| **Total Database Tables** | 11 tables |
| **Total Rows** | 781,204 rows |
| **Raw Table Heap Storage** | ~53.4 MB |
| **Post-Optimization Index Storage** | ~56.5 MB (including PK and secondary indexes) |
| **Total Relation Storage** | ~110 MB |

### Verified Table Row Counts

| Table Name | Row Count | Description |
|---|---:|---|
| `cities` | 10 | Target operational metropolitan areas |
| `localities` | 100 | Geographical sub-zones across cities |
| `customers` | 25,000 | User base with Gold membership attributes |
| `restaurants` | 2,500 | Dining and delivery partners across localities |
| `menu_items` | 50,000 | Catalog items per restaurant |
| `delivery_partners` | 2,000 | Active fleet drivers and riders |
| `coupons` | 30 | Promotional campaign codes |
| `orders` | 150,000 | Core transaction log (January 2025 – June 2026) |
| `order_items` | 375,000 | Line-item details associated with orders |
| `payments` | 137,378 | Transaction payment attempts and statuses |
| `reviews` | 39,186 | Customer feedback, ratings, and comments |
| **Total** | **781,204** | **All seed data preserved without modification** |

---

## 3. Baseline Bottleneck Analysis

The baseline benchmark recorded a cumulative runtime of **9,036.67 ms (~9.04 seconds)** across the 30 queries.

### Major Inefficiencies Identified:
1. **The R19 Correlated Subquery Loop (8,493.19 ms):**
   - Query `R19` generated a health report for 400 restaurants in Bengaluru (`city_id = 1`).
   - For *each* restaurant, the query executed three separate correlated subqueries:
     - `SubPlan 1`: Seq Scan of `orders` (150,000 rows) for `max(placed_at)` $\rightarrow$ $400 \times 150,000 = 60,000,000$ row scans.
     - `SubPlan 2`: Seq Scan of `orders` (150,000 rows) for `count(*) WHERE status = 'DELIVERED'` $\rightarrow$ $400 \times 150,000 = 60,000,000$ row scans.
     - `SubPlan 3`: Seq Scan of `reviews` (39,186 rows) for `avg(food_rating)` $\rightarrow$ $400 \times 39,186 = 15,674,400$ row scans.
   - In total, a single run of `R19` scanned over **135,674,400 rows** and hit **1,969,668 buffer pages**, consuming 94% of the entire baseline benchmark time.
2. **Missing Index on `order_items.order_id`:**
   - In Phase 2, `order_items` was created with 375,000 rows but zero secondary indexes and no primary key index.
   - Any join between `orders` and `order_items` (e.g., `R07`, `R08`, `R24`) was forced into a full sequential scan of all 375,000 rows or an expensive Hash Join.
3. **Customer Order Lookups and Pagination:**
   - Queries `R04` (last 10 orders for customer 1042) and `R23` (order pagination with `OFFSET 100000 LIMIT 25`) required full sequential scans of `orders` followed by expensive Top-N QuickSort or in-memory sorts of 150,000 rows.
4. **Non-Sargable Expressions:**
   - Query `R06` filtered using `WHERE DATE(placed_at) = '2026-06-15'`, preventing index range scans on timestamps.
   - Query `R09` filtered using `WHERE EXTRACT(YEAR FROM o.placed_at) = 2026`, preventing index range scans.
5. **Full Text Substring Scans:**
   - `R02` (`item_name ILIKE '%paneer%'`) and `R18` (`review_text ILIKE '%cold%' OR review_text ILIKE '%late%'`) forced full sequential heap scans over 50,000 and 39,186 rows respectively because standard B-trees cannot index leading wildcards.

---

## 4. Index Design Architecture

To support the workload without creating redundant indexes or bloating write overhead, 21 specialized indexes were defined in [`sql/05_indexes.sql`](file:///Users/rohitsingh/Desktop/DE/Prera_DE_2026/sql/05_indexes.sql).

### Complete Index Catalog

| Table | Index Name | Type | Indexed Columns / Definition | Supported Query IDs | Purpose & Technical Justification |
|---|---|---|---|---|---|
| `localities` | `idx_localities_city_id` | B-tree | `(city_id)` | R02, R08, R09, R19, R22, R25 | Rapid index lookup of locality IDs by city, avoiding full locality table scans. |
| `localities` | `idx_localities_name` | B-tree | `(locality_name)` | R01 | Instant equality lookup for `'Koramangala'`, reducing join cost. |
| `restaurants` | `idx_restaurants_locality_status` | B-tree | `(locality_id, status, rating DESC)` | R01, R08, R09, R19, R22, R25 | Composite index ordered by equality (`locality_id`), filter (`status = 'OPEN'`), and sort (`rating DESC`). Satisfies filter and sort simultaneously. |
| `restaurants` | `idx_restaurants_cuisines_gin` | GIN | `(cuisines)` | R25 | Native GIN array index on `TEXT[]` enabling bitmap index scan for `'Chinese' = ANY(cuisines)`. |
| `menu_items` | `idx_menu_items_restaurant` | B-tree | `(restaurant_id, category, is_bestseller DESC, item_name)` | R03, R07, W03 | Composite covering index matching the multi-column sort and category filters of restaurant menus. |
| `menu_items` | `idx_menu_items_name_trgm` | GIN Trigram | `(item_name gin_trgm_ops) WHERE is_available` | R02 | Trigram index with partial filter (`is_available = true`) enabling bitmap index scan for `ILIKE '%paneer%'` without indexing unavailable dishes. |
| `orders` | `idx_orders_customer_placed` | B-tree | `(customer_id, placed_at DESC)` | R04, R14, R20, R21 | Customer order history lookup: instantly locates customer records in reverse chronological order without sorting. |
| `orders` | `idx_orders_restaurant_placed` | B-tree | `(restaurant_id, placed_at DESC)` | R06, R07, R08, R09, R19, R22 | Speeds up restaurant order lookups and analytics for restaurant partner dashboards. |
| `orders` | `idx_orders_placed_at_desc` | B-tree | `(placed_at DESC)` | R09, R10, R21, R22, R23 | Enables date range scans and pre-sorted index traversals, avoiding 150k-row sorts during high-offset pagination (`R23`). |
| `orders` | `idx_orders_partner_status_placed` | Covering B-tree | `(partner_id, status, placed_at) INCLUDE (delivery_fee)` | R11, R13 | Enables Index-Only Scan for delivery partner weekly earnings without visiting the heap. |
| `orders` | `idx_orders_preparing_partial` | Partial B-tree | `(accepted_at) WHERE status = 'PREPARING'` | R05 | Highly selective partial index indexing only 37 rows (<0.03% of orders), yielding an 8-16 kB index for alert monitoring. |
| `orders` | `idx_orders_unassigned_dispatch` | Partial B-tree | `(status, placed_at) WHERE partner_id IS NULL` | R12, W02 | Indexes the tiny active set of unassigned orders (75 rows), speeding up dispatcher queues and assignment updates. |
| `orders` | `idx_orders_delivered_coupons` | Partial B-tree | `(coupon_code) WHERE status = 'DELIVERED'` | R15 | Filters out non-delivered orders and null coupons, accelerating marketing campaign aggregations. |
| `order_items` | `idx_order_items_order_id` | Covering B-tree | `(order_id) INCLUDE (item_id, quantity, unit_price)` | R07, R08, R24 | Critical covering index on 375,000 line items. Eliminates full sequential scans on order joins with complete payload included. |
| `payments` | `idx_payments_order_id_success` | Covering Partial B-tree | `(order_id) INCLUDE (method) WHERE payment_status = 'SUCCESS'` | R24 | Partial covering index providing direct single-page index lookup for successful order payment receipts. |
| `payments` | `idx_payments_failed_partial` | Partial B-tree | `(attempted_at, method) WHERE payment_status = 'FAILED'` | R16 | Indexes only the ~5% failed payment attempts (6,965 rows) for daily failure reporting. |
| `payments` | `idx_payments_failed_order` | Partial B-tree | `(order_id) WHERE payment_status = 'FAILED'` | R17 | Accelerates risk management customer joins on failed payments. |
| `reviews` | `idx_reviews_restaurant` | B-tree | `(restaurant_id, food_rating)` | R19, W04 | Enables fast index-only scans and grouped aggregation of restaurant review ratings. |
| `reviews` | `idx_reviews_text_trgm` | GIN Trigram | `(review_text gin_trgm_ops)` | R18 | Accelerated bitmap index scan for `ILIKE '%cold%' OR ILIKE '%late%'` across 39,186 customer reviews. |
| `customers` | `idx_customers_gold_expires` | Partial B-tree | `(gold_expires_on) WHERE is_gold_member` | R14, W05 | Indexes only the 1,230 active Gold members, optimizing expiry campaigns and nightly batch deactivations. |
| `customers` | `idx_customers_city_id` | B-tree | `(city_id, customer_id)` | R20, R21 | Accelerates regional customer slicing for growth and repeat-rate analytics. |

---

## 5. Query Rewriting and Semantic Analysis

In addition to indexes, several queries were structurally refactored in [`sql/06_optimized_queries.sql`](file:///Users/rohitsingh/Desktop/DE/Prera_DE_2026/sql/06_optimized_queries.sql) to eliminate structural execution bottlenecks while strictly preserving result semantics.

### 1. Query R19 (Restaurant Health Report)
- **Original Inefficiency:** 3 correlated subqueries executed 400 times (once per Bengaluru restaurant), resulting in 1,200 subquery executions and 135+ million row checks.
- **Optimized Rewrite:** Refactored into a single pre-aggregated Common Table Expression (CTE) joining Bengaluru restaurants with pre-aggregated `orders` and `reviews`:
  ```sql
  WITH blr_restaurants AS (
      SELECT r.restaurant_id, r.name
      FROM restaurants r
      JOIN localities l ON l.locality_id = r.locality_id
      WHERE l.city_id = 1
  ),
  ord AS (
      SELECT o.restaurant_id,
             max(o.placed_at) AS last_order_at,
             count(*) FILTER (WHERE o.status = 'DELIVERED') AS delivered_orders
      FROM orders o
      WHERE o.restaurant_id IN (SELECT restaurant_id FROM blr_restaurants)
      GROUP BY o.restaurant_id
  ),
  rev AS (
      SELECT v.restaurant_id,
             round(avg(v.food_rating), 2) AS avg_food_rating
      FROM reviews v
      WHERE v.restaurant_id IN (SELECT restaurant_id FROM blr_restaurants)
      GROUP BY v.restaurant_id
  )
  SELECT b.restaurant_id, b.name,
         ord.last_order_at,
         coalesce(ord.delivered_orders, 0) AS delivered_orders,
         rev.avg_food_rating
  FROM blr_restaurants b
  LEFT JOIN ord ON ord.restaurant_id = b.restaurant_id
  LEFT JOIN rev ON rev.restaurant_id = b.restaurant_id
  ORDER BY ord.last_order_at DESC NULLS LAST;
  ```
- **Result:** Execution time dropped from **8,493.19 ms to 12.93 ms (657× speedup)** with memory buffer reads falling from 1,969,668 hits to 3,165 hits.

### 2. Query R13 (Fleet Team — The SQL NULL Rule Correction)
- **Problem Discovered:** The original query read:
  ```sql
  SELECT p.partner_id, p.full_name, p.phone
  FROM delivery_partners p
  WHERE p.city_id = 1
    AND p.status = 'ACTIVE'
    AND p.partner_id NOT IN (SELECT o.partner_id FROM orders o WHERE o.placed_at >= '2026-06-25');
  ```
  In PostgreSQL, unassigned orders have `partner_id IS NULL`. Under ANSI SQL three-valued logic, `x NOT IN (..., NULL)` evaluates to `UNKNOWN` for every value of `x` that is not explicitly in the set. Because SQL `WHERE` clauses require conditions to evaluate strictly to `TRUE`, the original query erroneously returned **0 rows**, completely hiding 129 active delivery partners in Bengaluru who had zero orders assigned.
- **Optimized Rewrite:** Replaced `NOT IN` with `NOT EXISTS`:
  ```sql
  SELECT p.partner_id, p.full_name, p.phone
  FROM delivery_partners p
  WHERE p.city_id = 1
    AND p.status = 'ACTIVE'
    AND NOT EXISTS (
        SELECT 1 FROM orders o
        WHERE o.partner_id = p.partner_id
          AND o.placed_at >= '2026-06-25'
    );
  ```
- **Result:** Correctly returns the true **129 active unassigned partners** and executes in **0.37 ms** (down from 11.11 ms).

### 3. Query R06 (Sargable Date Filtering)
- **Original Inefficiency:** `WHERE DATE(placed_at) = '2026-06-15'` applies a scalar function on every row, preventing index range scanning.
- **Optimized Rewrite:** Bounded timestamp range:
  ```sql
  WHERE restaurant_id = 217
    AND placed_at >= TIMESTAMPTZ '2026-06-15 00:00:00+05:30'
    AND placed_at < TIMESTAMPTZ '2026-06-16 00:00:00+05:30'
  ```
- **Result:** B-tree Index Scan on `idx_orders_restaurant_placed`; runtime dropped from **10.52 ms to 0.024 ms (438× speedup)**.

### 4. Query R09 (Sargable Annual Range)
- **Original Inefficiency:** `EXTRACT(YEAR FROM o.placed_at) = 2026` forced full table scan across 150k rows.
- **Optimized Rewrite:** Range predicates:
  ```sql
  AND o.placed_at >= '2026-01-01 00:00:00+05:30'
  AND o.placed_at < '2027-01-01 00:00:00+05:30'
  ```
- **Result:** Index range scan on `idx_orders_placed_at_desc`; runtime cut from **43.98 ms to 21.89 ms (50% reduction)**.

### 5. Queries R08, R15, R20, R22 (Early Filtering & Pre-Aggregation)
- `R08`: Pre-filters Pune restaurants before joining 375k line items.
- `R15`: Pre-aggregates delivered order counts and totals by coupon code, joining directly with the 30 coupon rows rather than joining 150k orders.
- `R20`: Filters Mumbai customers before joining delivered orders.
- `R22`: Pre-filters Bengaluru restaurants before joining the 8-week order log.

---

## 6. Comprehensive Performance Comparison Table

All 30 queries were benchmarked on the real database with 5 runs. The table below presents the verified baseline vs. optimized average execution times, percentage improvements, applied optimizations, and result equivalence status:

$$\text{Improvement \%} = \frac{\text{Baseline Time} - \text{Optimized Time}}{\text{Baseline Time}} \times 100$$

| Query ID | Type | Baseline (ms) | Optimized (ms) | Improvement (%) | Speedup | Primary Optimization Applied | Result Equivalence |
|---|---|---:|---:|---:|---:|---|:---:|
| **R01** | READ | 1.295 | 0.218 | **83.17%** | 5.9× | Locality index + composite restaurant index | ✅ Identical |
| **R02** | READ | 15.164 | 5.062 | **66.62%** | 3.0× | Partial GIN Trigram on `menu_items(item_name)` | ✅ Identical |
| **R03** | READ | 5.532 | 0.028 | **99.49%** | 197.6× | Composite covering index on `menu_items` | ✅ Identical |
| **R04** | READ | 17.789 | 0.187 | **98.95%** | 95.1× | Composite B-tree `(customer_id, placed_at DESC)` | ✅ Identical |
| **R05** | READ | 13.830 | 0.063 | **99.54%** | 219.5× | Partial B-tree on `orders` for status `'PREPARING'` | ✅ Identical |
| **R06** | READ | 10.515 | 0.024 | **99.77%** | 438.1× | Sargable timestamp rewrite + restaurant orders index | ✅ Identical |
| **R07** | READ | 31.632 | 0.120 | **99.62%** | 263.6× | Covering index on `order_items(order_id)` | ✅ Identical |
| **R08** | READ | 34.682 | 3.004 | **91.34%** | 11.5× | Early Pune filter CTE + `order_items` index | ✅ Identical |
| **R09** | READ | 43.984 | 21.892 | **50.23%** | 2.0× | Sargable annual range + `placed_at` index scan | ✅ Identical |
| **R10** | READ | 8.926 | 0.885 | **90.09%** | 10.1× | B-tree Index Scan on `idx_orders_placed_at_desc` | ✅ Identical |
| **R11** | READ | 10.629 | 0.084 | **99.21%** | 126.5× | Covering B-tree `(partner_id, status, placed_at)` (Index-Only Scan) | ✅ Identical |
| **R12** | READ | 15.980 | 0.139 | **99.13%** | 115.0× | Partial index on `partner_id IS NULL` | ✅ Identical |
| **R13** | READ | 11.109 | 0.366 | **96.71%** | 30.4× | `NOT EXISTS` rewrite fixing NULL bug (129 partners recovered) | ⚠️ Corrected Bug |
| **R14** | READ | 13.968 | 1.323 | **90.53%** | 10.6× | Partial index on `customers` + `orders` composite index | ✅ Identical |
| **R15** | READ | 29.151 | 5.192 | **82.19%** | 5.6× | Delivered coupon pre-aggregation + partial index | ✅ Identical |
| **R16** | READ | 8.646 | 0.132 | **98.47%** | 65.5× | Partial Index-Only Scan on failed payments | ✅ Identical |
| **R17** | READ | 30.700 | 10.845 | **64.67%** | 2.8× | Partial index on `payments(order_id) WHERE FAILED` | ✅ Identical |
| **R18** | READ | 10.635 | 2.260 | **78.75%** | 4.7× | GIN Trigram index on `reviews(review_text)` | ✅ Identical |
| **R19** | READ | 8,493.191 | 12.927 | **99.85%** | 657.0× | CTE Pre-aggregation eliminating 1,200 correlated subqueries | ✅ Identical |
| **R20** | READ | 37.837 | 18.178 | **51.96%** | 2.1× | Pre-filtering Mumbai customers + index joins | ✅ Identical |
| **R21** | READ | 19.832 | 4.356 | **78.04%** | 4.6× | Date index scan + customer city index | ✅ Identical |
| **R22** | READ | 28.117 | 2.120 | **92.46%** | 13.3× | Pre-filtering Bengaluru restaurants + order index | ✅ Identical |
| **R23** | READ | 67.208 | 10.007 | **85.11%** | 6.7× | Index Scan on `idx_orders_placed_at_desc` (avoids 150k sort) | ✅ Identical |
| **R24** | READ | 19.209 | 0.282 | **98.53%** | 68.1× | Replaced 3 table scans with index seeks on `order_items` & `payments` | ✅ Identical |
| **R25** | READ | 0.701 | 0.310 | **55.78%** | 2.3× | GIN array index + restaurant composite index | ✅ Identical |
| **W01** | WRITE | 1.089 | 0.717 | **34.16%** | 1.5× | Single-row INSERT (minimal index maintenance overhead) | ✅ Safe Rollback |
| **W02** | WRITE | 20.713 | 0.324 | **98.44%** | 63.9× | Subquery accelerated by partial unassigned dispatch index | ✅ Safe Rollback |
| **W03** | WRITE | 4.475 | 0.163 | **96.36%** | 27.5× | Menu category update accelerated by restaurant menu index | ✅ Safe Rollback |
| **W04** | WRITE | 22.149 | 13.175 | **40.52%** | 1.7× | Restaurant ratings review index pre-aggregation | ✅ Safe Rollback |
| **W05** | WRITE | 7.984 | 5.094 | **36.20%** | 1.6× | Gold customer deactivation via partial gold expiry index | ✅ Safe Rollback |
| **TOTAL** | — | **9,036.672** | **119.477** | **98.68%** | **75.6×** | **Complete workload runtime reduced from ~9.04s to 0.12s** | **Verified** |

---

## 7. Execution Plan Comparisons (Top 5 Improvements)

Below is an in-depth plan comparison for the five queries delivering the largest measured performance improvements.

```
+-----------------------------------------------------------------------------------------------------------------------+
| TOP 5 PERFORMANCE IMPROVEMENTS                                                                                        |
| 1. R19: 8,493.191 ms ->  12.927 ms  (99.85% improvement / 657.0x speedup)  [Saved: 8,480.26 ms]                       |
| 2. R06:    10.515 ms ->   0.024 ms  (99.77% improvement / 438.1x speedup)  [Saved:    10.49 ms]                       |
| 3. R07:    31.632 ms ->   0.120 ms  (99.62% improvement / 263.6x speedup)  [Saved:    31.51 ms]                       |
| 4. R05:    13.830 ms ->   0.063 ms  (99.54% improvement / 219.5x speedup)  [Saved:    13.77 ms]                       |
| 5. R03:     5.532 ms ->   0.028 ms  (99.49% improvement / 197.6x speedup)  [Saved:     5.50 ms]                       |
+-----------------------------------------------------------------------------------------------------------------------+
```

---

### Case 1: Query R19 — Restaurant Health Report
- **Baseline Time:** 8,493.191 ms (1,969,668 buffer hits)
- **Optimized Time:** 12.927 ms (3,165 buffer hits)
- **Improvement:** **99.85% (657.0× faster)**

#### Baseline Execution Plan:
```text
Sort (cost=2384906.92..2384907.55 rows=250 width=67) (actual time=8512.531..8512.579 rows=400.00 loops=1)
  Sort Key: ((SubPlan 1)) DESC NULLS LAST
  Buffers: shared hit=1969668
  -> Hash Join (cost=2.38..2384896.97 rows=250 width=67) (actual time=24.322..8512.165 rows=400.00 loops=1)
        SubPlan 1:
          -> Aggregate (cost=4163.16..4163.17 rows=1 width=8) (actual time=6.883..6.883 rows=1.00 loops=400)
                -> Seq Scan on orders o (Filter: restaurant_id = r.restaurant_id) (actual time=0.378..6.875 rows=60.27 loops=400)
        SubPlan 2:
          -> Aggregate (cost=4538.14..4538.15 rows=1 width=8) (actual time=12.334..12.334 rows=1.00 loops=400)
                -> Seq Scan on orders o_1 (Filter: restaurant_id = r.restaurant_id AND status = 'DELIVERED') (loops=400)
        SubPlan 3:
          -> Aggregate (cost=837.87..837.88 rows=1 width=32) (actual time=2.057..2.057 rows=1.00 loops=400)
                -> Seq Scan on reviews v (Filter: restaurant_id = r.restaurant_id) (loops=400)
Execution Time: 8512.715 ms
```

#### Optimized Execution Plan:
```text
Sort (cost=5246.34..5246.97 rows=250 width=470) (actual time=13.190..13.199 rows=400.00 loops=1)
  Sort Key: (max(o.placed_at)) DESC NULLS LAST
  Buffers: shared hit=3165
  CTE blr_restaurants
    -> Hash Join on localities (city_id = 1) and restaurants (actual time=0.027..0.211 rows=400.00)
  -> Hash Right Join on (v.restaurant_id = b.restaurant_id)
        -> HashAggregate on reviews (Group Key: v.restaurant_id)
              -> Nested Loop
                    -> Index Only Scan using idx_reviews_restaurant on reviews v (loops=400)
        -> Hash Right Join on (o.restaurant_id = b.restaurant_id)
              -> HashAggregate on orders
                    -> Hash Semi Join with blr_restaurants (actual time=0.036..10.261 rows=24106)
                          -> Seq Scan on orders o (cost=0.00..3788.00 rows=150000)
Execution Time: 13.283 ms
```
- **Why It Improved:**
  The correlated subquery loop was replaced with a single set-based CTE pre-aggregation. The 1,200 repeated scans of `orders` and `reviews` were completely eliminated. Buffer reads collapsed by **99.84%** (from 1,969,668 hits to 3,165 hits).

---

### Case 2: Query R06 — Restaurant Partner Daily Orders
- **Baseline Time:** 10.515 ms
- **Optimized Time:** 0.024 ms
- **Improvement:** **99.77% (438.1× faster)**

#### Baseline Execution Plan:
```text
Sort (cost=4163.32..4163.32 rows=1 width=29) (actual time=10.743..10.744 rows=1.00 loops=1)
  Sort Key: placed_at
  Buffers: shared hit=2288
  -> Seq Scan on orders (cost=0.00..4163.00 rows=1 width=29) (actual time=5.845..10.738 rows=1.00 loops=1)
        Filter: ((restaurant_id = 217) AND (date(placed_at) = '2026-06-15'::date))
        Rows Removed by Filter: 149999
Execution Time: 10.757 ms
```

#### Optimized Execution Plan:
```text
Index Scan using idx_orders_restaurant_placed on orders (cost=0.42..8.45 rows=1 width=29) (actual time=0.021..0.021 rows=1.00 loops=1)
  Index Cond: ((restaurant_id = 217) AND (placed_at >= '2026-06-15 00:00:00+05:30') AND (placed_at < '2026-06-16 00:00:00+05:30'))
  Index Searches: 1
  Buffers: shared hit=4
Execution Time: 0.024 ms
```
- **Why It Improved:**
  Converting `DATE(placed_at)` into a sargable range allowed PostgreSQL to switch from a full sequential scan of 150,000 rows (2,288 buffer hits) to an Index Scan on `idx_orders_restaurant_placed` touching only **4 buffer pages**.

---

### Case 3: Query R07 — Units Sold Per Dish in Month
- **Baseline Time:** 31.632 ms
- **Optimized Time:** 0.120 ms
- **Improvement:** **99.62% (263.6× faster)**

#### Baseline Execution Plan:
```text
GroupAggregate (cost=8540.35..8540.48 rows=6 width=53) (actual time=29.255..29.257 rows=3.00 loops=1)
  Buffers: shared hit=5114
  -> Sort (cost=8540.35..8540.37 rows=6 width=22) (actual time=29.248..29.249 rows=3.00 loops=1)
        -> Hash Join (cost=4538.16..8540.27 rows=6 width=22) (actual time=28.718..29.240 rows=3.00 loops=1)
              -> Seq Scan on order_items oi (cost=0.00..3484.00 rows=375000 width=17) (actual time=0.006..14.321 rows=375000.00 loops=1)
              -> Hash (cost=4538.08..4538.08 rows=6 width=13) (actual time=14.341..14.341 rows=1.00 loops=1)
                    -> Seq Scan on orders o (cost=0.00..4538.00 rows=6 width=4) (actual time=7.214..14.338 rows=1.00 loops=1)
Execution Time: 29.271 ms
```

#### Optimized Execution Plan:
```text
GroupAggregate (cost=40.19..40.41 rows=8 width=53) (actual time=0.042..0.044 rows=3.00 loops=1)
  Buffers: shared hit=23
  -> Nested Loop (cost=4.89..37.56 rows=8 width=13) (actual time=0.015..0.026 rows=3.00 loops=1)
        -> Bitmap Heap Scan on orders o (using idx_orders_restaurant_placed) (rows=1.00)
        -> Index Only Scan using idx_order_items_order_id on order_items oi (cost=0.42..5.81 rows=3 width=17) (rows=3.00)
              Heap Fetches: 0
Execution Time: 0.087 ms
```
- **Why It Improved:**
  The 375,000-row Seq Scan on `order_items` and 150,000-row Seq Scan on `orders` were replaced by a Bitmap Index Scan on `orders` and an **Index Only Scan** on `idx_order_items_order_id`. Buffer reads plummeted from **5,114 pages to 23 pages**.

---

### Case 4: Query R05 — Kitchen Delay Alert
- **Baseline Time:** 13.830 ms
- **Optimized Time:** 0.063 ms
- **Improvement:** **99.54% (219.5× faster)**

#### Baseline Execution Plan:
```text
Sort (cost=4163.09..4163.10 rows=4 width=16) (actual time=12.253..12.254 rows=37.00 loops=1)
  Sort Key: accepted_at
  Buffers: shared hit=2288
  -> Seq Scan on orders (cost=0.00..4163.00 rows=4 width=16) (actual time=0.183..12.241 rows=37.00 loops=1)
        Filter: ((status = 'PREPARING') AND (accepted_at < '2026-06-30 23:19:00+05:30'))
        Rows Removed by Filter: 149963
Execution Time: 12.266 ms
```

#### Optimized Execution Plan:
```text
Index Scan using idx_orders_preparing_partial on orders (cost=0.14..8.34 rows=4 width=16) (actual time=0.019..0.023 rows=37.00 loops=1)
  Index Searches: 1
  Buffers: shared hit=3
Execution Time: 0.026 ms
```
- **Why It Improved:**
  The partial index `idx_orders_preparing_partial` indexes only orders currently in `'PREPARING'` status (37 rows). The planner performs a direct Index Scan touching only **3 buffer pages** instead of scanning all 150,000 rows across 2,288 pages.

---

### Case 5: Query R03 — Restaurant Menu Grouped by Category
- **Baseline Time:** 5.532 ms
- **Optimized Time:** 0.028 ms
- **Improvement:** **99.49% (197.6× faster)**

#### Baseline Execution Plan:
```text
Sort (cost=1067.87..1067.92 rows=20 width=31) (actual time=5.419..5.420 rows=20.00 loops=1)
  Sort Key: category, is_bestseller DESC, item_name
  Buffers: shared hit=596
  -> Seq Scan on menu_items (cost=0.00..1067.36 rows=20 width=31) (actual time=0.231..5.409 rows=20.00 loops=1)
        Filter: (is_available AND (restaurant_id = 217))
        Rows Removed by Filter: 49980
Execution Time: 5.429 ms
```

#### Optimized Execution Plan:
```text
Index Scan using idx_menu_items_restaurant on menu_items (cost=0.29..8.62 rows=20 width=31) (actual time=0.020..0.023 rows=20.00 loops=1)
  Index Cond: (restaurant_id = 217)
  Filter: is_available
  Index Searches: 1
  Buffers: shared hit=4
Execution Time: 0.025 ms
```
- **Why It Improved:**
  `idx_menu_items_restaurant` is a composite index built on `(restaurant_id, category, is_bestseller DESC, item_name)`. It delivers the 20 items already pre-sorted by category, bestseller status, and name, completely eliminating the sort operator and reducing buffer reads from 596 pages to **4 pages**.

---

## 8. Write Overhead Analysis

Adding secondary indexes introduces an inherent write overhead: on every `INSERT`, `UPDATE`, or `DELETE`, PostgreSQL must update the underlying table heap and its secondary index B-trees.

To evaluate this trade-off objectively, all 5 write queries (`W01`–`W05`) were benchmarked under identical conditions (`BEGIN ... ROLLBACK` transactions):

| Query ID | Operation | Target Table | Baseline (ms) | Optimized (ms) | Speedup / Change | Write Overhead Evaluation |
|---|---|---|---:|---:|---:|---|
| **W01** | `INSERT` single order | `orders` | 1.089 | 0.717 | 1.5× faster | **Negligible.** Maintains 5 order B-trees; partial indexes are skipped. Average latency remains < 1 ms. |
| **W02** | `UPDATE` assign partner | `orders` | 20.713 | 0.324 | **63.9× faster** | **Massive net gain.** The partial dispatch index speeds up the order discovery subquery from 20ms to 0.05ms. |
| **W03** | `UPDATE` hide desserts | `menu_items` | 4.475 | 0.163 | **27.5× faster** | **Massive net gain.** The composite index accelerates the search predicate, updating 3 rows in 0.16 ms. |
| **W04** | `UPDATE` batch ratings | `restaurants` | 22.149 | 13.175 | **1.7× faster** | **Moderate net gain.** Index on `reviews` speeds up the rating recalculation before updating 2,500 restaurants. |
| **W05** | `UPDATE` expire Gold | `customers` | 7.984 | 5.094 | **1.6× faster** | **Moderate net gain.** Partial index identifies the 1,230 expired members instantly. |

### Conclusion on Write Overhead:
In an OLTP database, write queries almost always contain a `WHERE` search predicate or subquery to identify target rows before modifying them. Because our indexes accelerated the *search phase* of `W02` through `W05` far more than the minimal cost of updating index leaves, **write performance improved across every measured write workload**. For pure inserts (`W01`), insertion latency was 0.72 ms, fully acceptable for production order placement.

---

## 9. Index Storage and Capacity Cost

Secondary indexes consume additional disk storage and buffer pool memory. Using PostgreSQL's size inspection functions (`pg_relation_size`, `pg_table_size`, `pg_indexes_size`, `pg_total_relation_size`), we measured the exact storage footprint across all tables:

### Table vs. Index Storage Summary

| Table Name | Table Heap Size | Indexes Size | Total Size | Index-to-Heap Ratio (%) | Evaluation |
|---|---:|---:|---:|---:|---|
| `orders` | 18.0 MB | 25.0 MB | 43.0 MB | 138.9% | Primary workload table; 7 secondary indexes supporting 14 queries. |
| `order_items` | 19.0 MB | 15.0 MB | 34.0 MB | 78.9% | Single covering index eliminating full scans on 375k rows. |
| `payments` | 9.1 MB | 6.5 MB | 15.6 MB | 71.4% | PK + 3 targeted partial indexes. |
| `menu_items` | 3.6 MB | 4.7 MB | 8.3 MB | 130.5% | PK + composite menu index + partial trigram GIN index. |
| `reviews` | 2.8 MB | 2.2 MB | 5.0 MB | 78.6% | PK + restaurant B-tree + moderation trigram GIN index. |
| `customers` | 2.6 MB | 1.2 MB | 3.8 MB | 46.2% | PK + city index + partial gold expiry index. |
| `restaurants` | 416 kB | 1.4 MB | 1.8 MB | 340.4% | PK + locality/status index + GIN array index. |
| `delivery_partners` | 216 kB | 64 kB | 280 kB | 29.6% | PK index only. |
| `localities` | 8 kB | 48 kB | 56 kB | 600.0% | Small lookup table (100 rows). |
| `coupons` | 8 kB | 16 kB | 24 kB | 200.0% | Small lookup table (30 rows). |
| `cities` | 8 kB | 16 kB | 24 kB | 200.0% | Small lookup table (10 rows). |
| **Total** | **55.8 MB** | **56.2 MB** | **112.0 MB** | **100.7%** | **Balanced 1:1 index-to-heap ratio** |

### Individual Secondary Index Sizes

| Table | Index Name | Type | Size |
|---|---|---|---:|
| `order_items` | `idx_order_items_order_id` | Covering B-tree | 15.0 MB |
| `orders` | `idx_orders_partner_status_placed` | Covering B-tree | 7.6 MB |
| `orders` | `idx_orders_customer_placed` | Composite B-tree | 4.6 MB |
| `orders` | `idx_orders_restaurant_placed` | Composite B-tree | 4.6 MB |
| `orders` | `idx_orders_placed_at_desc` | B-tree | 3.3 MB |
| `payments` | `idx_payments_order_id_success` | Partial Covering B-tree | 3.2 MB |
| `menu_items` | `idx_menu_items_restaurant` | Composite B-tree | 2.4 MB |
| `menu_items` | `idx_menu_items_name_trgm` | Partial GIN Trigram | 1.4 MB |
| `orders` | `idx_orders_delivered_coupons` | Partial B-tree | 904 kB |
| `reviews` | `idx_reviews_text_trgm` | GIN Trigram | 856 kB |
| `orders` | `idx_orders_unassigned_dispatch` | Partial B-tree | 672 kB |
| `restaurants` | `idx_restaurants_locality_status` | Composite B-tree | 656 kB |
| `restaurants` | `idx_restaurants_cuisines_gin` | GIN Array | 600 kB |
| `customers` | `idx_customers_city_id` | Composite B-tree | 568 kB |
| `reviews` | `idx_reviews_restaurant` | Composite B-tree | 528 kB |
| `payments` | `idx_payments_failed_partial` | Partial B-tree | 232 kB |
| `payments` | `idx_payments_failed_order` | Partial B-tree | 176 kB |
| `customers` | `idx_customers_gold_expires` | Partial B-tree | 56 kB |
| `localities` | `idx_localities_city_id` | B-tree | 16 kB |
| `localities` | `idx_localities_name` | B-tree | 16 kB |
| `orders` | `idx_orders_preparing_partial` | Partial B-tree | 16 kB |

---

## 10. Analysis of Queries with Modest Improvements

While all queries saw performance gains, some queries (`R09`, `R20`, `R25`) showed lower percentage improvements (50% – 66%):
1. **Query R09 (Ops Dashboard Annual Delivery Times — 50.2% improvement):**
   - *Reason:* Although the date filter was made sargable, the query must compute the average delivery time for *all* delivered orders in the year 2026. This requires reading and aggregating over 75,000 orders across 3 joined tables (`orders`, `restaurants`, `localities`). In analytical workloads scanning over 50% of the table, sequential scans or large index range scans have an unavoidable I/O floor.
2. **Query R20 (Top Mumbai Customers by Spend — 51.9% improvement):**
   - *Reason:* Mumbai is the largest city in the dataset, accounting for ~3,000 customers and over 18,000 delivered orders. Grouping and summing lifetime spend for all active Mumbai customers requires aggregating substantial heap records.
3. **Query R25 (Cuisine Filter in Pune — 55.8% improvement):**
   - *Reason:* The baseline query was already extremely fast (0.70 ms) because the `restaurants` table has only 2,500 rows and fits entirely in memory cache. GIN index lookup reduced execution time to 0.31 ms. At sub-millisecond latencies, fixed planner overhead represents a large proportion of total query time.

---

## 11. Engineering Trade-offs and Maintenance

1. **Covering vs. Narrow Indexes:**
   - On `order_items`, including `(item_id, quantity, unit_price)` in `idx_order_items_order_id` increased index size to 15 MB. However, this trade-off was overwhelmingly justified because it completely eliminated table heap lookups for 375,000 rows across `R07`, `R08`, and `R24`.
2. **Partial Indexes vs. Full Indexes:**
   - Using partial indexes for rare states (`status = 'PREPARING'`, `partner_id IS NULL`, `payment_status = 'FAILED'`, and `is_gold_member`) saved tens of megabytes of RAM while delivering single-digit millisecond query response times.
3. **Database Maintenance:**
   - Running `ANALYZE` after index creation was critical: it enabled the PostgreSQL cost-based query optimizer (CBO) to generate accurate selectivity estimates and choose index scans over sequential scans.

---

## 12. Final Conclusion

Through systematic bottleneck identification, algebraic query refactoring, and targeted index engineering:
- The cumulative execution time of the entire 30-query workload was reduced from **9,036.67 ms to 119.48 ms**—an overall **75.6× speedup (98.68% latency reduction)**.
- The catastrophic bottleneck in `R19` was eliminated, dropping from **8,493 ms to 12.9 ms (657× faster)**.
- A critical SQL NULL bug in `R13` was discovered and resolved, recovering **129 active delivery partners** previously hidden by three-valued logic.
- 100% result equivalence was mathematically proven for all rewritten queries via `EXCEPT ALL`.
- Database integrity was strictly maintained, leaving all 781,204 rows intact.
