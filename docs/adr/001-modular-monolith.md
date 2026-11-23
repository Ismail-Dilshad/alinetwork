# ADR 001 — Modular monolith, not microservices

- **Status:** accepted
- **Date:** 2026-11-23

## Context
AliNetwork is one business with a small team. Microservices add network failures, distributed transactions and operations work with little benefit at this scale. Shopify runs its core as a modular monolith.

## Decision
One NestJS app (`services/api`) split into modules with enforced boundaries: imports only via `public/`, one Postgres schema per module, no cross-schema foreign keys, events via a transactional outbox. Same code runs as `api` or `worker`.

## Consequences
Sale and stock change in one transaction. Any module can be extracted later because nothing reaches into its tables. Boundaries must be enforced in CI (dependency-cruiser) or they erode.
