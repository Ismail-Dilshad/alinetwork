# AliNetwork infrastructure

One Hostinger VPS (KVM 8: 8 vCPU, 32 GB RAM, 400 GB NVMe) running:

- **Caddy**: HTTPS and routing, one site block per address
- **PM2**: the Node apps (API, worker, storefront), production + staging
- **Docker**: data services only (Postgres, Valkey, Meilisearch), bound to 127.0.0.1
- **Cloudflare**: DNS, proxy and DDoS protection, plus **R2** for images (cdn.) and off-site backups

Every address is separate, so any part can later move to its own server by
changing one DNS record and one Caddy block.

## Folder contents

```
infra/
├── README.md                     this file
├── docker/
│   ├── compose.dev.yml           laptops + AI agents: Postgres, Valkey, Meilisearch, S3 (RustFS), Mailpit
│   ├── compose.server.yml        VPS: Postgres, Valkey (prod + staging), Meilisearch
│   └── postgres/init/            creates alinetwork_prod + alinetwork_staging on first start
├── caddy/Caddyfile               every address → its process or folder
├── pm2/ecosystem.config.cjs      prod + staging Node processes
├── env/*.example                 templates for the real secret files (never committed)
└── scripts/
    ├── setup-server.sh           one-time VPS setup (user, SSH, firewall, Docker, Node, PM2, Caddy)
    ├── deploy.sh                 build → migrate → switch → health check → auto-rollback
    └── backup.sh                 nightly Postgres dump → verify → copy to R2
.github/workflows/deploy.yml      main → staging, tag v* → production (with approval)
```

## Address map

| Address | Serves | Runs as | Port |
| --- | --- | --- | --- |
| alinetwork.store | Online shop | PM2 `prod-storefront` ×2 | 3000 |
| www.alinetwork.store | Redirect to the shop | Caddy | — |
| api.alinetwork.store | API + POS sync (`/v1/pos/sync`) | PM2 `prod-api` ×3 | 4000 |
| — | Jobs, outbox, webhooks | PM2 `prod-worker` | — |
| manage.alinetwork.store | Business console | Static files via Caddy | — |
| ops.alinetwork.store | System admin console | Static files + login gate | — |
| cdn.alinetwork.store | Images | Cloudflare R2 custom domain | — |
| status.alinetwork.store | Status page | Hosted service (CNAME) | — |
| staging.alinetwork.store | Shop (test) | PM2 `staging-storefront` | 3100 |
| staging-api.alinetwork.store | API (test) | PM2 `staging-api` | 4100 |
| staging-manage.alinetwork.store | Business console (test) | Static files | — |
| staging-ops.alinetwork.store | Admin console (test) | Static files | — |
| sync.alinetwork.store | LATER: Go sync gateway | PM2 `prod-sync` | 4500 |

Internal only (127.0.0.1): Postgres 5432 · Valkey 6379 (prod), 6380 (staging) · Meilisearch 7700.

Staging uses flat names (`staging-api`, not `api.staging`) because Cloudflare's
free certificate covers only one subdomain level when the proxy is on.

## Server layout

```
/srv/alinetwork/
├── infra/                    copy of this folder (updated by each production deploy)
├── secrets/                  chmod 700, never in git
│   ├── data.env
│   ├── production/  api.env · storefront.env · build.env
│   └── staging/     api.env · storefront.env · build.env
├── production/
│   ├── current -> releases/20261123-180000
│   └── releases/             last 5 builds
├── staging/                  same shape
├── data/                     Docker volumes (postgres, valkey, meili)
└── backups/postgres/         last 7 days locally (30 daily + 12 monthly in R2)
/var/log/alinetwork/          PM2 + backup logs (rotated)
/etc/caddy/Caddyfile -> /srv/alinetwork/infra/caddy/Caddyfile
```

## DNS (Cloudflare)

| Type | Name | Value | Proxy |
| --- | --- | --- | --- |
| A | @, www, api, manage, ops | VPS IP | On |
| A | staging, staging-api, staging-manage, staging-ops | VPS IP | On |
| R2 custom domain | cdn | bucket `alinetwork-media` | (set in R2 settings) |
| CNAME | status | status provider | Off |
| TXT / MX | mail | SPF, DKIM, DMARC from the email provider | Off |

SSL/TLS mode: **Full (strict)**. Lock `ops` further with Cloudflare Access (free for small teams).

## First-time setup

1. Hostinger panel: install Ubuntu 24.04, add your SSH key.
2. `ssh root@VPS_IP` and run `bash infra/scripts/setup-server.sh`.
3. Follow the steps it prints: deploy key on GitHub, secrets, start Docker services, link Caddyfile, first deploys.
4. Cloudflare: R2 buckets `alinetwork-media`, `alinetwork-media-staging`, `alinetwork-backups`;
   API tokens into `api.env`; `rclone config` on the server with a remote named `r2`.
5. GitHub: add secrets `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`; set yourself as required reviewer on the `production` environment.

## Daily work

| Task | Command |
| --- | --- |
| Start local services | `docker compose -f infra/docker/compose.dev.yml up -d` |
| Ship to staging | push to `main` |
| Ship to production | `git tag v1.2.0 && git push --tags`, then approve in GitHub |
| Roll back | `infra/scripts/deploy.sh production rollback` |
| See processes | `pm2 status` · `pm2 logs prod-api` · `pm2 monit` |
| Data services | `docker compose -f /srv/alinetwork/infra/docker/compose.server.yml ps` |
| Restore test (monthly) | `pg_restore` the latest dump into a scratch database and check row counts |

## How it scales (no rewrite at any step)

| Step | Trigger | Change |
| --- | --- | --- |
| 1 | Launch | Everything on this KVM 8 |
| 2 | CPU/RAM above ~70% at peak | Move staging to a small separate VPS |
| 3 | Database competes with the apps | Move `compose.server.yml` + data to its own VPS; update `DATABASE_URL` |
| 4 | API needs more power | Second app VPS; Cloudflare load balancer for api.alinetwork.store |
| 5 | POS sync is the bottleneck | Go sync gateway on sync.alinetwork.store |

## Honest limits

- One server is a single point of failure. The POS keeps selling offline; the online shop does not.
- Do step 3 (separate database server) before big seasons such as Ramadan and Eid.
- Never rely on Hostinger's weekly backup alone; the nightly R2 backup is the real one.
