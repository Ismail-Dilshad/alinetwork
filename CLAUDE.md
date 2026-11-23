# CLAUDE.md — AliNetwork

AliNetwork is a unified commerce system for one business with several branches in Iraq:
online shop (alinetwork.store), mobile app, in-store POS, business console and system
admin console, all on one API and one database.

## Read before any work

1. `docs/PROGRESS.md` — current step and status
2. `docs/09-build-plan.md` — the step you are working on
3. The docs that step lists under **Read**
4. `docs/01-structure.md` — where every file goes

Do not rely on memory of earlier sessions. The files are the source of truth.

## How work runs

- Work happens **one build step at a time** (`S01`, `S02`, …) from `docs/09-build-plan.md`.
- The main session is the **orchestrator**: it delegates the step to the agent named in
  the plan (`.claude/agents/`), then verifies, then updates `docs/PROGRESS.md`, then **stops**.
- Never start the next step without the human saying so.
- If the plan, a doc and the code disagree, stop and ask. Do not guess.
- If a business rule is missing, check `docs/11-open-decisions.md`; if still unclear, ask.

## Stack (do not change without an ADR approved by the human)

- Monorepo: pnpm workspaces + Turborepo; TypeScript strict everywhere
- Backend: NestJS modular monolith (`services/api`), Drizzle ORM, PostgreSQL 17,
  Valkey (Redis) + BullMQ, Meilisearch, Cloudflare R2 (S3 API)
- Contracts: OpenAPI 3.1 (`packages/contracts`), Zod (`packages/schemas`)
- Shared rules: `packages/commerce-rules` (prices, tax, discounts, totals) — pure functions
- Storefront: Next.js App Router + next-intl
- Consoles: React + Vite + TanStack Router/Query/Table + react-hook-form + i18next
- POS + mobile: Expo (React Native) + expo-router; POS uses expo-sqlite for offline data
- Tests: Vitest, Playwright (web), Maestro (native), k6 (load)
- Use the latest stable version of each library at the time you install it, and pin it.

## Hard rules

1. **Stay in your folders.** Each agent owns folders listed in its file. Need a change
   elsewhere? Write it in your report under "Requests for other agents".
   Exception that applies to all module agents: `modules/*/db/schema.ts` and
   `services/api/migrations/` belong to the **database** agent. Module agents own the rest
   of their module (repositories included) and request schema changes; the orchestrator
   runs the database agent for them first.
2. **Module boundaries.** A backend module imports another module only from its `public/`
   folder. No cross-module SQL joins or foreign keys; reference by id.
3. **Contract first.** API changes go into `packages/contracts/openapi.yaml` and
   `packages/schemas` before code uses them.
4. **Money** is an integer in the smallest unit (`bigint`/`number`) + ISO currency code.
   Never floats. All price/tax/discount/total maths goes through `packages/commerce-rules`.
5. **IDs** are UUIDv7 generated in code. Human order numbers are per branch: `BGD1-000123`.
6. **Idempotency.** Every client write accepts `Idempotency-Key`; the server stores and replays.
7. **Audit.** Every staff or super-admin write creates an audit entry.
8. **Events** are written to `platform.outbox_events` in the same transaction as the change.
9. **Permissions** are checked in the backend on every request (role + branch).
10. **No card numbers** ever stored or logged. **No secrets** in code; use env files.
11. **i18n**: every UI string through translation files (ar, ckb, en). RTL-safe CSS
    (logical properties). Arabic is the default locale.
12. **Design tokens only**: no hard-coded colours, spacing or fonts.
13. **No new dependency, language or service** without listing it in the step report.

## Code conventions

- Files: `kebab-case.ts`; React components `PascalCase.tsx`; one component per file.
- Backend module folder shape (always the same):
  `public/ http/ domain/ db/ events/ jobs/ <name>.module.ts` + `__tests__/`
- Database: snake_case tables and columns; one Postgres schema per module.
- Commits: Conventional Commits with step id: `feat(S13): catalog products CRUD`.
- Errors: API returns `{ error: { code, message, details? } }`, codes in `UPPER_SNAKE`.

## Commands

```bash
pnpm install
docker compose -f infra/docker/compose.dev.yml up -d   # local services
pnpm dev                     # all apps
pnpm turbo run lint typecheck test build
pnpm --filter @alinetwork/api db:migrate
pnpm --filter @alinetwork/api db:seed
```

## Definition of done (every step)

- `pnpm turbo run lint typecheck test build` passes with zero errors
- New code has tests; business logic has table-driven tests
- New endpoints exist in `openapi.yaml` and pass contract tests
- Migrations run up cleanly on a fresh database and are backward compatible
- No `TODO` without a step id; no `any` without a comment explaining why
- The step's own "Done when" checks in `docs/09-build-plan.md` pass
- `docs/PROGRESS.md` updated; a short report written (see `.claude/commands/next-step.md`)

## Never without the human

Merging or pushing to `main`; changing payments, permissions, migrations already applied,
or `infra/`; adding a language or service; deleting data; editing `docs/11-open-decisions.md`
answers.
