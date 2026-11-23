# ADR 004 — Money as integers in the smallest unit

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Floating point causes rounding errors; IQD has no minor units in practice, USD has cents.

## Decision
All amounts are integers + ISO currency code. IQD in dinars, USD in cents. Rounding half up at defined points only (per line tax, cash rounding). All maths in `@alinetwork/commerce-rules`.

## Consequences
No float bugs. Database uses bigint. Formatting is a display concern only.
