#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
HEALTH_PATH="${HEALTH_PATH:-/healthz}"
HOST_HEADER="${HOST_HEADER:-}"

i=0
while true; do
  i=$((i + 1))

  curl_args=(-s -o /dev/null -w '%{http_code}')
  if [[ -n "$HOST_HEADER" ]]; then
    curl_args+=(-H "Host: $HOST_HEADER")
  fi
  code=$(curl "${curl_args[@]}" "${BASE_URL}${HEALTH_PATH}" || echo "ERR")

  ts=$(date +%H:%M:%S)
  echo "[$ts] request $i -> $code"

  sleep 0.2
done
