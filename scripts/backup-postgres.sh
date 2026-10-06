#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.production}"
SERVICE="${POSTGRES_SERVICE:-postgres}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

BACKUP_DIR="$(grep '^BACKUP_DIR=' "$ENV_FILE" | cut -d= -f2- || true)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/../backups}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR" 2>/dev/null || true

STAMP=$(date +%Y%m%d-%H%M%S)
FILE="$BACKUP_DIR/stock-$STAMP.sql.gz"

DB_USER="$(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv POSTGRES_USER | tr -d '\r')"
DB_NAME="$(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv POSTGRES_DB | tr -d '\r')"

echo "Creating backup $FILE"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$FILE"
chmod 600 "$FILE"
echo "Backup written to $FILE"
echo "Keep several copies off-server. Do not delete old backups without a retention plan."
