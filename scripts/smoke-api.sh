#!/usr/bin/env bash
set -euo pipefail

base_url="${API_BASE_URL:-http://127.0.0.1:3000/api/v1}"
base_url="${base_url%/}"

health="$(curl --fail --silent --show-error --retry 5 --retry-delay 1 "$base_url/health")"
ready="$(curl --fail --silent --show-error --retry 5 --retry-delay 1 "$base_url/health/ready")"

node - "$health" "$ready" <<'NODE'
const [healthRaw, readyRaw] = process.argv.slice(2);
const health = JSON.parse(healthRaw);
const ready = JSON.parse(readyRaw);
if (!['ok', 'degraded'].includes(health.status)) throw new Error(`Unexpected liveness status: ${health.status}`);
if (ready.status !== 'ready' || ready.database !== true) throw new Error('Readiness did not confirm the database');
console.log(`API smoke passed: ${health.status}, ${ready.status}`);
NODE
