# ADR 008 — Contract-first REST API with OpenAPI 3.1

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Five clients and parallel agents need a stable contract before the backend exists.

## Decision
`packages/contracts/openapi.yaml` is written first; typed client generated (openapi-typescript + openapi-fetch); Zod schemas in `packages/schemas`; Prism mock server for frontend work; contract tests in CI.

## Consequences
Frontends start early against mocks. Breaking changes need `/v2`.
