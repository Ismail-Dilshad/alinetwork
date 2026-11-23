# 10 — Testing and quality

## Test pyramid

| Level | Tool | Where | What |
| --- | --- | --- | --- |
| Unit | Vitest | next to code / `__tests__/` | domain logic, commerce-rules (table-driven JSON cases), utils |
| Integration | Vitest + real Postgres/Valkey (docker) | `services/api/**/__tests__` | repositories, transactions, RLS, outbox, idempotency |
| Contract | Vitest + openapi validator | `tests/contract` | every endpoint's request/response matches `openapi.yaml` |
| Component | Storybook + test-runner | `packages/ui-*` | rendering, a11y, RTL |
| E2E web | Playwright | `tests/e2e` | storefront checkout, console flows, admin flows |
| E2E POS | Maestro | `tests/pos-e2e` | sale, return, shift, offline sync |
| Load | k6 | `tests/load` | checkout, POS sync, search at 10× expected traffic |

## Rules

- Business rules get **table-driven tests**: inputs and expected outputs in JSON.
- Integration tests use a fresh schema per test file (or transactions rolled back).
- Factories in `services/api/test/factories` create valid entities in one line.
- No test talks to real payment gateways; adapters have sandbox and fake modes.
- Flaky test = bug; fix or quarantine with an issue, never ignore.
- Coverage targets: commerce-rules 100% branches; domain folders ≥ 90%; overall ≥ 80%.

## Definition of done (every step)

1. `pnpm turbo run lint typecheck test build` passes
2. Step's "Done when" checks in docs/09-build-plan.md pass
3. New endpoints in openapi.yaml + contract tests
4. Migrations clean on a fresh DB and backward compatible
5. UI: light, dark, RTL checked; strings in i18n files (ar, ckb, en)
6. Audit entries for staff writes; permissions on every route
7. Report in `docs/reports/SNN.md`; `docs/PROGRESS.md` updated

## Launch checklist (S36)

- [ ] All e2e suites green on staging for 7 consecutive days
- [ ] Load test passed at 10× expected peak; p95 < 300 ms
- [ ] Backups running nightly to R2; restore drill done this month
- [ ] Security review: no open high/critical findings
- [ ] Payment gateways in live mode tested with real small transactions and refunds
- [ ] Monitoring: Sentry, uptime checks on every address, alerts reach the owner and super admin
- [ ] Owner recovery account created and stored offline
- [ ] Staff trained; POS devices registered; printers tested in every branch
- [ ] Legal pages (terms, privacy, returns) published in ar/ckb/en
- [ ] Rollback tested on production (`deploy.sh production rollback`)
