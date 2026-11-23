# ADR 009 — Cloudflare R2 for images; no MinIO

- **Status:** accepted
- **Date:** 2026-11-23

## Context
MinIO stopped publishing free community Docker images and binaries in October 2025 and moved the community edition to maintenance.

## Decision
Production and staging images in Cloudflare R2 (S3 API) served at cdn.alinetwork.store; local development uses RustFS (S3-compatible) in Docker.

## Consequences
No storage service on the VPS, no image bandwidth from it. Code uses the generic S3 client so the provider can change.
