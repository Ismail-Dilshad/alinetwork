# 01 — Folder and file structure

This is the target structure. The Architect agent creates the skeleton in S01–S02;
other agents fill their own folders. **Never create top-level folders that are not here.**

## Top level

```
alinetwork/
├── apps/                       everything users touch
│   ├── storefront/             Next.js · alinetwork.store
│   ├── console/                React + Vite · manage.alinetwork.store
│   ├── admin/                  React + Vite · ops.alinetwork.store
│   ├── pos/                    Expo · store tablets (offline-first)
│   └── mobile/                 Expo · iOS + Android shop app
├── services/
│   ├── api/                    NestJS modular monolith · api.alinetwork.store
│   ├── sync-gateway/           Go · LATER (only if POS sync needs it) — do not create yet
│   └── intelligence/           Python · YEAR 2 (forecasting) — do not create yet
├── packages/
│   ├── contracts/              openapi.yaml + generated TypeScript client + mock server
│   ├── schemas/                Zod schemas shared by server and apps
│   ├── commerce-rules/         prices, tax, discounts, totals, rounding (pure functions)
│   ├── tokens/                 design tokens → CSS variables + RN theme
│   ├── ui-web/                 web components (Radix-based) + Storybook
│   ├── ui-native/              React Native components for POS + mobile
│   ├── i18n/                   translation files ar / ckb / en + helpers
│   ├── utils/                  tiny shared helpers (ids, dates, money formatting)
│   └── config/                 tsconfig, eslint, prettier, dependency-cruiser presets
├── infra/                      Docker, Caddy, PM2, env templates, scripts
├── tests/
│   ├── e2e/                    Playwright: storefront + consoles
│   ├── pos-e2e/                Maestro flows for POS
│   ├── contract/               every endpoint vs openapi.yaml
│   └── load/                   k6 scripts
├── docs/                       specification, plan, progress, ADRs, runbooks
├── .claude/                    agents + slash commands
├── .github/workflows/          ci.yml, deploy.yml
├── CLAUDE.md  AGENTS.md  START-HERE.md
├── package.json  pnpm-workspace.yaml  turbo.json  tsconfig.base.json
├── .editorconfig  .gitignore  .nvmrc  .npmrc
└── .env.example
```

## Package names

