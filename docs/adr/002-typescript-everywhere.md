# ADR 002 — TypeScript everywhere; Go and Python only when measured

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Five apps (web, consoles, POS, mobile) are TypeScript by nature. The offline POS must calculate exactly like the server.

## Decision
TypeScript for backend and all apps. Prices/tax/discounts in one shared package used by API and POS. Go may be added later for a measured hot spot (POS sync gateway); Python only for ML in year 2. No Rust.

## Consequences
Shared types and rules, one hiring profile. A second language requires a new ADR, a clear boundary (API/events only) and shared JSON test cases.
