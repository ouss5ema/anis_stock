#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /opt/stock-management/backups/stock-YYYYMMDD-HHMMSS.sql.gz"
  exit 1
fi

FILE=$1
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.production}"
SERVICE="${POSTGRES_SERVICE:-postgres}"

if [[ ! -f "$FILE" ]]; then
  echo "Backup file not found: $FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

DB_USER="$(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv POSTGRES_USER | tr -d '\r')"
DB_NAME="$(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv POSTGRES_DB | tr -d '\r')"

echo "Restoring $FILE into $DB_NAME (this overwrites current data in that database)"
gunzip -c "$FILE" | docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  psql -U "$DB_USER" -d "$DB_NAME"
echo "Restore completed"
