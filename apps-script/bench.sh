#!/usr/bin/env bash
# Measure leaderboard API latency. Run before and after each clasp push to
# verify perf changes landed. Results go to stdout; pipe to a file to save:
#   ./bench.sh > baseline.txt
#   ./bench.sh > optimized.txt
#   diff baseline.txt optimized.txt

set -uo pipefail

API="${LEADERBOARD_API:-https://script.google.com/macros/s/AKfycbwRyTPGVCcyAwPYWhZdwFi9c8M5P43D1jUuwignuNo6AoD14nB8zWg8k8xc_ztOP0DZ/exec}"
RUNS="${RUNS:-10}"

printf "api: %s\nruns: %d\n\n" "$API" "$RUNS"

fetch_ms() {
  curl -s -o /dev/null -w '%{time_total}' "$1" | awk '{ printf "%.0f", $1 * 1000 }'
}

post_ms() {
  curl -s -o /dev/null -w '%{time_total}' \
    -X POST "$1" \
    -H 'Content-Type: text/plain;charset=utf-8' \
    -d "$2" | awk '{ printf "%.0f", $1 * 1000 }'
}

measure_series() {
  local label="$1"; shift
  local url="$1"; shift
  local times=()
  for i in $(seq 1 "$RUNS"); do
    ms=$(fetch_ms "$url")
    times+=("$ms")
    printf "  run %2d: %s ms\n" "$i" "$ms"
  done
  local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  local n=${#sorted[@]}
  local p50=${sorted[$((n / 2))]}
  local p95=${sorted[$((n * 95 / 100))]}
  local min=${sorted[0]}
  local max=${sorted[$((n - 1))]}
  local sum=0
  for t in "${times[@]}"; do sum=$((sum + t)); done
  local avg=$((sum / n))
  printf "  %s: min=%s p50=%s avg=%s p95=%s max=%s (ms)\n\n" "$label" "$min" "$p50" "$avg" "$p95" "$max"
}

echo "=== GET cold (cache-buster each request) ==="
measure_series "cold" "${API}?t=$(date +%s%N)-cold"

echo "=== GET warm (same URL, hopefully cache-hit with optimization) ==="
measure_series "warm" "${API}?t=fixed"

echo "=== POST rejected (bad handle — exits before sheet write) ==="
payload_bad='{"handle":"","wpm":100,"keystrokes":100}'
bad_times=()
for i in $(seq 1 "$RUNS"); do
  ms=$(post_ms "$API" "$payload_bad")
  bad_times+=("$ms")
  printf "  run %2d: %s ms\n" "$i" "$ms"
done
sum=0; for t in "${bad_times[@]}"; do sum=$((sum + t)); done
printf "  avg=%s ms\n\n" "$((sum / ${#bad_times[@]}))"

echo "=== Response size (GET) ==="
size=$(curl -s "$API" | wc -c | tr -d ' ')
printf "  bytes: %s\n\n" "$size"

echo "done."
