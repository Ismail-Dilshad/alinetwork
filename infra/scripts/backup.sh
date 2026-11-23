#!/usr/bin/env bash
# infra/scripts/backup.sh — nightly Postgres backup, verified, copied off-site to Cloudflare R2
# Runs from cron at 03:15 (installed by setup-server.sh).
# One-time: configure rclone with a remote named "r2"  →  rclone config
set -euo pipefail

ROOT="/srv/alinetwork"
source "$ROOT/secrets/data.env"
DIR="$ROOT/backups/postgres"
STAMP=$(date +%Y-%m-%d_%H%M)
FILE="$DIR/alinetwork_prod_$STAMP.dump"
CONTAINER="alinetwork-postgres-1"

echo "[$(date)] Backup started"

# 1. Dump (custom format: compressed, restorable table by table)
docker exec "$CONTAINER" pg_dump -U "$PG_SUPERUSER" -Fc alinetwork_prod > "$FILE"

# 2. Verify the dump can be read
docker exec -i "$CONTAINER" pg_restore --list < "$FILE" > /dev/null

# 3. Copy off this server (R2 bucket with lifecycle: 30 daily + 12 monthly)
rclone copy "$FILE" "r2:alinetwork-backups/postgres/" --s3-no-check-bucket

# 4. Keep 7 days locally
find "$DIR" -name '*.dump' -mtime +7 -delete

echo "[$(date)] Backup OK: $(du -h "$FILE" | cut -f1)"
# Meilisearch needs no backup: the search index is rebuilt from Postgres.
# Images need no backup here: they live in R2 (enable R2 object versioning).
