# 09 — Build plan (36 steps)

Run **one step at a time** with `/next-step`. Each step names its agent, what to read,
what to build, and the checks that must pass. After every step: `security-reviewer`
reviews if the step is marked 🔒, then the human reviews and commits.

Phases and gates match the roadmap:
- **Phase 0 Foundation** S01–S10
- **Phase 1 Sell in a store** S11–S24 → Gate 1: a pilot branch runs one full week on the POS with exact stock
- **Phase 2 Sell online** S25–S29 → Gate 2: online and in-store sell from one stock, zero oversells
- **Phase 3 App and insights** S30–S33 → Gate 3: every branch live, all channels in the owner dashboard
- **Phase 4 Scale and integrate** S34–S36

Standard verify command (used by every step unless stated):
```bash
pnpm turbo run lint typecheck test build
```

---

## Phase 0 — Foundation

### S01 — Monorepo skeleton
- **Agent:** architect
- **Read:** CLAUDE.md, docs/01-structure.md, docs/adr/*
- **Build:**
  - Root: `package.json` (scripts: dev, build, lint, typecheck, test, format), `pnpm-workspace.yaml`, `turbo.json`, `tsconfig.base.json` (strict, noUncheckedIndexedAccess), `.editorconfig`, `.gitignore`, `.nvmrc` (22), `.npmrc`, `.env.example`
  - `packages/config`: shared tsconfigs (node, react, react-native, next), ESLint flat config, Prettier, dependency-cruiser preset
  - Empty but buildable packages: `utils`, `schemas`, `commerce-rules`, `tokens`, `i18n`, `contracts`, `ui-web`, `ui-native` (each with package.json, tsconfig, `src/index.ts`, one passing test)
  - `packages/utils`: `newId()` (UUIDv7), `formatMoney()`, date helpers + tests
- **Done when:**
  - [ ] `pnpm install` works on a clean clone
  - [ ] Standard verify passes
  - [ ] Every package name matches docs/01-structure.md

### S02 — API skeleton, boundaries, CI
- **Agent:** architect
- **Depends on:** S01
- **Read:** docs/01-structure.md (services/api), docs/02-architecture.md
- **Build:**
  - `services/api` NestJS app: `main.ts` with `APP_MODE=api|worker`, `app.module.ts`, `platform/config` (Zod env validation), `platform/http` (error filter, request id), `platform/health` (`GET /health`), `platform/telemetry` (pino logger)
  - Empty modules with the exact folder shape for all 15 modules (settings … reports), each with `public/index.ts` and module file
  - dependency-cruiser rule: modules may import other modules only via `public/`; platform may not import modules
  - `.github/workflows/ci.yml`: install, lint, typecheck, test, build, depcruise (keep the existing `deploy.yml`)
- **Done when:**
  - [ ] `pnpm --filter @alinetwork/api dev` serves `GET /health` → `{ status: "ok" }`
  - [ ] A deliberate import of `modules/catalog/domain/x` from `modules/orders` fails `pnpm depcruise` (test then remove)
  - [ ] Standard verify passes

### S03 — Local environment
- **Agent:** devops
- **Depends on:** S02
- **Read:** infra/README.md, docs/08-infrastructure.md
- **Build:**
  - Check `infra/docker/compose.dev.yml` works; root scripts `services:up`, `services:down`, `services:reset`
  - Root `.env.example` + `services/api/.env.example` for local values
  - `platform/db` (Drizzle client + transaction helper), `platform/jobs` (BullMQ connection), `platform/storage` (S3 client pointing to local RustFS), `platform/search` (Meilisearch client) — connect only, no business code
  - `/health` reports db, redis, search, storage status
- **Done when:**
  - [ ] `pnpm services:up && pnpm --filter @alinetwork/api dev` → `/health` all green
  - [ ] Standard verify passes

### S04 — Database: platform, settings, identity, branches, audit 🔒
- **Agent:** database
- **Depends on:** S03
- **Read:** docs/03-data-model.md (conventions, platform, settings, identity, branches, audit)
- **Build:** Drizzle schemas in each module's `db/schema.ts`, migrations, `migrate.ts`, outbox + idempotency + change_log + processed_events tables, audit partitioning (monthly), RLS helper functions
- **Done when:**
  - [ ] `db:migrate` on an empty DB succeeds; running it twice is a no-op
  - [ ] Schema matches the data model doc (report lists any deviation)
  - [ ] Standard verify passes

### S05 — Database: catalog, pricing, inventory, customers, promotions
- **Agent:** database
- **Depends on:** S04
- **Read:** docs/03-data-model.md (those sections)
- **Build:** schemas, migrations, indexes listed in the doc, `inventory/jobs/rebuild-levels` query
- **Done when:** [ ] migrations clean · [ ] indexes exist · [ ] standard verify passes

### S06 — Database: checkout, orders, payments, fulfillment, pos-ops, reports + RLS + seed 🔒
- **Agent:** database
- **Depends on:** S05
- **Read:** docs/03-data-model.md (rest + RLS), docs/04-business-logic.md §13–14
- **Build:** remaining schemas; RLS policies; API DB role (non-owner, FORCE RLS); `seed.ts`: business profile, settings defaults from docs/11-open-decisions.md, 3 branches (BGD1, EBL1, WEB), roles + permission matrix, 10 staff (one per role + extras), 500 products / ~1,200 variants with barcodes and prices, stock in each branch, 200 customers, 3 delivery zones, 2 promotions
- **Done when:**
  - [ ] Seed runs in < 60 s on a fresh DB
  - [ ] Integration test: a session scoped to BGD1 cannot read EBL1 shifts or orders
  - [ ] Standard verify passes

### S07 — API contract, schemas, client, mock server
- **Agent:** api-contract
- **Depends on:** S06
- **Read:** docs/05-api.md, docs/03-data-model.md, docs/04-business-logic.md
- **Build:** `packages/contracts/openapi.yaml` for every endpoint in docs/05-api.md (phases 1–2 fully specified, phase 3–4 stubs), shared components (Money, Error, Page), Zod schemas in `packages/schemas`, generated client (openapi-typescript + openapi-fetch) in `packages/contracts/src`, mock server (Prism) script `pnpm contracts:mock` on port 4010 with realistic examples (Arabic names, IQD prices)
- **Done when:**
  - [ ] Spec validates (redocly lint) with zero errors
  - [ ] Client builds and is importable by apps
  - [ ] Mock server answers every endpoint
  - [ ] Standard verify passes

### S08 — Commerce rules engine
- **Agent:** rules-engine
- **Depends on:** S07
- **Read:** docs/04-business-logic.md §1–7, §10, §12
- **Build:** `packages/commerce-rules`: money ops, cash rounding, price resolution, promotions, manual discount limits, tax (inclusive/exclusive), proportional distribution, totals, refund proportion, loyalty earn/redeem; JSON test cases in `test-cases/`
- **Done when:**
  - [ ] ≥ 200 table-driven test cases, 100% branch coverage
  - [ ] No floating point in money paths (lint rule or test)
  - [ ] Runs under Node and Hermes (a test in `apps/pos` imports and runs it — add a minimal check script)
  - [ ] Standard verify passes

### S09 — Design tokens + web components
- **Agent:** design-system
- **Depends on:** S01
- **Read:** docs/06-design-system.md
- **Build:** `packages/tokens` (Style Dictionary → CSS variables + TS theme, light/dark), `packages/i18n` setup (ar default, ckb, en; key format), `packages/ui-web` components listed in the doc with Storybook (light, dark, RTL stories), fonts (Vazirmatn + Inter)
- **Done when:**
  - [ ] Every listed web component has light/dark/RTL stories
  - [ ] Storybook a11y addon shows no violations
  - [ ] Standard verify passes

### S10 — Native components
- **Agent:** design-system
- **Depends on:** S09
- **Read:** docs/06-design-system.md
- **Build:** `packages/ui-native` components listed in the doc, using tokens theme; RTL via `I18nManager`; a demo screen in `apps/pos` (temporary) to render them
- **Done when:** [ ] components render in Expo on Android tablet emulator, light/dark, RTL · [ ] standard verify passes

---

## Phase 1 — Sell in a store

### S11 — Identity, auth, permissions 🔒
- **Agent:** identity-access
- **Depends on:** S08
- **Read:** docs/07-security.md, docs/04-business-logic.md §14–15, docs/05-api.md (Auth, Staff & roles)
- **Build:** staff login + TOTP + passkeys, POS PIN login, refresh rotation, `platform/auth` guards (`@RequirePermission`, branch scope), RLS session setter per request, staff & roles endpoints, acting-as sessions, platform/idempotency interceptor, platform/audit writer
- **Done when:**
  - [ ] Test matrix: every role × every permission key behaves as in the doc
  - [ ] Refresh token reuse revokes the session family
  - [ ] Idempotent POST replays the same response
  - [ ] Standard verify passes

### S12 — Settings, branches, devices, audit endpoints 🔒
- **Agent:** identity-access
- **Depends on:** S11
- **Build:** settings, branches, registers, device registration (one-time code) + revoke, feature flags, integrations (encrypted config), audit list + security alerts, order number sequences + POS number blocks
- **Done when:** [ ] revoked device rejected on next request · [ ] every write appears in audit · [ ] contract tests pass · [ ] standard verify passes

### S13 — Catalog and pricing
- **Agent:** catalog-stock
- **Depends on:** S12
- **Read:** docs/04-business-logic.md §3–4, docs/05-api.md (Catalog, Pricing)
- **Build:** products/variants/options/categories/collections/barcodes CRUD, media presigned upload, price lists + bulk prices + resolve (using commerce-rules), tax classes, cost prices, events `product.*`, `price.changed`, Meilisearch indexing via worker
- **Done when:** [ ] search returns Arabic products by partial name · [ ] price resolution tests match doc cases · [ ] contract tests pass · [ ] standard verify passes

### S14 — Inventory
- **Agent:** catalog-stock
- **Depends on:** S13
- **Read:** docs/04-business-logic.md §7
- **Build:** levels, movements, adjustments, transfers (send/receive), stock counts (apply), purchase receipts, reservations + expiry job, low-stock events, change_log entries for POS sync, rebuild-levels job
- **Done when:**
  - [ ] Concurrency test: 50 parallel reservations for the last 10 units never oversell
  - [ ] Levels always equal the sum of movements (property test)
  - [ ] Standard verify passes

### S15 — Customers and promotions
- **Agent:** store-ops
- **Depends on:** S13
- **Read:** docs/04-business-logic.md §5, §12
- **Build:** customers CRUD + POS search (trigram), addresses, loyalty accounts + ledger, promotions + coupons CRUD + validate (logic from commerce-rules)
- **Done when:** [ ] POS customer search by partial phone/name < 100 ms on seed data · [ ] standard verify passes

### S16 — Orders and in-store payments 🔒
- **Agent:** orders-payments
- **Depends on:** S14, S15
- **Read:** docs/04-business-logic.md §6, §8–11, §13
- **Build:** order creation for POS/console (one transaction: order + lines + stock movements + payment + outbox), state machine functions + history, cancel, returns + refunds (cash, card terminal), payment adapter interface + cash + card-terminal adapters, split payments, events
- **Done when:**
  - [ ] Same sale sent 3× with one idempotency key creates one order
  - [ ] Totals equal commerce-rules output for all seed test cases
  - [ ] Return of 1 of 3 discounted units refunds the correct proportional amount
  - [ ] Standard verify passes

### S17 — Shifts and POS sync endpoints 🔒
- **Agent:** store-ops
- **Depends on:** S16
- **Read:** docs/02-architecture.md (Offline POS), docs/04-business-logic.md §11
- **Build:** shifts open/close, cash movements, expected cash, variance alerts, Z-report; `/pos/bootstrap`, `/pos/sync/changes` (cursor over change_log), `/pos/sync/sales` (batch, per-sale result), negative-stock flags
- **Done when:**
  - [ ] Simulated device offline 8 h with 300 sales syncs with correct stock and no duplicates
  - [ ] Shift report matches sales to the dinar
  - [ ] Standard verify passes

### S18 — Business console: shell, products, inventory
- **Agent:** business-console
- **Depends on:** S13, S14 (can start on mock server after S07)
- **Read:** docs/06-design-system.md, docs/00-overview.md (roles)
- **Build:** login (+MFA), app shell (sidebar from permissions, branch switcher, locale switch), products list/editor/variants/media/bulk import, categories, price lists, inventory levels, adjustments, transfers, counts, receipts
- **Done when:** [ ] data entry user adds 20 products by keyboard only · [ ] RTL correct in ar/ckb · [ ] Playwright e2e for create product + transfer · [ ] standard verify passes

### S19 — Business console: orders, customers, staff, promotions, reports v1
- **Agent:** business-console
- **Depends on:** S16, S17, S18
- **Build:** orders list/detail/actions, returns, customers, promotions/coupons, staff + roles editor (for owner/admin), shifts + Z-reports, basic reports (daily sales by branch/channel, top products, cash variance), history tab (audit) on records
- **Done when:** [ ] permissions hide and block correctly per role (e2e for cashier vs owner) · [ ] standard verify passes

### S20 — Admin console 🔒
- **Agent:** admin-console
- **Depends on:** S12
- **Build:** branches, registers, devices (registration codes, revoke), roles/permissions, integrations, feature flags, settings, audit + security alerts, system health (queues, sync lag per device, failed webhooks), acting-as with red bar
- **Done when:** [ ] every admin action appears in the owner's audit view · [ ] standard verify passes

### S21 — POS app: device, login, local DB, sync
- **Agent:** pos-app
- **Depends on:** S17, S10
- **Read:** docs/02-architecture.md (Offline POS)
- **Build:** device registration, PIN login, expo-sqlite schema + migrations, pull sync (cursor, paging, background), local outbox + push, sync status UI, offline badge
- **Done when:** [ ] fresh device bootstraps 1,200 variants in < 60 s · [ ] airplane mode → back online syncs queued data · [ ] standard verify passes

### S22 — POS app: selling and payment
- **Agent:** pos-app
- **Depends on:** S21
- **Build:** sell screen (scan, search, quantity, line/manual discounts with limits + manager PIN), customer attach, payment (cash with change + rounding, card terminal code, split), receipt print (ESC/POS over Bluetooth/USB), cash drawer kick, totals via commerce-rules
- **Done when:** [ ] 5-item cash sale in < 15 s by a trained user · [ ] totals identical to API for the same cart · [ ] Maestro flow for a sale · [ ] standard verify passes

### S23 — POS app: shifts, returns, offline hardening
- **Agent:** pos-app
- **Depends on:** S22
- **Build:** open/close shift, cash in/out, Z-report print, returns (online only) with manager PIN, offline limits from settings, number blocks for offline order numbers, crash-safe local writes
- **Done when:** [ ] full day offline (Maestro + script, 300 sales) syncs with zero lost sales · [ ] standard verify passes

### S24 — Gate 1: QA + security review
- **Agents:** qa, then security-reviewer
- **Build:** e2e suite for store flows, contract tests for all phase-1 endpoints, k6 load test at 10× expected store traffic, security review of auth, payments, RLS, devices
- **Done when:** [ ] all suites green · [ ] no open high/critical security findings · [ ] staging deployed · [ ] **human runs the pilot branch for one week** before Phase 2

---

## Phase 2 — Sell online

### S25 — Checkout, delivery, reservations 🔒
- **Agent:** orders-payments (with catalog-stock for reservations)
- **Depends on:** S24
- **Build:** carts, coupon apply, delivery zones + quote + drivers + shipments + pickups, checkout (order placed + reservation + payment intent), COD confirmation flow, cancellation releases stock
- **Done when:** [ ] 50 parallel checkouts on last 10 units never oversell · [ ] standard verify passes

### S26 — Payment gateways 🔒
- **Agent:** orders-payments
- **Depends on:** S25
- **Build:** FIB, ZainCash, Qi Card adapters (sandbox), webhooks with signature verification, status polling fallback, intent expiry job, COD handover + reconciliation, nightly reconciliation report
- **Done when:** [ ] replaying every webhook twice changes nothing · [ ] expired intent releases stock · [ ] standard verify passes

### S27 — Storefront: browse
- **Agent:** storefront
- **Depends on:** S13 (mock server allowed earlier)
- **Build:** layout (ar default, RTL), home, category, search (Meilisearch), product page (variants, gallery, stock badge, delivery estimate), SEO (metadata, sitemap, product structured data), app links files
- **Done when:** [ ] product page LCP < 2.5 s on throttled 4G (Lighthouse CI) · [ ] standard verify passes

### S28 — Storefront: cart, checkout, account
- **Agent:** storefront
- **Depends on:** S26, S27
- **Build:** cart, checkout (address, zone, fee, payment method incl. COD/FIB/ZainCash/Qi), success/failed pages, OTP login, account (orders, addresses, loyalty), order tracking
- **Done when:** [ ] Playwright: full checkout for each payment method on staging sandbox · [ ] standard verify passes

### S29 — Gate 2: QA + security review
- **Agents:** qa, security-reviewer
- **Done when:** [ ] online + store sell from one stock with zero oversells under load · [ ] payment security review passed · [ ] **human approves production launch of the shop**

---

## Phase 3 — App and insights

### S30 — Mobile app
- **Agent:** mobile-app
- **Depends on:** S28
- **Build:** shop flows reusing client/schemas, push notifications, deep links, wishlist, reorder, biometric login, EAS build + update channels
- **Done when:** [ ] test builds pass App Store/Play pre-review checks · [ ] standard verify passes

### S31 — Owner dashboard + analytics
- **Agents:** devops (ClickHouse service) then business-console (UI) with orders-payments (event feed)
- **Build:** ClickHouse in compose, event → ClickHouse feed, dashboard (sales by channel/branch, margin, top/slow products, stock-out risk, staff performance, cash variance), exports
- **Done when:** [ ] dashboard loads 12 months of seeded data in < 2 s · [ ] standard verify passes

### S32 — Promotions and loyalty complete
- **Agent:** store-ops
- **Build:** buy-x-get-y, scheduled promotions, customer segments, loyalty redemption in POS and online, notification triggers (SMS/push)
- **Done when:** [ ] commerce-rules cases for every promotion type pass in API and POS · [ ] standard verify passes

### S33 — Gate 3
- **Agents:** qa, security-reviewer
- **Done when:** [ ] every branch live · [ ] all three channels in the owner dashboard · [ ] human sign-off

---

## Phase 4 — Scale and integrate

### S34 — Integrations API and webhooks
- **Agent:** orders-payments (with api-contract)
- **Build:** API keys, outgoing webhook subscriptions (signed), accounting export, courier integration hook
- **Done when:** [ ] webhook deliveries retried with backoff and signed · [ ] standard verify passes

### S35 — Hardening
- **Agents:** devops, qa
- **Build:** load test at 10× normal traffic, slow-query review, read replica plan, restore drill, runbooks in `docs/runbooks/`
- **Done when:** [ ] p95 API < 300 ms at target load · [ ] restore drill documented

### S36 — Production readiness review
- **Agents:** security-reviewer, qa, devops
- **Done when:** [ ] checklist in docs/10-testing.md "Launch checklist" fully ticked · [ ] human sign-off
