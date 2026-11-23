# ADR 005 — Offline-first POS with cursor sync and idempotent push

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Store internet in Iraq can be unreliable; stores must keep selling.

## Decision
POS stores catalog, prices, branch stock and customers in SQLite. Pull uses a cursor over `platform.change_log`. Sales are saved locally first with UUIDv7 ids and idempotency keys, then pushed in batches; the server answers per sale. Server is the truth for stock; offline overselling is accepted and flagged.

## Consequences
Selling never stops. Need conflict alerts, offline limits (value cap, no refunds) and number blocks for offline order numbers.
