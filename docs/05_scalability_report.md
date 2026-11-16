# CP4: Scalability Report

**Project:** Zomato Food Delivery Database
**Team ID:** T0042
**Database:** PostgreSQL 18
**Schema:** `zomato`

---

## 1. Introduction

This report evaluates the scalability of the Zomato Food Delivery Database. It covers query performance, data growth, partitioning, storage, and architecture considerations for handling increased transaction volume.

The objective is to understand how the database can handle a significant increase in customers, restaurants, orders, and transactions while maintaining efficient query performance.

The report uses the seed dataset as the initial performance baseline. A separate large dataset will be used to evaluate how query performance and storage requirements change as the database grows.

## 2. Current Dataset

The seed dataset contains the following records:

| Table | Number of rows |
|---|---:|
| cities | 10 |
| localities | 100 |
| customers | 25,000 |
| restaurants | 2,500 |
| menu_items | 50,000 |
| delivery_partners | 2,000 |
| coupons | 30 |
| orders | 150,000 |
| order_items | 375,000 |
| payments | 137,378 |
| reviews | 39,186 |
| **Total** | **791,204** |

The database contains 791,204 records across 11 tables.

The seed dataset provides the baseline for evaluating query performance, storage consumption, and the effectiveness of database optimization techniques.

## 3. Partitioning Strategy

### 3.1 Partitioning Approach

Range partitioning was selected for the orders data using the `placed_at` column.

Orders are divided into monthly partitions so that queries filtering by date can scan only the relevant partition instead of scanning the entire orders table.

A separate demonstration table, `orders_partitioned_demo`, was created to demonstrate partitioning without changing the original `orders` table and its existing foreign-key relationships.

The partitioned table uses a composite primary key consisting of `order_id` and `placed_at`, because PostgreSQL requires a partitioned table's primary key to include the partition key.

### 3.2 Partitioning Results

The partitioning demonstration was successfully executed.

- Original orders: 150,000
- Partitioned orders: 150,000
- Monthly partitions: 18
- Default partition: 1
- Total leaf partitions: 19

All 150,000 orders were successfully copied into the partitioned demonstration table.

### 3.3 Partition Pruning

Partition pruning was tested using the following query:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM zomato.orders_partitioned_demo
WHERE placed_at >= '2026-01-01'
  AND placed_at < '2026-02-01';
