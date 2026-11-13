# CP2: Baseline Query Timings

## 1. Overview

- Database: PostgreSQL 18
- Database Name: zomato_db
- Workload: queries/workload_30.sql
- Total Queries: 30
- READ Queries: 25
- WRITE Queries: 5
- Runs per Query: 3
- Measurement Method: EXPLAIN ANALYZE, BUFFERS

## 2. Benchmark Methodology

Each query was executed three times using the benchmark script.

The average execution time of the three runs was recorded in milliseconds.

Write queries were executed inside transactions and rolled back to avoid permanent data changes.

## 3. Result Files

- Summary timings: benchmarks/results/baseline/summary.csv
- Raw execution plans: benchmarks/results/baseline/

## 4. Complete Baseline Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Home feed - open restaurants in Koramangala | READ | 1.715 | 0.544 | 1.627 | 1.295 |
| R02: Dish search - available paneer dishes in Bengaluru | READ | 20.458 | 12.659 | 12.374 | 15.164 |
| R03: Restaurant page - menu grouped by category | READ | 5.585 | 5.583 | 5.429 | 5.532 |
| R04: Your orders - last 10 orders with restaurant names | READ | 31.844 | 10.858 | 10.665 | 17.789 |
| R05: Kitchen-delay alert - PREPARING orders over 40 minutes | READ | 16.160 | 12.266 | 13.063 | 13.830 |
| R06: Restaurant partner app - orders for restaurant 217 | READ | 10.757 | 10.668 | 10.119 | 10.515 |
| R07: Units sold per dish in May 2026 | READ | 36.272 | 29.271 | 29.354 | 31.632 |
| R08: Top 3 dishes of every Pune restaurant | READ | 34.915 | 34.675 | 34.456 | 34.682 |
| R09: Average delivery time per city per month | READ | 45.359 | 43.241 | 43.351 | 43.984 |
| R10: June deliveries taking more than 60 minutes | READ | 8.891 | 8.806 | 9.082 | 8.926 |
| R11: Delivery partner 150 weekly earnings | READ | 10.637 | 10.682 | 10.567 | 10.629 |
| R12: Orders waiting for delivery partner, oldest first | READ | 15.418 | 15.836 | 16.687 | 15.980 |
| R13: Active Bengaluru partners without recent orders | READ | 10.921 | 11.278 | 11.129 | 11.109 |
| R14: Gold members expiring before July with June orders | READ | 14.373 | 13.318 | 14.212 | 13.968 |
| R15: Coupon effectiveness - orders, discount, average bill | READ | 29.127 | 29.276 | 29.050 | 29.151 |
| R16: Failed payment attempts per method in last 7 days | READ | 9.133 | 8.247 | 8.557 | 8.646 |
| R17: Customers with 2 or more failed payment attempts | READ | 29.205 | 29.565 | 33.330 | 30.700 |
| R18: Newest reviews complaining about cold food or late delivery | READ | 10.722 | 10.540 | 10.644 | 10.635 |
| R19: Restaurant health report for Bengaluru | READ | 8512.715 | 8493.858 | 8473.000 | 8493.191 |
| R20: Top 20 Mumbai customers by delivered-order spend | READ | 36.915 | 36.549 | 40.046 | 37.837 |
| R21: Share of customers in each city ordering twice in May | READ | 19.028 | 20.558 | 19.910 | 19.832 |
| R22: Bengaluru orders by weekday and hour, last 8 weeks | READ | 28.092 | 27.949 | 28.310 | 28.117 |
| R23: All orders, page 4001 | READ | 68.172 | 65.550 | 67.903 | 67.208 |
| R24: Bill page - order items, restaurant, successful payment | READ | 18.766 | 19.866 | 18.995 | 19.209 |
| R25: Open Chinese restaurants in Pune | READ | 0.711 | 0.709 | 0.684 | 0.701 |
| W01: Place a new order - header row | WRITE | 0.868 | 0.938 | 1.460 | 1.089 |
| W02: Assign partner 150 to oldest accepted order | WRITE | 25.412 | 19.140 | 17.587 | 20.713 |
| W03: Hide sold-out desserts | WRITE | 3.142 | 4.807 | 5.477 | 4.475 |
| W04: Recompute restaurant ratings from reviews | WRITE | 28.745 | 20.529 | 17.174 | 22.149 |
| W05: End expired Gold memberships | WRITE | 7.310 | 7.899 | 8.742 | 7.984 |
| **Total (sum of all 30)** | | **9091.368** | **9015.665** | **9002.984** | **9036.672** |

## 5. Scan Types and Performance Analysis

