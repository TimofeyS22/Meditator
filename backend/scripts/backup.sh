#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/backups/postgres"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="backend-postgres-1"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting PostgreSQL backup..."

docker exec "$CONTAINER_NAME" pg_dump \
    -U "${POSTGRES_USER:-meditator}" \
    -d "${POSTGRES_DB:-meditator}" \
    --format=custom \
    --compress=9 \
    > "$BACKUP_DIR/meditator_${TIMESTAMP}.dump"

echo "[$(date)] Backup created: meditator_${TIMESTAMP}.dump"

find "$BACKUP_DIR" -name "meditator_*.dump" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] Old backups cleaned (retention: ${RETENTION_DAYS} days)"

echo "[$(date)] Backup complete."