```

The execution plan accessed only the `orders_demo_2026_01` partition instead of scanning all partitions.

**Observed execution times (single run):**

| Table | Execution time |
|---|---:|
| Original `orders` table | 2.132 ms |
| `orders_partitioned_demo` | 1.484 ms |

The partitioned demonstration table was approximately 30.4% faster in this single test.

This indicates that partition pruning can reduce the amount of data scanned for date-based queries. However, repeated runs are required for a more reliable performance comparison.

The partitioning demonstration is separate from the original production-style orders table. Applying partitioning to the actual table would require careful planning of foreign-key relationships and primary-key constraints.

## 4. Query Performance Benchmarking

### 4.1 Benchmark Methodology

The optimized workload contains 30 queries:

- 25 read queries (R01–R25).
- 5 write queries (W01–W05).

Each query was executed three times on the seed database.

The benchmark script recorded:

- Average execution time.
- Median execution time.
- Minimum execution time.
- Maximum execution time.
- Scan nodes from the execution plans.

Write queries were executed inside transactions and rolled back to prevent benchmark runs from permanently changing the seed dataset.

The results are stored in:

`benchmarks/results/seed_check/summary.csv`

Individual execution plans are saved in the same directory.

### 4.2 Seed Dataset Benchmark Results

The following table contains the measured results from the three benchmark runs.

| Query | Type | Average (ms) | Median (ms) | Minimum (ms) | Maximum (ms) |
|---|---|---:|---:|---:|---:|
| R01 | READ | 0.199 | 0.183 | 0.162 | 0.253 |
| R02 | READ | 7.730 | 7.535 | 7.018 | 8.637 |
| R03 | READ | 0.049 | 0.049 | 0.048 | 0.049 |
| R04 | READ | 0.344 | 0.178 | 0.142 | 0.711 |
| R05 | READ | 0.046 | 0.037 | 0.037 | 0.064 |
| R06 | READ | 0.128 | 0.050 | 0.048 | 0.286 |
| R07 | READ | 0.295 | 0.140 | 0.139 | 0.607 |
| R08 | READ | 5.871 | 4.289 | 4.223 | 9.101 |
| R09 | READ | 43.289 | 43.191 | 43.091 | 43.585 |
| R10 | READ | 1.647 | 1.653 | 1.628 | 1.659 |
| R11 | READ | 0.181 | 0.071 | 0.053 | 0.420 |
| R12 | READ | 0.227 | 0.121 | 0.097 | 0.462 |
| R13 | READ | 0.562 | 0.566 | 0.534 | 0.587 |
| R14 | READ | 2.284 | 2.293 | 2.160 | 2.400 |
| R15 | READ | 9.985 | 10.144 | 9.146 | 10.664 |
| R16 | READ | 0.249 | 0.136 | 0.119 | 0.491 |
| R17 | READ | 22.438 | 22.417 | 22.116 | 22.780 |
| R18 | READ | 13.792 | 4.576 | 4.478 | 32.321 |
| R19 | READ | 26.921 | 27.143 | 25.605 | 28.014 |
| R20 | READ | 37.750 | 37.063 | 37.038 | 39.150 |
| R21 | READ | 8.844 | 8.952 | 8.612 | 8.967 |
| R22 | READ | 7.113 | 4.284 | 4.156 | 12.899 |
| R23 | READ | 20.212 | 20.277 | 19.964 | 20.395 |
| R24 | READ | 0.494 | 0.229 | 0.228 | 1.024 |
| R25 | READ | 0.613 | 0.600 | 0.585 | 0.654 |
| W01 | WRITE | 1.497 | 1.391 | 1.277 | 1.822 |
| W02 | WRITE | 0.861 | 0.748 | 0.651 | 1.183 |
| W03 | WRITE | 0.349 | 0.363 | 0.312 | 0.371 |
| W04 | WRITE | 24.617 | 23.932 | 23.911 | 26.008 |
| W05 | WRITE | 10.455 | 11.351 | 7.862 | 12.151 |

### 4.3 Initial Performance Observations

The seed benchmark results show that query execution times vary depending on the type and amount of work performed.

- R03, R05, R06, R07, R11, R12, and R16 have particularly low average execution times.
- R09, R17, R19, R20, and R23 take longer than several other read queries, indicating that more expensive filtering, joins, or aggregation may be involved.
- W01, W02, and W03 have relatively low average execution times.
- W04 and W05 take longer than the other write queries.

The benchmark results provide a baseline for identifying queries that may require further optimization when the dataset becomes larger.

These observations are based on the seed dataset only. They do not establish whether the queries will meet the performance targets on the large dataset.

## 5. Large Dataset Performance

The large dataset is expected to contain approximately 20 times the volume of the seed dataset.

The expected large dataset includes approximately:

- 3,000,000 orders.
- 7,500,000 order items.
- 500,000 customers.
- 50,000 restaurants.

A separate database named `zomato_large` has been created. Its schema and 21 secondary indexes have also been prepared.

The large dataset has not yet been loaded. Therefore, large-dataset benchmark results are pending.

After receiving `large_data.zip` from the faculty, the following steps will be performed:

1. Load the large dataset into `zomato_large`.
2. Verify the row counts of all tables.
3. Run `ANALYZE` to update database statistics.
4. Execute the optimized query workload.
5. Run each query three times.
6. Record average execution times and execution plans.
7. Compare the large-dataset results with the seed benchmark.

### 5.1 Seed vs Large Dataset Comparison

The following table will be completed after large-dataset benchmarking.

| Query | Seed average (ms) | Large average (ms) | Growth (large ÷ seed) | Meets target? |
|---|---:|---:|---:|---|
| R01 | 0.199 | Pending | Pending | Pending |
| R02 | 7.730 | Pending | Pending | Pending |
| R03 | 0.049 | Pending | Pending | Pending |
| R04 | 0.344 | Pending | Pending | Pending |
| R05 | 0.046 | Pending | Pending | Pending |
| R06 | 0.128 | Pending | Pending | Pending |
| R07 | 0.295 | Pending | Pending | Pending |
| R08 | 5.871 | Pending | Pending | Pending |
| R09 | 43.289 | Pending | Pending | Pending |
| R10 | 1.647 | Pending | Pending | Pending |
| R11 | 0.181 | Pending | Pending | Pending |
| R12 | 0.227 | Pending | Pending | Pending |
| R13 | 0.562 | Pending | Pending | Pending |
| R14 | 2.284 | Pending | Pending | Pending |
| R15 | 9.985 | Pending | Pending | Pending |
| R16 | 0.249 | Pending | Pending | Pending |
| R17 | 22.438 | Pending | Pending | Pending |
| R18 | 13.792 | Pending | Pending | Pending |
| R19 | 26.921 | Pending | Pending | Pending |
| R20 | 37.750 | Pending | Pending | Pending |
| R21 | 8.844 | Pending | Pending | Pending |
| R22 | 7.113 | Pending | Pending | Pending |
| R23 | 20.212 | Pending | Pending | Pending |
| R24 | 0.494 | Pending | Pending | Pending |
| R25 | 0.613 | Pending | Pending | Pending |
| W01 | 1.497 | Pending | Pending | Pending |
| W02 | 0.861 | Pending | Pending | Pending |
| W03 | 0.349 | Pending | Pending | Pending |
| W04 | 24.617 | Pending | Pending | Pending |
| W05 | 10.455 | Pending | Pending | Pending |

The growth ratio will be calculated using:

`Large dataset average execution time / Seed dataset average execution time`

The final comparison will identify queries that remain efficient and queries that require further optimization.

### 5.2 Performance Targets

The following performance targets will be used to evaluate the large dataset.

| Query category | Queries | Target |
|---|---|---:|
| Real-time/customer-facing reads and writes | R01, R03, R04, R05, R06, R11, R12, R24, W01, W02, W03 | Under 5 ms |
| Interactive/search/operations | R02, R10, R13, R14, R16, R18, R25 | Under 250 ms |
| Reports and analytics | R07, R08, R09, R15, R17, R19, R20, R21, R22, R23 | Under 5000 ms |
| Batch writes | W04, W05 | Under 2000 ms |

Performance target achievement will be determined using actual large-dataset measurements.

## 6. Growth Analysis

The growth analysis will compare optimized query execution times on the seed and large datasets.

Queries will be grouped into three categories:

1. **Queries that remain approximately the same:** Queries that use efficient indexes and retrieve a limited number of records.
2. **Queries that grow approximately with dataset size:** Queries that process a larger proportion of the database as the data increases.
3. **Queries that grow more than expected:** Queries that may involve expensive joins, sorting, aggregations, or large table scans.

Execution plans will be examined to identify the reasons behind significant performance changes.

### 6.1 Potential Scalability Challenges

The following challenges may become more noticeable as the database grows:

- Full table scans on large tables.
- Expensive joins involving orders, customers, restaurants, and order items.
- Sorting and aggregation over millions of records.
- Increased index storage requirements.
- Higher write workload and index maintenance overhead.
- Increased contention when multiple transactions access the same records.

### 6.2 Optimization Approach

If a query does not meet its performance target, its execution plan will be examined.

Possible improvements include:

- Creating or modifying suitable indexes.
- Improving join conditions and filtering.
- Reducing unnecessary columns and rows.
- Using partition pruning for date-based queries.
- Reviewing aggregation and sorting operations.
- Using materialized views for frequently requested analytical results.

Actual scale-related problems and applied optimizations will be documented after large-dataset benchmarking.

## 7. Storage Analysis

Storage measurements were collected from the seed database using PostgreSQL size functions.

### 7.1 Total Database Size

The total size of the seed database (`zomato_db`) was measured using `pg_database_size()`.

| Dataset | Database size |
|---|---:|
| Seed dataset | 139 MB |
| Large dataset | Pending |

### 7.2 Table and Index Storage

The following measurements were collected using `pg_relation_size()`, `pg_indexes_size()`, and `pg_total_relation_size()`.

| Table | Table size | Index size | Total size |
|---|---:|---:|---:|
| orders | 18 MB | 25 MB | 42 MB |
| order_items | 19 MB | 15 MB | 33 MB |
| payments | 9.1 MB | 6.5 MB | 16 MB |
| menu_items | 3.6 MB | 4.7 MB | 8.5 MB |
| reviews | 2.7 MB | 2.2 MB | 5 MB |
| customers | 2.9 MB | 1.2 MB | 4.2 MB |
| restaurants | 376 kB | 904 kB | 1.3 MB |

*Note: Values are rounded as displayed by PostgreSQL. The complete storage breakdown, including the remaining tables and partition demonstration tables, is saved in `benchmarks/results/seed_check/storage_report.txt`.*

### 7.3 Storage Observations

1. The `orders` table has the highest total storage usage among the original tables, at approximately 42 MB.
2. The `order_items` table occupies approximately 33 MB, making it another major contributor to database storage.
3. Index storage is significant. For example, the indexes on `orders` occupy approximately 25 MB compared with 18 MB of table storage.
4. This demonstrates that indexes improve query access but also contribute to overall database storage requirements.

### 7.4 Large Dataset Storage Comparison

The same measurements will be collected after loading the large dataset into `zomato_large`.

The final comparison will include:

- Total database size for both datasets.
- Individual table storage growth.
- Index storage growth.
- Overall storage increase as data volume increases.

## 8. Architecture for 100× Growth

### 8.1 Partitioning

Monthly range partitioning on `orders.placed_at` is proposed for managing historical order data and improving date-filtered queries.

The partitioning demonstration showed that PostgreSQL can eliminate irrelevant partitions when a query filters by date.

For production, the partitioning strategy should be applied to the actual orders table with careful planning of foreign keys and primary-key constraints.

Future monthly partitions should be created in advance to ensure that new orders can be inserted without interruption.

### 8.2 Sharding

For handling approximately 100 times the current data volume, a customer-based sharding strategy using `customer_id` is proposed.

**Sharding Strategy**

The customer records can be distributed across multiple database shards using a hash-based partitioning approach.

For example:

- Shard 1: Customers whose hash value maps to shard 1.
- Shard 2: Customers whose hash value maps to shard 2.
- Shard 3: Customers whose hash value maps to shard 3.
- Additional shards can be introduced as the data grows.

A routing layer can calculate the appropriate shard using the customer's ID and direct requests to the correct database.

**Data Distribution**

Orders belonging to a customer should be stored on the same shard as that customer's data. Related order items should also be accessible through the same shard to reduce cross-shard operations. This may require including the customer identifier in the order-item data or maintaining a mapping between orders and shards.

**Advantages**

- Distributes customer and order data across multiple database servers.
- Reduces the workload handled by a single database.
- Improves scalability for customer-specific operations such as order history and booking details.
- Allows additional shards to be introduced as data volume increases.

**Challenges of Cross-Shard Queries**

Some operations require data from multiple shards:

- Restaurant dashboards may need orders from customers stored on different shards.
- Delivery partner assignment may involve orders across multiple customer shards.
- City-wise analytics and restaurant performance reports may require combining data from multiple shards.

These operations require distributed query processing and aggregation, which can increase response time and system complexity.

**Proposed Solution**

A central routing layer can direct customer-specific requests to the correct shard. Frequently accessed reference data, such as restaurant and city information, can be replicated across shards where appropriate.

Analytical queries that require data from multiple shards can be executed through a reporting layer that combines the results.

Overall, customer-based sharding can improve transaction scalability, but cross-shard joins, distributed transactions, and data consistency must be carefully managed.

### 8.3 Read Replicas and Caching

A read-replica architecture is proposed to distribute database workload and reduce pressure on the primary database.

**Read Replicas**

Read-only analytical queries can be routed to read replicas, including:

- R07–R10: Restaurant sales and operational reports.
- R15, R17, R19–R23: Marketing, risk, growth, and analytics reports.

These queries mainly retrieve and aggregate data, so they can tolerate a small replication delay where appropriate.

**Primary Database**

The primary database should handle all write operations (W01–W05), because changes must be committed to the main database.

Freshness-sensitive queries such as dispatch, order status, payment information, and billing should also use the primary database when the latest committed data is required.

**Caching**

Frequently accessed data can be cached to reduce repeated database queries:

- Restaurant listings and ratings.
- Restaurant menus.
- Cuisine and dish search results.
- Frequently accessed restaurant information.

A short cache expiration time (TTL) should be used. The cache should be invalidated or refreshed when relevant restaurant or menu information changes.

**Benefits**

Read replicas improve read scalability, while caching reduces repeated database access. Together, they can improve response times and support increased traffic.

### 8.4 Database Maintenance

Database maintenance is important to keep the database efficient as the number of orders and transactions increases.

**1. VACUUM and Autovacuum**

PostgreSQL's autovacuum should remain enabled to clean up dead tuples and update table statistics.

The `orders` table is expected to receive frequent inserts and updates. Therefore, its autovacuum activity should be monitored and tuned according to actual workload and table growth.

The following command can be used for manual maintenance:

```sql
VACUUM (ANALYZE) zomato.orders;
```

**2. Archiving Old Data**

Older orders can be archived to reduce the size of actively queried data.

Since the proposed partitioning strategy divides orders by month, old monthly partitions can be detached and moved to archival storage when they are no longer frequently accessed.

Historical records should remain available for reporting and business analysis.

**3. Refreshing Summary Tables**

Frequently used analytical reports can use materialized views or summary tables instead of repeatedly calculating results from millions of rows.

Examples include:

- Monthly restaurant sales.
- Average restaurant ratings.
- City-wise order statistics.
- Monthly delivery performance.

Materialized views can be refreshed periodically using:

```sql
REFRESH MATERIALIZED VIEW view_name;
```

The refresh schedule should depend on how frequently the underlying data changes and how fresh the reports need to be.

**Expected Benefits**

These maintenance practices help control database growth, improve query performance, reduce unnecessary storage usage, and maintain reliable analytical results.

## 9. Conclusion

The seed dataset successfully loaded 791,204 records across 11 tables. All 30 optimized queries were benchmarked three times, providing baseline execution-time measurements for read and write operations.

The seed database occupies approximately 139 MB. Storage measurements show that the `orders` and `order_items` tables are major contributors to storage usage, and that indexes account for a significant portion of database size.

The partitioning demonstration successfully copied all 150,000 orders and showed partition pruning for a date-based query. The partitioned demonstration table was approximately 30.4% faster in the observed single-run comparison.

Monthly range partitioning, customer-based sharding, read replicas, caching, and regular database maintenance are proposed as strategies for supporting future growth.

The final scalability evaluation will be completed after the large dataset is received and benchmarked. Actual large-dataset execution times, storage measurements, growth ratios, performance target results, and any additional optimizations will be included in the final report.

---

**Benchmark result files:** `benchmarks/results/seed_check/summary.csv`
**Seed storage report:** `benchmarks/results/seed_check/storage_report.txt`
**Partitioning script:** `sql/08_partitioning.sql`