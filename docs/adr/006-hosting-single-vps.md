# ADR 006 — Launch on one Hostinger KVM 8 with Caddy, PM2 and Docker

- **Status:** accepted
- **Date:** 2026-11-23

## Context
Medium scale at launch; owner already has the VPS and domain.

## Decision
Caddy (HTTPS, one site block per address), PM2 (Node apps), Docker (Postgres, Valkey, Meilisearch, bound to localhost), Cloudflare in front, R2 for images and backups.

## Consequences
Cheap and simple; single point of failure (POS keeps working offline). Each address is separate so parts can move to other servers by changing DNS. Separate DB server before peak seasons.
