#!/usr/bin/env bash
# Deploy Meditator backend (production Compose stack).
# Run from anywhere; uses backend directory as project root for Compose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${BACKEND_ROOT}"

COMPOSE=(docker compose --env-file .env.prod -f docker-compose.prod.yml)

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH" >&2
  exit 1
fi

if [[ ! -f .env.prod ]]; then
  echo "error: missing .env.prod (copy from .env.prod.example)" >&2
  exit 1
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  GIT_ROOT="$(git rev-parse --show-toplevel)"
  echo "Pulling latest Git revision in ${GIT_ROOT}..."
  git -C "${GIT_ROOT}" pull --ff-only
fi

echo "Building images..."
"${COMPOSE[@]}" build --pull

echo "Starting Postgres..."
"${COMPOSE[@]}" up -d postgres

echo "Waiting for Postgres to accept connections..."
attempts=0
until "${COMPOSE[@]}" exec -T postgres pg_isready >/dev/null 2>&1; do
  attempts=$((attempts + 1))
  if [[ "${attempts}" -ge 60 ]]; then
    echo "error: Postgres did not become ready in time" >&2
    exit 1
  fi
  sleep 2
done

echo "Running Alembic migrations..."
"${COMPOSE[@]}" run --rm --entrypoint alembic backend upgrade head

echo "Starting all services..."
"${COMPOSE[@]}" up -d

echo "Waiting for backend health..."
attempts=0
until "${COMPOSE[@]}" exec -iT backend python - <<'PY' >/dev/null 2>&1
import sys
import urllib.error
import urllib.request

try:
    r = urllib.request.urlopen("http://127.0.0.1:8080/health", timeout=10)
    sys.exit(0 if r.getcode() == 200 else 1)
except urllib.error.HTTPError:
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
do
  attempts=$((attempts + 1))
  if [[ "${attempts}" -ge 45 ]]; then
    echo "error: backend /health did not succeed in time" >&2
    "${COMPOSE[@]}" ps
    exit 1
  fi
  sleep 2
done

echo "Deploy complete: backend /health OK."