The scan types below were identified from the generated baseline `summary.csv`. Sequential scans read table rows, while index scans use an index to locate relevant records. The observations are based on the recorded average execution times and scan nodes.

| Query ID | Scan Type | Average Time (ms) | Performance Observation |
|---|---|---:|---|
| R01 | Seq Scan on restaurants, localities | 1.295 | Fast query; scans on these tables complete quickly for this workload. |
| R02 | Seq Scan on menu_items, restaurants, localities | 15.164 | Multiple sequential scans and joins increase execution work. |
| R03 | Seq Scan on menu_items | 5.532 | Single-table scan with relatively low execution time. |
| R04 | Seq Scan on orders; Index Scan on restaurants (PK) | 17.789 | Orders are scanned sequentially, while restaurant lookup uses the primary-key index. |
| R05 | Seq Scan on orders | 13.830 | Full scan of orders contributes to execution time. |
| R06 | Seq Scan on orders | 10.515 | Sequential scan with moderate execution time. |
| R07 | Seq Scan on order_items, orders; Index Scan on menu_items (PK) | 31.632 | Scans across order-related tables and joins increase work. |
| R08 | Seq Scan on order_items, orders, restaurants, localities | 34.682 | Multiple sequential scans across joined tables contribute to higher execution time. |
| R09 | Seq Scan on orders, restaurants, localities | 43.984 | Scans across multiple tables result in relatively high execution time. |
| R10 | Seq Scan on orders | 8.926 | Sequential scan completes with comparatively low execution time. |
| R11 | Seq Scan on orders | 10.629 | Sequential scan with moderate execution time. |
| R12 | Seq Scan on orders | 15.980 | Sequential scan takes longer than several other orders queries. |
| R13 | Seq Scan on delivery_partners, orders | 11.109 | Sequential scans on two tables contribute to query processing. |
| R14 | Seq Scan on orders, customers | 13.968 | Sequential scans across joined tables add work. |
| R15 | Seq Scan on orders, coupons | 29.151 | Sequential scans across both tables correspond to a higher execution time. |
| R16 | Seq Scan on payments | 8.646 | Single-table scan with relatively low execution time. |
| R17 | Seq Scan on orders, payments | 30.700 | Sequential scans across two tables contribute to execution time. |
| R18 | Seq Scan on reviews | 10.635 | Single-table scan with moderate execution time. |
| R19 | Seq Scan on restaurants, localities, orders, reviews | 8493.191 | Highest average execution time in the workload (~8.49 seconds). The multiple table scans are visible in the plan; detailed plan analysis is needed to identify the exact bottleneck. |
| R20 | Seq Scan on orders, customers | 37.837 | Scans across joined tables correspond to relatively high execution time. |
| R21 | Seq Scan on customers, orders | 19.832 | Sequential scans across two tables contribute to query work. |
| R22 | Seq Scan on orders, restaurants, localities | 28.117 | Multiple sequential scans increase the amount of data processed. |
| R23 | Seq Scan on orders | 67.208 | Highest average among the reads apart from R19; the orders scan is associated with substantial execution time. |
| R24 | Seq Scan on payments; Index Scans on orders, restaurants, menu_items; Seq Scan on order_items | 19.209 | Uses a combination of sequential and primary-key index scans across multiple tables. |
| R25 | Seq Scan on restaurants, localities | 0.701 | Fastest read query by average execution time. |
| W01 | No scan reported | 1.089 | Write operation completes quickly in the baseline. |
| W02 | Seq Scan on orders; Index Scan on orders (PK) | 20.713 | The plan includes a sequential scan and a primary-key index scan on orders. |
| W03 | Seq Scan on menu_items | 4.475 | The write plan includes a sequential scan on menu_items. |
| W04 | Seq Scan on restaurants, reviews | 22.149 | Sequential scans on two tables are present in the write plan. |
| W05 | Seq Scan on customers | 7.984 | The write plan includes a sequential scan on customers. |

### Key Observations

- **R19 is the slowest query**, averaging 8493.191 ms (approximately 8.49 seconds).
- **R25 is the fastest read query**, averaging 0.701 ms.
- Sequential scans appear frequently throughout the baseline workload.
- Some queries use primary-key index scans, including R04, R07, and R24.
- Queries involving scans across multiple tables generally have higher execution times in this workload, although the exact bottleneck depends on the full execution plan.
- The baseline results provide a reference point for evaluating future indexing and query optimization.



## 6. Conclusion

The baseline benchmark for the Zomato Food Delivery Database has been completed.

The execution timings and raw query plans have been stored for future performance analysis. These results will serve as the reference point for CP3 query optimization.
