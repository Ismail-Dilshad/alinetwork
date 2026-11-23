#!/usr/bin/env bash
# infra/scripts/deploy.sh — build a release, migrate, switch, health-check, auto-rollback
# Usage:
#   deploy.sh staging main          (branch)
#   deploy.sh production v1.4.0     (tag)
#   deploy.sh production 3f9c2ab    (commit)
#   deploy.sh production rollback   (previous release)
set -euo pipefail

ENV="${1:?usage: deploy.sh <production|staging> <git-ref|rollback>}"
REF="${2:?usage: deploy.sh <production|staging> <git-ref|rollback>}"
[[ "$ENV" == "production" || "$ENV" == "staging" ]] || { echo "bad env"; exit 1; }

ROOT="/srv/alinetwork"
BASE="$ROOT/$ENV"
SECRETS="$ROOT/secrets/$ENV"
REPO="git@github.com:YOUR_ORG/alinetwork.git"
ECOSYSTEM="$ROOT/infra/pm2/ecosystem.config.cjs"
KEEP=5

if [[ "$ENV" == "production" ]]; then P="prod"; API_PORT=4000; WEB_PORT=3000
else P="staging"; API_PORT=4100; WEB_PORT=3100; fi
APPS="${P}-api,${P}-worker,${P}-storefront"

# Only one deploy at a time
exec 9>"/tmp/alinetwork-deploy-$ENV.lock"
flock -n 9 || { echo "Another deploy is running"; exit 1; }

switch_to() {
  ln -sfn "$1" "$BASE/current"
  pm2 startOrReload "$ECOSYSTEM" --only "$APPS" --update-env
  pm2 save
}

healthy() {
  for i in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$API_PORT/health" >/dev/null \
       && curl -fsS -o /dev/null "http://127.0.0.1:$WEB_PORT/"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if [[ "$REF" == "rollback" ]]; then
  PREV=$(ls -1dt "$BASE"/releases/* | sed -n 2p)
  [[ -n "$PREV" ]] || { echo "No previous release"; exit 1; }
  switch_to "$PREV"
  echo "Rolled back $ENV to $PREV"; exit 0
fi

PREVIOUS=$(readlink -f "$BASE/current" || true)
RELEASE="$BASE/releases/$(date +%Y%m%d-%H%M%S)"

echo "==> Fetching $REF"
git clone --filter=blob:none --quiet "$REPO" "$RELEASE"
git -C "$RELEASE" checkout --quiet "$REF"
cd "$RELEASE"

echo "==> Building"
set -a; source "$SECRETS/build.env"; set +a
pnpm install --frozen-lockfile
pnpm turbo run build \
  --filter=@alinetwork/api --filter=@alinetwork/storefront \
  --filter=@alinetwork/console --filter=@alinetwork/admin

# Next.js standalone needs its static files next to server.js
SF=apps/storefront/.next/standalone/apps/storefront
cp -r apps/storefront/.next/static "$SF/.next/"
cp -r apps/storefront/public "$SF/"

echo "==> Migrating database (backward-compatible migrations only)"
node --env-file="$SECRETS/api.env" services/api/dist/migrate.js

if [[ "$ENV" == "production" ]]; then
  echo "==> Updating server config from this release"
  rsync -a --delete --exclude 'env/' "$RELEASE/infra/" "$ROOT/infra/"
  caddy validate --config "$ROOT/infra/caddy/Caddyfile" --adapter caddyfile
  sudo systemctl reload caddy
fi

echo "==> Switching to new release"
switch_to "$RELEASE"

echo "==> Health check"
if ! healthy; then
  echo "!! Health check failed, rolling back"
  [[ -n "$PREVIOUS" ]] && switch_to "$PREVIOUS"
  exit 1
fi

echo "==> Cleaning old releases"
ls -1dt "$BASE"/releases/* | tail -n +$((KEEP + 1)) | xargs -r rm -rf

echo "Deployed $REF to $ENV ($RELEASE)"
