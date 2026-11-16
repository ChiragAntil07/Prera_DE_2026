
#!/usr/bin/env bash

# ============================================================
# ZOMATO DATABASE - CP4 BENCHMARK SCRIPT
# Runs each marked query multiple times and records:
# average, median, minimum, maximum execution time and scan nodes.
# WRITE queries run inside BEGIN/ROLLBACK.
# ============================================================

set -euo pipefail

DB="${1:?Usage: $0 <database> <phase> [runs] [workload.sql]}"
PHASE="${2:?Phase required: before | after | seed_check | large}"
RUNS="${3:-3}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKLOAD="${4:-$ROOT/queries/workload_30.sql}"
OUT="$ROOT/benchmarks/results/$PHASE"
SUMMARY="$OUT/summary.csv"

# Validate number of runs
if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: RUNS must be a positive integer."
    exit 1
fi

# Validate workload file
if [[ ! -f "$WORKLOAD" ]]; then
    echo "ERROR: Workload file not found: $WORKLOAD"
    exit 1
fi

mkdir -p "$OUT"
echo "query_id,type,avg_ms,median_ms,min_ms,max_ms,scan_nodes" > "$SUMMARY"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Extract queries using marker lines
awk -v dir="$TMP" '
    /^-- @/ {
        id = ""
        if ($2 ~ /^@[RW][0-9]+$/) {
            id = substr($2, 2)
            file = dir "/" id ".sql"
            printf "" > file
        }
        next
    }

    id != "" && !/^--/ {
        print >> file
    }
' "$WORKLOAD"

# Confirm all 30 queries were extracted
COUNT=$(find "$TMP" -name '*.sql' | wc -l | tr -d ' ')

if [[ "$COUNT" -ne 30 ]]; then
    echo "ERROR: Expected 30 queries, but extracted $COUNT."
    exit 1
fi

echo "Database: $DB"
echo "Runs per query: $RUNS"
echo "Queries found: $COUNT"
echo "--------------------------------------------"

shopt -s nullglob
FILES=("$TMP"/*.sql)

# Sort query files naturally
IFS=$'\n' FILES=($(printf '%s\n' "${FILES[@]}" | sort -V))
unset IFS

for f in "${FILES[@]}"; do

    id="$(basename "$f" .sql)"
    type="READ"

    [[ "$id" == W* ]] && type="WRITE"

    query="$(cat "$f")"
    times=()
    plan=""

    : > "$OUT/$id.txt"

    for ((i = 1; i <= RUNS; i++)); do

        if [[ "$type" == "WRITE" ]]; then
            sql="SET search_path TO zomato; BEGIN; EXPLAIN (ANALYZE, BUFFERS) $query ROLLBACK;"
        else
            sql="SET search_path TO zomato; EXPLAIN (ANALYZE, BUFFERS) $query"
        fi

        plan="$(printf '%s\n' "$sql" |
            PGHOST=/tmp PGUSER=postgres PGPORT=5432 \
            psql -d "$DB" -X -q -A -t -v ON_ERROR_STOP=1)"

        echo "=== $id run $i ===" >> "$OUT/$id.txt"
        echo "$plan" >> "$OUT/$id.txt"

        t="$(echo "$plan" |
            grep -oE 'Execution Time: [0-9.]+' |
            awk '{print $3}')"

        if [[ -z "$t" ]]; then
            echo "ERROR: Could not extract execution time for $id."
            exit 1
        fi

        times+=("$t")
    done

    sorted=($(printf '%s\n' "${times[@]}" | sort -g))

    median="${sorted[$((RUNS / 2))]}"

    avg="$(printf '%s\n' "${times[@]}" |
        awk '{s += $1} END {printf "%.3f", s / NR}')"

    node="$(echo "$plan" |
        grep -oE '(Parallel )?(Seq Scan|Index Scan|Index Only Scan|Bitmap Heap Scan|Bitmap Index Scan)( Backward)?( using [a-z0-9_]+)? on [a-z0-9_]+' |
        sed -E 's/Parallel //; s/ Backward//' |
        awk '!seen[$0]++' |
        paste -sd'|' - |
        sed 's/|/ | /g' || true)"

    node="${node:-(no scan)}"

    echo "$id,$type,$avg,$median,${sorted[0]},${sorted[$((RUNS - 1))]},$node" >> "$SUMMARY"

    printf '%-4s %-5s avg %9s ms\n' "$id" "$type" "$avg"

done

echo "--------------------------------------------"
echo "Completed: $COUNT queries"
echo "Summary saved to: $SUMMARY"
echo "Raw plans saved to: $OUT/"