| Folder | Package name |
| --- | --- |
| services/api | `@alinetwork/api` |
| apps/storefront | `@alinetwork/storefront` |
| apps/console | `@alinetwork/console` |
| apps/admin | `@alinetwork/admin` |
| apps/pos | `@alinetwork/pos` |
| apps/mobile | `@alinetwork/mobile` |
| packages/* | `@alinetwork/<folder>` (e.g. `@alinetwork/commerce-rules`) |

## services/api

```
services/api/
├── package.json  tsconfig.json  nest-cli.json  drizzle.config.ts  vitest.config.ts
├── src/
│   ├── main.ts                 boots "api" or "worker" based on APP_MODE
│   ├── app.module.ts           imports platform + every domain module
│   ├── migrate.ts              runs Drizzle migrations (used by deploy.sh)
│   ├── seed.ts                 dev/staging seed data
│   ├── platform/               shared plumbing, no business logic
│   │   ├── config/             env loading + validation (zod)
│   │   ├── db/                 drizzle client, transaction helper, RLS session setter
│   │   ├── outbox/             outbox writer + relay (worker) + event bus
│   │   ├── jobs/               BullMQ setup, queue registry
│   │   ├── auth/               guards: authenticated, permission, branch scope
│   │   ├── idempotency/        interceptor + store
│   │   ├── audit/              audit writer used by all modules
│   │   ├── http/               error filter, request id, pagination helpers
│   │   ├── storage/            S3/R2 client
│   │   ├── search/             Meilisearch client
│   │   ├── telemetry/          logger (pino), OpenTelemetry, Sentry
│   │   └── health/             GET /health
│   └── modules/
│       ├── settings/  identity/  branches/  audit/
│       ├── catalog/  pricing/  inventory/
│       ├── customers/  promotions/
│       ├── checkout/  orders/  payments/
│       ├── fulfillment/  pos-ops/
│       └── reports/            read-only queries for dashboards
├── migrations/                 generated SQL migrations (never edit after applied)
└── test/                       integration test helpers (test DB, factories)
```

### Every module has exactly this shape

```
modules/catalog/
├── catalog.module.ts           NestJS module
├── public/                     THE ONLY folder other modules may import
│   ├── index.ts                exports below + event types
│   └── catalog.service.ts      functions other modules may call
├── http/                       controllers for /v1/... routes (thin: validate → service)
│   ├── products.controller.ts
│   └── categories.controller.ts
├── domain/                     business logic, no HTTP, no SQL
│   ├── product.ts
│   └── product.rules.ts
├── db/                         Drizzle tables (schema "catalog") + repositories
│   ├── schema.ts
│   └── products.repository.ts
├── events/                     event payload types it publishes + handlers it consumes
│   ├── catalog.events.ts
│   └── on-stock-changed.handler.ts
├── jobs/                       BullMQ processors (imports, exports, reindex)
└── __tests__/                  unit + integration tests for this module
```

Payments adds `adapters/`:

```
modules/payments/adapters/
├── payment-provider.interface.ts
├── cash.adapter.ts  card-terminal.adapter.ts  cod.adapter.ts
├── fib.adapter.ts  zaincash.adapter.ts  qicard.adapter.ts
└── __tests__/
```

## apps/storefront (Next.js)

```
apps/storefront/
├── next.config.ts  middleware.ts (locale detection)  package.json
├── app/[locale]/
│   ├── layout.tsx  page.tsx (home)
│   ├── c/[slug]/page.tsx       category
│   ├── p/[slug]/page.tsx       product
│   ├── search/page.tsx
│   ├── cart/page.tsx
│   ├── checkout/               page.tsx, success/, failed/
│   ├── account/                orders/, addresses/, profile/
│   ├── orders/[number]/track/page.tsx
│   └── (legal)/                terms/, privacy/, returns/
├── app/sitemap.ts  app/robots.ts
├── components/                 layout/, product/, cart/, checkout/
├── lib/                        api.ts (generated client), seo.ts, format.ts
├── messages/ → uses @alinetwork/i18n
└── public/.well-known/         apple-app-site-association, assetlinks.json
```

## apps/console and apps/admin (React + Vite)

```
apps/console/
├── index.html  vite.config.ts  package.json
└── src/
    ├── main.tsx  router.tsx  app-shell/ (sidebar, topbar, branch switcher)
    ├── routes/
    │   ├── dashboard/  products/  inventory/  transfers/  counts/
    │   ├── orders/  returns/  customers/  promotions/
    │   ├── staff/  shifts/  reports/  settings/
    │   └── login/
    ├── features/               feature code used by routes (forms, tables, hooks)
    ├── lib/                    api client, auth, permissions (can()), format
    └── __tests__/
apps/admin/                     same shape; routes: branches/ devices/ roles/
                                integrations/ activity/ health/ feature-flags/ audit/
```

## apps/pos (Expo, offline-first)

```
apps/pos/
├── app.json  eas.json  package.json
└── src/
    ├── app/                    expo-router screens
    │   ├── (auth)/register-device.tsx  (auth)/pin-login.tsx
    │   ├── (pos)/sell.tsx  (pos)/payment.tsx  (pos)/receipt.tsx
    │   ├── (pos)/returns.tsx  (pos)/customers.tsx
    │   └── (pos)/shift/open.tsx  close.tsx  cash-movement.tsx
    ├── db/                     expo-sqlite schema + migrations (local copy)
    ├── sync/                   pull (cursor), push (outbox queue), conflict flags
    ├── hardware/               printer (ESC/POS), scanner, cash drawer, terminal
    ├── features/               cart, payment, receipt formatting
    ├── state/                  store (zustand) for the current sale
    └── __tests__/
```

## apps/mobile (Expo)

```
apps/mobile/src/app/            (tabs)/home, search, cart, account; product/[slug];
                                checkout/; orders/[id]
apps/mobile/src/                features/, lib/ (api, auth, push), __tests__/
```

## packages

```
packages/contracts/   openapi.yaml · src/generated/ (do not edit) · src/client.ts · mock/
packages/schemas/     src/<module>.ts (zod) · src/index.ts
packages/commerce-rules/ src/ (money.ts, price-cart.ts, promotions.ts, tax.ts,
                      rounding.ts, totals.ts) · test-cases/*.json · __tests__/
packages/tokens/      tokens.json · build/ (css, ts) · style-dictionary.config.mjs
packages/ui-web/      src/components/* · .storybook/
packages/ui-native/   src/components/* (NumPad, ProductTile, CartLine, TotalBar, OfflineBadge…)
packages/i18n/        locales/ar.json ckb.json en.json · src/index.ts
packages/utils/       src/id.ts (uuidv7) · money-format.ts · dates.ts
packages/config/      tsconfig/*.json · eslint/*.js · depcruise.cjs · prettier.cjs
```

## docs

```
docs/00-overview.md … 11-open-decisions.md   specification
docs/PROGRESS.md                             tracker (updated after each step)
docs/adr/NNN-title.md                        decision records
docs/reports/SNN.md                          one report per finished step
docs/runbooks/                               what to do when X breaks (added in phase 4)
```
