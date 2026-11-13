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

## 4. READ Query Baseline Timings

| Query ID | Average Execution Time (ms) |
|---|---:|
| R01 | 1.295 |
| R02 | 15.164 |
| R03 | 5.532 |
| R04 | 17.789 |
| R05 | 13.830 |
| R06 | 10.515 |
| R07 | 31.632 |
| R08 | 34.682 |
| R09 | 43.984 |
| R10 | 8.926 |
| R11 | 10.629 |
| R12 | 15.980 |
| R13 | 11.109 |
| R14 | 13.968 |
| R15 | 29.151 |
| R16 | 8.646 |
| R17 | 30.700 |
| R18 | 10.635 |
| R19 | 8493.191 |
| R20 | 37.837 |
| R21 | 19.832 |
| R22 | 28.117 |
| R23 | 67.208 |
| R24 | 19.209 |
| R25 | 0.701 |

## 5. WRITE Query Baseline Timings

| Query ID | Average Execution Time (ms) |
|---|---:|
| W01 | 1.089 |
| W02 | 20.713 |
| W03 | 4.475 |
| W04 | 22.149 |
| W05 | 7.984 |

## 6. Baseline Observations

- All 30 workload queries were executed successfully.
- Each query was measured across three runs.
- R19 recorded the highest average execution time of 8493.191 ms.
- R23 recorded the second-highest average execution time of 67.208 ms.
- R25 recorded the lowest average execution time of 0.701 ms.
- The baseline timings will be used to compare query performance after optimization.

## 7. Conclusion

The baseline benchmark for the Zomato Food Delivery Database has been completed.

The execution timings and raw query plans have been stored for future performance analysis. These results will serve as the reference point for CP3 query optimization.
