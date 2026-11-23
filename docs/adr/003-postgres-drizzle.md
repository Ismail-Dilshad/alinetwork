# ADR 003 — PostgreSQL 17 with Drizzle ORM

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Commerce needs transactions, constraints, row-level security and good reporting SQL.

## Decision
PostgreSQL 17; Drizzle (SQL-first, typed, light) for schema, migrations and queries; drizzle-kit for generated migrations that are reviewed and never edited after being applied.

## Consequences
Predictable SQL. Complex reports may use raw SQL through Drizzle's `sql` template (parameterised).
