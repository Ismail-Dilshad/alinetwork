# 08 — Infrastructure

Full details and scripts: `infra/README.md`. Summary:

## Hosting

One Hostinger VPS KVM 8 (8 vCPU, 32 GB RAM, 400 GB NVMe) at launch:
- **Caddy**: HTTPS + one site block per address (`infra/caddy/Caddyfile`)
- **PM2**: Node apps (`infra/pm2/ecosystem.config.cjs`)
- **Docker**: data services only (`infra/docker/compose.server.yml`), bound to 127.0.0.1
- **Cloudflare**: DNS, proxy, DDoS; **R2** for images (cdn.) and backups

## Addresses

| Address | Serves | Runs as | Port |
| --- | --- | --- | --- |
| alinetwork.store | Storefront | PM2 `prod-storefront` ×2 | 3000 |
| www.alinetwork.store | Redirect to shop | Caddy | — |
| api.alinetwork.store | API (+ `/v1/pos/sync`) | PM2 `prod-api` ×3 + `prod-worker` | 4000 |
| manage.alinetwork.store | Business console | Caddy static files | — |
| ops.alinetwork.store | Admin console | Caddy static + login gate | — |
| cdn.alinetwork.store | Images | Cloudflare R2 custom domain | — |
| status.alinetwork.store | Status page | Hosted service (CNAME) | — |
| staging. / staging-api. / staging-manage. / staging-ops. | Test copies | Same, ports 3100/4100 | — |
| sync.alinetwork.store | LATER: Go sync gateway | PM2 | 4500 |

## Environments

| Env | Where | Data | Deploy trigger |
| --- | --- | --- | --- |
| local | Laptop | `infra/docker/compose.dev.yml` | `pnpm dev` |
| CI | GitHub Actions | service containers | every push/PR |
| staging | VPS | `alinetwork_staging` DB | push to `main` |
| production | VPS | `alinetwork_prod` DB | tag `v*` + approval |

## Environment variables

Templates: `infra/env/*.example`. Apps validate env at startup with Zod and refuse to
start if anything required is missing. Root `.env.example` lists local dev values.

## Deploy

`infra/scripts/deploy.sh`: build release → migrate → switch symlink → PM2 reload →
health check → automatic rollback on failure. Last 5 releases kept.

## Backups

`infra/scripts/backup.sh` nightly at 03:15: Postgres dump → verify → R2 (30 daily +
12 monthly). Monthly restore test into a scratch database.

## Mobile apps

- POS and mobile built with **EAS Build**; POS distributed as internal Android APK/AAB
  via EAS (or MDM) to store tablets; mobile app to App Store + Google Play.
- Over-the-air updates (EAS Update) for JS-only changes; channels `staging` and `production`.
