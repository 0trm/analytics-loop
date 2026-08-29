#!/usr/bin/env bash
# SessionStart hook: report which GA4 export data actually exists right now.
#
# The single most common source of wrong analytics answers here is assuming
# today's or yesterday's data is queryable. There is no events_intraday_* table
# and the finalized export lags one to two days, so a session that starts
# without this line will happily write a query over a window that is partly
# empty.
#
# Costs nothing: `bq ls` reads table metadata, it does not scan.

PROJECT="your-gcp-project"          # <- your BigQuery project id
DATASET="analytics_XXXXXXXXX"       # <- your GA4 export dataset

command -v bq >/dev/null 2>&1 || exit 0

# `timeout` is GNU coreutils and is absent from a stock macOS, so it is optional here.
TIMEOUT=""
command -v gtimeout >/dev/null 2>&1 && TIMEOUT="gtimeout 10"
command -v timeout  >/dev/null 2>&1 && TIMEOUT="timeout 10"

# bq ls lists lexicographically and truncates at max_results with no warning, so keep
# the cap far above any plausible shard count or the newest shard falls off.
LATEST=$(
  $TIMEOUT bq --project_id="$PROJECT" ls --max_results=10000 "$DATASET" 2>/dev/null |
    grep -oE 'events_[0-9]{8}' | sort | tail -1
)

[ -z "$LATEST" ] && exit 0

SHARD="${LATEST#events_}"
TODAY=$(date -u +%Y%m%d)

# Day difference, via epoch seconds. BSD date on macOS, GNU date elsewhere.
# Both dates parse at UTC midnight so the difference is an exact multiple of a
# day (BSD date otherwise fills in the current time-of-day; local-time parsing
# would shift by an hour across DST and floor the division). Shard names follow
# the property's reporting timezone, so near midnight the lag can still read
# one day off - acceptable for a heads-up line.
if date -j >/dev/null 2>&1; then
  S=$(date -j -u -f %Y%m%d%H%M%S "${SHARD}000000" +%s 2>/dev/null)
  T=$(date -j -u -f %Y%m%d%H%M%S "${TODAY}000000" +%s 2>/dev/null)
else
  S=$(date -u -d "$SHARD" +%s 2>/dev/null)
  T=$(date -u -d "$TODAY" +%s 2>/dev/null)
fi

if [ -n "${S:-}" ] && [ -n "${T:-}" ]; then
  LAG=$(( (T - S) / 86400 ))
  echo "GA4 export: newest finalized shard is ${SHARD} (D-${LAG}). No intraday table exists - anything after ${SHARD} is unqueryable."
else
  echo "GA4 export: newest finalized shard is ${SHARD}. No intraday table exists."
fi
